#Requires -Version 5.1
<#
.SYNOPSIS
    OpenTouryo 用のコーディングエージェント・アセットを、対象リポジトリへインストールする。

.DESCRIPTION
    src/instructions/AGENTS.md（概要）と src/skills/*（コードの書き方）を、
    プロダクトごとの規定の場所へ配置する。AGENTS.md から参照される本文（TESTING.md）も、AGENTS.md と同じくルートへ置く。

    スキルは Agent Skills のオープン標準（SKILL.md）に準拠しているため全プロダクト共通で、
    配置先が異なるだけ。インストラクションのみプロダクト差分を吸収する。

      プロダクト   インストラクション                      スキル
      ---------------------------------------------------------------------
      claude       CLAUDE.md（AGENTS.md を @ import）      .claude/skills/
      copilot      .github/copilot-instructions.md（複製）  .github/skills/
      agents       AGENTS.md のみ                          .agents/skills/

    AGENTS.md はどのプロダクトでも対象リポジトリのルートに配置される（これが原本）。
    Claude Code は AGENTS.md を読まないため、@ import する CLAUDE.md を別途生成する。
    claude では、役の定義（src/agents：テスト先行の実装役・レビュー役）を .claude/agents へ置く。

    既存ファイルは、このスクリプトが生成したもの（生成マーカー付き）でない限り上書きしない。
    上書きするには -Force を指定する。

.PARAMETER Product
    インストール先プロダクト。claude / copilot / agents から複数指定可。

.PARAMETER TargetRoot
    インストール先リポジトリのルート。既定はカレントディレクトリ。

.PARAMETER Skill
    インストールするスキル名。省略時は全スキル。

.PARAMETER Force
    このスクリプトが生成したものではない既存ファイルも上書きする。

.PARAMETER IncludeTutorial
    spec→テスト→plan→実装 の進め方を試す見本一式（src/docs 配下の全ファイル。
    docs/spec・docs/plan・docs/prompt）を、相対パスを保ったまま導入先の docs/ へ配置する。
    既定では配置しない（opt-in）。
    docs/spec・docs/plan は利用者が実仕様/実計画を置く作業ディレクトリのため、
    既存ファイルは上書きしない（上書きするには -Force）。

.PARAMETER IncludeQualityGuard
    期待値の変更の検出器（src/quality/ExpectationGuard。段 1〜3）を導入先へ写す。既定では写さない（opt-in）。
      <QualityGuardPath>/CheckExpectationChange.ps1   本体
      <QualityGuardPath>/rules.common.psd1           共通の規則
      <QualityGuardPath>/rules.psd1                  リポジトリごとの規則（無いときだけ、rules.sample.psd1 から置く）
      <QualityGuardTestsPath>/                       判定の用例（Run-Tests.ps1。既定は <QualityGuardPath>/ExpectationGuard.Tests）
      .claude/hooks/ExpectationGuard.ps1             段 1（PreToolUse フック）
      .claude/agents/opentouryo-expectation-reviewer.md  突き合わせ役（期待値の変更の理由と差分。-Product の有無によらない）
      .githooks/commit-msg                           段 2（commit-msg フック）
      .github/workflows/expectation-change.yml       段 3（CI の雛形。無いときだけ置く。-Force でも上書きしない＝雛形の変更は手で合わせる）
      .claude/settings.json                          段 1 の登録（無いときだけ置く。あれば登録の例を表示する）
    写したファイルの先頭付近に「expectation-guard-source: <原本の版> <原本のパス> sha256:<中身>」の行を書く。
    原本の版は、src/quality に最後に触れたコミット（検出器と関係の無いコミットの後に写し直しても、版の行は変わらない）。
    導入先の CI は本体の -VerifyCopy で、写しが写したときのままかを確かめる（ずれは警告）。
    この行のあるファイルは再実行で上書きする（**写しは直さず、原本を直して写し直す**）。

.PARAMETER QualityGuardPath
    -IncludeQualityGuard の本体を置くフォルダ（導入先のルートから）。既定は tools/ExpectationGuard。

.PARAMETER QualityGuardTestsPath
    -IncludeQualityGuard の判定の用例を置くフォルダ（導入先のルートから）。既定は <QualityGuardPath>/ExpectationGuard.Tests。
    製品のソースの隣を避け、道具の置き場所に分けるときに使う（例 root/files/tools/ExpectationGuard.Tests。OpenTouryoCodingAgentAssets#13）。
    置き場所を変えても、古い場所の写しは消さない（導入先で消す。INSTALL.md）。CI の雛形は無いときだけ置くので、既存の workflow のパスは手で直す。

    -IncludeQualityGuard だけで -Product を省くと、検出器だけを写す（AGENTS.md・CLAUDE.md・スキルには触れない）。
    既に自前の検出器を持つリポジトリ（印の行の無いフック・検出器がある）を置き換えるときは、これに -Force を付ける
    （-Product と併せて -Force を付けると、導入先の AGENTS.md なども上書きされる）。

.EXAMPLE
    ./install.ps1 -Product claude -TargetRoot C:\git\MyApp
    Claude Code 向けに全スキルをインストールする。

.EXAMPLE
    ./install.ps1 -Product claude -TargetRoot C:\git\MyApp -IncludeQualityGuard
    スキルに加えて、期待値の変更の検出器を tools/ExpectationGuard/ とフック・CI の場所へ写す。

.EXAMPLE
    ./install.ps1 -Product claude -TargetRoot C:\git\MyApp -IncludeTutorial
    スキルに加えて、評価用チュートリアル一式（src/docs 配下の全ファイル）も docs/ へ配置する。

.EXAMPLE
    ./install.ps1 -TargetRoot $env:OT_OTR_PATH -IncludeQualityGuard -QualityGuardPath root/programs -Force
    検出器だけを写す（インストラクション・スキルには触れない）。自前の検出器を置き換える場合。

.EXAMPLE
    ./install.ps1 -Product claude,copilot -Skill opentouryo-layer-d,opentouryo-layer-b
    Claude Code と GitHub Copilot 向けに、D層とB層のスキルのみをインストールする。

.EXAMPLE
    ./install.ps1 -Product agents -WhatIf
    実際には書き込まず、何が行われるかを表示する。
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('claude', 'copilot', 'agents')]
    [string[]]$Product,

    [string]$TargetRoot = (Get-Location).Path,

    [string[]]$Skill,

    [switch]$Force,

    [switch]$IncludeTutorial,

    [switch]$IncludeQualityGuard,

    [string]$QualityGuardPath = 'tools/ExpectationGuard',

    [string]$QualityGuardTestsPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# このスクリプトが生成したファイルの目印。再実行時の安全な上書き判定に使う。
$GeneratedMarker = '<!-- opentouryo-agent-assets:generated -->'

$SourceRoot = Split-Path -Parent $PSScriptRoot
$InstructionsSource = Join-Path $SourceRoot 'src/instructions/AGENTS.md'
# AGENTS.md から参照される本文（AGENTS.md と同じく、導入先のルートへ置く）
$InstructionsExtraSources = @('src/instructions/TESTING.md') | ForEach-Object { Join-Path $SourceRoot $_ }
$SkillsSource = Join-Path $SourceRoot 'src/skills'
# 役の定義（Claude Code のサブ エージェント。TESTING.md 5 の実装役・レビュー役）
$AgentsSource = Join-Path $SourceRoot 'src/agents'
$DocsSource = Join-Path $SourceRoot 'src/docs'

# プロダクト別のスキル配置先。
# 補足: Copilot は .github/skills / .claude/skills / .agents/skills のいずれも走査するため、
#       claude と copilot を併用する場合は .claude/skills に寄せて重複を避けることもできる。
$SkillDestinations = @{
    claude  = '.claude/skills'
    copilot = '.github/skills'
    agents  = '.agents/skills'
}

function Resolve-Skills {
    param([string[]]$Requested)

    $available = Get-ChildItem -Path $SkillsSource -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }

    if (-not $available) {
        throw "スキルが見つかりません: $SkillsSource"
    }

    if (-not $Requested) { return $available }

    $unknown = $Requested | Where-Object { $_ -notin $available.Name }
    if ($unknown) {
        throw ("不明なスキル: {0}`n利用可能: {1}" -f ($unknown -join ', '), ($available.Name -join ', '))
    }

    return $available | Where-Object { $_.Name -in $Requested }
}

function Write-AssetFile {
    param(
        [string]$Path,
        [string]$Content
    )

    if (Test-Path $Path) {
        # UTF-8 で読む（Windows PowerShell 5.1 の Get-Content 既定は ANSI で、
        # UTF-8 の日本語を誤読して文字化けする。.NET は BOM 検出＋UTF-8 既定）。
        $existing = [System.IO.File]::ReadAllText($Path)
        if ($existing -notlike "*$GeneratedMarker*" -and -not $Force) {
            Write-Warning "スキップ（既存ファイルを保護）: $Path`n  上書きするには -Force を指定してください。"
            return
        }
    }

    if ($PSCmdlet.ShouldProcess($Path, '書き込み')) {
        $dir = Split-Path -Parent $Path
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        # BOM なし UTF-8。エージェント・Git の双方で扱いやすい。
        # Windows PowerShell 5.1 では -Encoding utf8 が BOM 付きになるため、.NET で直接書く
        # （utf8NoBOM は PowerShell 6+ 専用。5.1 でも動くようにこの方式を採る）。
        [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  書き込み: $Path"
    }
}

function Install-Skills {
    param(
        [string]$Destination,
        [System.IO.DirectoryInfo[]]$Skills
    )

    foreach ($s in $Skills) {
        $dest = Join-Path $Destination $s.Name
        if ($PSCmdlet.ShouldProcess($dest, 'スキルを配置')) {
            if (Test-Path $dest) {
                Remove-Item -Path $dest -Recurse -Force
            }
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Copy-Item -Path (Join-Path $s.FullName '*') -Destination $dest -Recurse -Force
            Write-Host "  配置: $dest"
        }
    }
}

# ---- 期待値の変更の検出器（-IncludeQualityGuard） ----

$QualitySource = Join-Path $SourceRoot 'src/quality/ExpectationGuard'
# 写したファイルの印。本体（CheckExpectationChange.ps1 -VerifyCopy）と同じ。
$QualityMarker = 'expectation-guard-source:'

# 原本の版（src/quality に最後に触れたコミット。原本に未コミットの変更があれば +dirty）
#   HEAD にしない：検出器と関係の無いコミットの後に写し直すと、中身が同じでも版の行だけが変わり、
#   導入先で「仕組みの変更」（トレーラーが要る）になるため（OpenTouryo 45cc9114 で判明）。
function Get-GuardRevision {
    $rev = & git -C $SourceRoot log -1 --format=%h --abbrev=12 -- 'src/quality' 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $rev) { return 'unknown' }
    $dirty = & git -C $SourceRoot status --porcelain -- 'src/quality' 2>$null
    if ($dirty) { $rev += '+dirty' }
    return $rev
}

# 本体の Get-CopyHash と同じ計算（改行を LF にそろえ、印の行を除いた残りの SHA-256）
function Get-GuardHash {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes(($Text -replace "`r`n", "`n"))
    return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant()
}

function Test-GuardCopy {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $head = @([System.IO.File]::ReadAllLines($Path) | Select-Object -First 3)
    return [bool]($head | Where-Object { $_ -match ('^\s*#.*' + [regex]::Escape($QualityMarker)) })
}

# 原本を写す。印の行を先頭（shebang・YAML の前付け「---」があればその次＝前付けの中の YAML のコメント）に入れる。
#   -Template : 雛形。無いときだけ置き、以後は導入先が持つ（印の行は付けるが、中身の検査はしない＝sha256:-）
#   -NoMarker : 印の行を付けない（rules.psd1。導入先が持つ）
function Copy-GuardFile {
    param(
        [string]$Source,
        [string]$Destination,
        [hashtable]$Replace = @{},
        [switch]$Bom,
        [switch]$Template,
        [switch]$NoMarker
    )

    $exists = Test-Path -LiteralPath $Destination
    if ($exists) {
        # 雛形・導入先が持つファイルは、-Force でも上書きしない（導入先の固有の設定を失うため。OpenTouryo#657 で判明）
        if ($NoMarker -or $Template) {
            Write-Host "  そのまま（導入先が持つ）: $Destination"
            if ($Template) { Write-Host "    雛形の変更は手で合わせる（原本: $($Source.Substring($SourceRoot.Length).TrimStart('\', '/') -replace '\\', '/')）" }
            return
        }
        elseif (-not (Test-GuardCopy $Destination) -and -not $Force) {
            Write-Warning "スキップ（既存ファイルを保護）: $Destination`n  上書きするには -Force を指定してください。"
            return
        }
    }

    $text = [System.IO.File]::ReadAllText($Source) -replace "`r`n", "`n"
    foreach ($k in $Replace.Keys) { $text = $text.Replace($k, $Replace[$k]) }

    if (-not $NoMarker) {
        $relSource = ($Source.Substring($SourceRoot.Length).TrimStart('\', '/') -replace '\\', '/')
        $hash = $(if ($Template) { '-' } else { Get-GuardHash $text })
        $marker = "# $QualityMarker OpenTouryoCodingAgentAssets@$script:guardRevision $relSource sha256:$hash"
        $lines = New-Object System.Collections.ArrayList
        $lines.AddRange(@($text -split "`n"))
        $at = $(if ($lines.Count -gt 0 -and ($lines[0].StartsWith('#!') -or $lines[0] -eq '---')) { 1 } else { 0 })
        $lines.Insert($at, $marker)
        $text = ($lines -join "`n")
    }

    if ($PSCmdlet.ShouldProcess($Destination, '写す')) {
        $dir = Split-Path -Parent $Destination
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        # .ps1・.psd1 は BOM 付き UTF-8（Windows PowerShell 5.1 は BOM 無しを ANSI として読み、日本語が化ける）。
        # commit-msg は sh が読むので BOM 無し・LF。
        [System.IO.File]::WriteAllText($Destination, $text, (New-Object System.Text.UTF8Encoding($Bom.IsPresent)))
        Write-Host "  写す: $Destination"
    }
}

function Install-QualityGuard {
    if (-not (Test-Path $QualitySource)) {
        throw "検出器の原本が見つかりません: $QualitySource"
    }
    $script:guardRevision = Get-GuardRevision

    $rel = ($QualityGuardPath -replace '\\', '/').Trim('/')
    if (-not $rel -or $rel -eq '.') { $checker = 'CheckExpectationChange.ps1' } else { $checker = "$rel/CheckExpectationChange.ps1" }
    $checkerWin = $checker -replace '/', '\'
    $testsRel = $(if ($QualityGuardTestsPath) { ($QualityGuardTestsPath -replace '\\', '/').Trim('/') } elseif (-not $rel -or $rel -eq '.') { 'ExpectationGuard.Tests' } else { "$rel/ExpectationGuard.Tests" })
    $testsWin = ($testsRel -replace '/', '\') + '\Run-Tests.ps1'
    # Run-Tests.ps1 が本体を探す場所（ルートから。本体が導入先のルートなら '.'）
    $checkerDir = $(if (-not $rel -or $rel -eq '.') { '.' } else { $rel })
    $replace = @{ '@@CHECKER@@' = $checker; '@@CHECKER_WIN@@' = $checkerWin; '@@TESTS_WIN@@' = $testsWin; '@@CHECKER_DIR@@' = $checkerDir }

    $dest = Join-Path $TargetRoot $rel
    Write-Host "  原本の版: OpenTouryoCodingAgentAssets@$script:guardRevision"
    Copy-GuardFile -Source (Join-Path $QualitySource 'CheckExpectationChange.ps1') -Destination (Join-Path $dest 'CheckExpectationChange.ps1') -Bom
    Copy-GuardFile -Source (Join-Path $QualitySource 'rules.common.psd1') -Destination (Join-Path $dest 'rules.common.psd1') -Bom
    Copy-GuardFile -Source (Join-Path $QualitySource 'rules.sample.psd1') -Destination (Join-Path $dest 'rules.psd1') -Bom -NoMarker

    $testsSource = Join-Path $QualitySource 'tests'
    foreach ($f in Get-ChildItem -Path $testsSource -File) {
        Copy-GuardFile -Source $f.FullName -Destination (Join-Path (Join-Path $TargetRoot $testsRel) $f.Name) -Replace $replace -Bom
    }

    Copy-GuardFile -Source (Join-Path $QualitySource 'ExpectationGuard.ps1') -Destination (Join-Path $TargetRoot '.claude/hooks/ExpectationGuard.ps1') -Replace $replace -Bom
    Copy-GuardFile -Source (Join-Path $QualitySource 'commit-msg') -Destination (Join-Path $TargetRoot '.githooks/commit-msg') -Replace $replace
    # 突き合わせ役（OpenTouryoCodingAgentAssets#6）。検出器の一部なので、-Product の有無によらず写す
    Copy-GuardFile -Source (Join-Path $QualitySource 'opentouryo-expectation-reviewer.md') -Destination (Join-Path $TargetRoot '.claude/agents/opentouryo-expectation-reviewer.md') -Replace $replace
    Copy-GuardFile -Source (Join-Path $QualitySource 'expectation-change.yml') -Destination (Join-Path $TargetRoot '.github/workflows/expectation-change.yml') -Replace $replace -Template

    # 段 1 の登録。settings.json は利用者の他の設定も持つので、あれば書き換えない。
    $settingsPath = Join-Path $TargetRoot '.claude/settings.json'
    $hookEntry = @'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|Bash|PowerShell",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe",
            "args": ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "${CLAUDE_PROJECT_DIR}/.claude/hooks/ExpectationGuard.ps1"]
          }
        ]
      }
    ]
  }
}
'@
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        if ($PSCmdlet.ShouldProcess($settingsPath, '書き込み')) {
            $dir = Split-Path -Parent $settingsPath
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            [System.IO.File]::WriteAllText($settingsPath, ($hookEntry -replace "`r`n", "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
            Write-Host "  書き込み: $settingsPath"
        }
    }
    else {
        Write-Warning ("そのまま（既存の設定を保護）: $settingsPath`n  段 1 を使うには、hooks.PreToolUse に次を足してください。`n" + $hookEntry)
    }

    Write-Host ''
    Write-Host '  導入先で行うこと（人が行う）:'
    Write-Host "    1. $rel/rules.psd1 を確かめる（既定はテストが <Webプロジェクト名>.Tests/ の NUnit。違うなら Paths を合わせる）"
    Write-Host '    2. git config core.hooksPath .githooks（段 2 を有効にする。人ごとの設定）'
    Write-Host '    3. git add --chmod=+x .githooks/commit-msg（実行属性。Linux・macOS の sh で要る）'
    Write-Host "    4. 判定の用例を回す: $testsWin"
    Write-Host '    5. 既に検出器があるリポジトリ（入れ直しを含む）では、この変更自体が「仕組みの変更」になる。コミットにトレーラー Expectation-Change: <理由> を付ける'
    Write-Host '       （写しの中身が同じでも、印の行の版が変わるだけで止まる。理由には版の変化と、中身が変わったかどうかを書く）'
}

# ---- 実行 ----

if (-not (Test-Path $InstructionsSource)) {
    throw @"
アセットの原本が見つかりません: $InstructionsSource
このインストーラはアセット・リポジトリ（OpenTouryoCodingAgentAssets）の install/ 内から実行してください。
install.ps1 だけを他所へコピーしても、隣接する src/instructions・src/skills を読めないため動きません。
導入先は -TargetRoot で指定します（既定はカレントディレクトリ）:
  <アセット>\install\install.ps1 -Product claude -TargetRoot <導入先リポジトリ>
"@
}

if (-not $Product -and -not $IncludeQualityGuard) {
    throw '-Product を指定してください（-IncludeQualityGuard だけのときは省けます）。'
}

$TargetRoot = (Resolve-Path $TargetRoot).Path

# 検出器だけを写す（-Product を省いたとき）
if (-not $Product) {
    Write-Host "インストール先: $TargetRoot"
    Write-Host ''
    Write-Host '期待値の変更の検出器:'
    Install-QualityGuard
    Write-Host ''
    Write-Host '完了しました。'
    return
}

$skills = Resolve-Skills -Requested $Skill
# UTF-8 で読む（PS 5.1 の Get-Content 既定 ANSI だと AGENTS.md の日本語が文字化けする）。
$instructionsBody = [System.IO.File]::ReadAllText($InstructionsSource)

Write-Host "インストール先: $TargetRoot"
Write-Host "対象プロダクト: $($Product -join ', ')"
Write-Host "対象スキル: $($skills.Name -join ', ')"
Write-Host ''

# AGENTS.md は全プロダクト共通の原本としてルートに配置する。
Write-Host 'インストラクション (共通):'
$agentsMd = "$GeneratedMarker`n$instructionsBody"
Write-AssetFile -Path (Join-Path $TargetRoot 'AGENTS.md') -Content $agentsMd
foreach ($extra in $InstructionsExtraSources) {
    $extraBody = [System.IO.File]::ReadAllText($extra)
    Write-AssetFile -Path (Join-Path $TargetRoot (Split-Path -Leaf $extra)) -Content "$GeneratedMarker`n$extraBody"
}

# チュートリアル一式（opt-in・プロダクト非依存）。src/docs 配下の全ファイルを、
# 相対パスを保ったまま導入先の docs/ 配下へ配置する。
# docs/spec・docs/plan は利用者の作業ディレクトリなので、生成マーカーは埋め込まず、
# 既存ファイルは上書きしない（Write-AssetFile が -Force 指定時のみ上書きする）。
if ($IncludeTutorial) {
    Write-Host ''
    Write-Host 'チュートリアル (opt-in):'
    if (-not (Test-Path $DocsSource)) {
        Write-Warning "チュートリアル原本ディレクトリが見つかりません: $DocsSource"
    }
    else {
        # Resolve-Path で区切りを正規化してから相対パスを切り出す。
        $docsRoot = (Resolve-Path $DocsSource).Path
        $docFiles = Get-ChildItem -Path $docsRoot -Recurse -File
        if (-not $docFiles) {
            Write-Warning "チュートリアル原本が見つかりません: $docsRoot"
        }
        foreach ($f in $docFiles) {
            $relative = $f.FullName.Substring($docsRoot.Length).TrimStart('\', '/')
            $tutorialBody = [System.IO.File]::ReadAllText($f.FullName)
            $destPath = Join-Path (Join-Path $TargetRoot 'docs') $relative
            Write-AssetFile -Path $destPath -Content $tutorialBody
        }
    }
}

# 期待値の変更の検出器（opt-in・プロダクト非依存。段 1 のフックは Claude Code 用）。
if ($IncludeQualityGuard) {
    Write-Host ''
    Write-Host '期待値の変更の検出器 (opt-in):'
    Install-QualityGuard
}

foreach ($p in $Product) {
    Write-Host ''
    Write-Host "プロダクト: $p"

    switch ($p) {
        'claude' {
            # Claude Code は AGENTS.md を読まないため、@ import する CLAUDE.md を生成する。
            # Windows では symlink に管理者権限が必要なので import 方式を採る。
            $claudeMd = @"
$GeneratedMarker
@AGENTS.md

## Claude Code 固有の指示

<!-- TODO: Claude Code でのみ有効にしたい指示があればここに追記する。不要なら節ごと削除してよい。 -->
"@
            Write-AssetFile -Path (Join-Path $TargetRoot 'CLAUDE.md') -Content $claudeMd

            # 役の定義（.claude/agents）。原本に生成マーカーを入れてあるので、再実行で上書きされる。
            Write-Host '  役の定義:'
            if (Test-Path $AgentsSource) {
                foreach ($a in Get-ChildItem -Path $AgentsSource -Filter '*.md' -File) {
                    $agentBody = [System.IO.File]::ReadAllText($a.FullName)
                    Write-AssetFile -Path (Join-Path $TargetRoot ".claude/agents/$($a.Name)") -Content $agentBody
                }
            }
        }

        'copilot' {
            # Copilot は @ import 構文を持たないため、AGENTS.md の内容を複製する。
            # 原本は src/instructions/AGENTS.md 側。こちらを直接編集しないこと。
            $copilotMd = @"
$GeneratedMarker
<!-- このファイルは install.ps1 が生成した複製です。編集しないでください。 -->
<!-- 原本: OpenTouryoCodingAgentAssets/src/instructions/AGENTS.md -->

$instructionsBody
"@
            Write-AssetFile -Path (Join-Path $TargetRoot '.github/copilot-instructions.md') -Content $copilotMd
        }

        'agents' {
            # AGENTS.md は既にルートへ配置済み。追加のインストラクションは不要。
            Write-Host '  インストラクション: AGENTS.md（配置済み）'
        }
    }

    Write-Host '  スキル:'
    Install-Skills -Destination (Join-Path $TargetRoot $SkillDestinations[$p]) -Skills $skills
}

Write-Host ''
Write-Host '完了しました。'
