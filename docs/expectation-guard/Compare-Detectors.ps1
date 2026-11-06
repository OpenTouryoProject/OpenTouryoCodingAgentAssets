<#
.SYNOPSIS
    置き換えの前（各リポジトリの検出器）と後（共通の本体＋規則）で、コミットごとの判定が同じかを比べる（OpenTouryoCodingAgentAssets#3 段階 4）。

.DESCRIPTION
    -Range のコミット（マージでないもの。導入より前は除く）を 1 つずつ、旧・新の検出器の -Commit で見て、
    終了コードと検出の一覧（承認済みなら件数）を比べる。-OldGeneratedSwitch を指定すると、
    範囲全体の生成物の確認（旧 -<スイッチ>、新 -CheckGenerated）も比べる。
    **読むだけで、リポジトリは変えない**（git の参照系の操作だけを使う）。

.PARAMETER Repo
    比べるリポジトリ（カレントにして動かす）。
.PARAMETER Old
    旧の検出器（そのリポジトリの CheckExpectationChange.ps1）。
.PARAMETER New
    新の本体（CheckExpectationChange.ps1。同じフォルダに rules.common.psd1）。
.PARAMETER Rules
    新の本体に渡す規則（rules.psd1）。
.PARAMETER Range
    <base>..<head>。
.PARAMETER IntroducedBy
    導入の印のパス（これが木に無いコミットは比べない）。
.PARAMETER OldGeneratedSwitch
    旧の検出器の、生成物の確認のスイッチ名（MultiPurposeAuthSite は CheckTestCases）。
#>
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Old,
    [Parameter(Mandatory)][string]$New,
    [Parameter(Mandatory)][string]$Rules,
    [Parameter(Mandatory)][string]$Range,
    [Parameter(Mandatory)][string]$IntroducedBy,
    [string]$OldGeneratedSwitch
)

$ErrorActionPreference = "Stop"
$utf8 = New-Object Text.UTF8Encoding $false
$host1 = (Get-Process -Id $PID).Path

function Invoke-Old([string[]]$Arguments)
{
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $host1
    $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" ' -f $Old) + ($Arguments -join " ")
    $psi.WorkingDirectory = $Repo
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $utf8
    $p = [Diagnostics.Process]::Start($psi)
    $errTask = $p.StandardError.ReadToEndAsync()
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    return [pscustomobject]@{ Exit = $p.ExitCode; Lines = @($out -split "`r?`n"); Error = $errTask.Result }
}

# 「種類 : パス（n 件）」を、空白をそろえた形にする
function Format-Finding([string]$Kind, [string]$Rest)
{
    return ("{0} : {1}" -f ($Kind.Trim() -replace '[\s　]+$', ''), $Rest.Trim())
}

# 旧の出力から、検出の一覧（未承認のとき）または件数（承認済みのとき）を読む
function Read-OldFindings([string[]]$Lines)
{
    $list = @(); $count = 0; $in = $false
    foreach ($l in $Lines)
    {
        if ($l -match 'トレーラーの無い期待値の変更があります') { $in = $true; continue }
        if ($l -match '期待値の変更 (\d+) 件（.*トレーラーで承認済み') { $count = [int]$Matches[1] }
        if ($in)
        {
            if (-not $l.Trim()) { if ($list.Count -gt 0) { $in = $false }; continue }
            if ($l -match '^\s{4}(\S.*?)\s*:\s(.+)$') { $list += (Format-Finding $Matches[1] $Matches[2]) }
        }
    }
    if ($list.Count -gt 0) { $count = $list.Count }
    return [pscustomobject]@{ List = @($list | Sort-Object); Count = $count }
}

Push-Location $Repo
try
{
    $commits = @(& git rev-list --no-merges --reverse $Range)
    $same = 0; $diff = 0; $skipped = 0
    foreach ($c in $commits)
    {
        & git cat-file -e "${c}:$IntroducedBy" 2>$null
        if ($LASTEXITCODE -ne 0) { $skipped++; continue }

        $o = Invoke-Old @("-Commit", $c)
        $of = Read-OldFindings $o.Lines

        $n = @(& $New -Commit $c -RulesFile $Rules -PassThru -Quiet) | Where-Object { $_ -and $_.PSObject.Properties["Findings"] } | Select-Object -Last 1
        $nCode = $LASTEXITCODE
        $nList = @($n.Findings | ForEach-Object {
            $tail = $(if ($_.Count -gt 0) { "（{0} 件）" -f $_.Count } else { "" })
            Format-Finding $_.Kind ($_.Path + $tail)
        } | Sort-Object)

        $ok = ($o.Exit -eq $nCode) -and ($of.Count -eq $nList.Count)
        if ($ok -and $o.Exit -eq 1) { $ok = (($of.List -join "`n") -ceq ($nList -join "`n")) }
        $subject = (& git log -1 --format=%s $c)
        if ($subject.Length -gt 60) { $subject = $subject.Substring(0, 60) }
        if ($ok)
        {
            $same++
            Write-Host ("  同じ  {0}  終了 {1}  検出 {2} 件  {3}" -f $c.Substring(0, 8), $nCode, $nList.Count, $subject)
        }
        else
        {
            $diff++
            Write-Host ("  違う  {0}  {1}" -f $c.Substring(0, 8), $subject) -ForegroundColor Red
            Write-Host ("        旧 : 終了 {0}  検出 {1} 件  {2}" -f $o.Exit, $of.Count, ($of.List -join " / "))
            Write-Host ("        新 : 終了 {0}  検出 {1} 件  {2}" -f $nCode, $nList.Count, ($nList -join " / "))
            if ($o.Error) { Write-Host ("        旧の標準エラー : " + $o.Error.Trim()) }
            if ($n -and $n.Errors) { Write-Host ("        新のエラー : " + ($n.Errors -join " / ")) }
        }
    }
    Write-Host ""
    Write-Host ("  コミット {0} 件：同じ {1} 件、違う {2} 件、導入より前 {3} 件" -f $commits.Count, $same, $diff, $skipped)

    if ($OldGeneratedSwitch)
    {
        $o = Invoke-Old @("-Range", $Range, "-$OldGeneratedSwitch")
        # 一覧は「作り直されていません」の見出しの後、空の行までの字下げした行（その後のトレーラーの例は含めない）
        $oList = @(); $in = $false
        foreach ($l in $o.Lines)
        {
            if ($l -match '作り直されていません') { $in = $true; continue }
            if ($in -and -not $l.Trim()) { if ($oList.Count -gt 0) { $in = $false }; continue }
            if ($in -and $l -match '^\s{4}\S') { $oList += $l.Trim() }
        }
        $oList = @($oList | Sort-Object)
        $n = @(& $New -Range $Range -CheckGenerated -RulesFile $Rules -PassThru -Quiet) | Where-Object { $_ -and $_.PSObject.Properties["Findings"] } | Select-Object -Last 1
        $nCode = $LASTEXITCODE
        $nList = @($n.Findings | ForEach-Object { $_.Path } | Sort-Object)
        $ok = ($o.Exit -eq $nCode) -and (($oList -join "`n") -ceq ($nList -join "`n"))
        Write-Host ("  生成物の確認 : {0}（旧 終了 {1} [{2}]、新 終了 {3} [{4}]）" -f $(if ($ok) { "同じ" } else { "違う" }), $o.Exit, ($oList -join ", "), $nCode, ($nList -join ", "))
        if (-not $ok) { $diff++ }
    }
    exit $(if ($diff -eq 0) { 0 } else { 1 })
}
finally { Pop-Location }
