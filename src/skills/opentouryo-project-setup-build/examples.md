# 参考：as-built セットアップ スクリプト（PowerShell 雛形）

実環境（WebForms_Sample / net48 / 固定タグ `03-20` / 深いリポ パス）で**実際に通した2本**。
本スキルが推奨する「生成スクリプトをリポジトリに残す・`.bat` より PowerShell ラッパ」の具体例で、
既知の落とし穴（MAX_PATH＝短い作業ルート、exit code 不信＝DLL 実在で判定、`.\`＋`< nul`、
**2CS＝`Business.RichClient` の別 sln**、**ツールの `PackageReference` restore**）を織り込み済み。
（※`build-app.ps1` は参照方式の更新に合わせて改訂：`WSServer_sample`/`WSIFType_sample` は ProjectReference＝
1ソリューション一括ビルド。旧「WS を別ビルドして `WS_sample\Build\` へコピー」は不要。`samples/webservices.md`。）

**これらは `scripts/` フォルダに置く**（ルート直置きにしない）。そのため各スクリプトの `$repo` は
**スクリプトの親＝リポジトリ ルート**を指す（`$repo = Split-Path -Parent $PSScriptRoot`。`$PSScriptRoot` は `scripts\` 自身）。

`$PSScriptRoot` は**スクリプト ファイルの場所**を指し**カレントディレクトリに依存しない**ので、
`cd scripts; .\setup-build.ps1` でもルートから `.\scripts\setup-build.ps1` でも同じく動く。ただし
**(1) `.ps1` ファイルとして実行する**（コンソールへ貼り付け実行だと `$PSScriptRoot` が空＝`$repo` が壊れる。dot-source は可）／
**(2) `scripts\` はリポジトリ ルート直下の1階層**に置く（`Split-Path -Parent` が1階層だけ上がる前提。深くしない）。

**雛形化する際は `$ref`・パス・標的ランタイム（net48）をパラメタ化**する。フラット化しない
（配置維持）方針なら相対パスは配置に合わせて変える。**as-built の雛形なので、環境に合わせて調整する**
（Configuration・restore 方式・msbuild 解決など）。

- `setup-build.ps1` — 本スキル ①②③（ZIP取得 → net48 基盤ビルド → ベンダ）。短パス `C:\otr` でビルド、
  `OpenTouryo.Business.dll` の実在で成否判定。**親クラス2 をカスタマイズするなら任意ブロック**（overlay 適用＋
  2CS の `Business.RichClient` ビルド）を有効化する。
- `build-app.ps1` — アプリ側の取り出し後ビルド（`opentouryo-project-setup` ④⑤ / `samples/webforms.md` 構成A）。
  `nuget restore` → WebForms ソリューションを一括ビルド（`WSServer_sample`/`WSIFType_sample` は ProjectReference＝
  同ソリューションで同時に建つ）。vswhere で msbuild 解決。
  **開発支援ツールを取り出しているなら任意ブロック**（DaoGen/DPQuery のビルド）で欠落参照を早期に炙り出す。

## `setup-build.ps1`（ZIP取得 → net48 基盤ビルド → ベンダ）

```powershell
# Download archive/<ref>.zip -> build net48 base -> vendor to
# OpenTouryoAssemblies\Build_net48. Idempotent; re-run to refresh a tag.
$ErrorActionPreference = 'Stop'
$repo    = Split-Path -Parent $PSScriptRoot   # scripts\ に置く前提＝親がリポジトリ ルート
$ref     = '03-20'                       # fixed tag; set per project (ask the user which tag; not a default)
# Base build runs from a SHORT root (C:\otr), not <repo>\Temp: the legacy
# net48 Business build writes a very long generated .resources filename;
# under a deep repo path the fully-qualified path exceeds MAX_PATH (MSB3553).
# Only scratch/build output lives here; vendored DLLs land in <repo>.
$work    = 'C:\otr'
$zip     = Join-Path $work "OpenTouryo-$ref.zip"
$extract = Join-Path $work "OpenTouryo-$ref"
$cs      = Join-Path $extract 'root\programs\CS'
$vendor  = Join-Path $repo 'OpenTouryoAssemblies\Build_net48'
$overlay = Join-Path $repo 'base2-overlay'   # present only when customizing 親クラス2

# --- 1. ZIP acquisition (not git clone) ---
New-Item -ItemType Directory -Force -Path $work | Out-Null
if (-not (Test-Path $extract)) {
    if (-not (Test-Path $zip)) {
        # WebClient.DownloadFile() defaults to an old TLS and gets 404 from GitHub
        # codeload (a HEAD returns 200, so it looks like the URL is fine -> misleading).
        # Force TLS 1.2 and use Invoke-WebRequest instead.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://github.com/OpenTouryoProject/OpenTouryo/archive/$ref.zip" -OutFile $zip
    }
    Expand-Archive -Path $zip -DestinationPath $work -Force
}

# --- 1b. (optional) apply base2 overlay BEFORE building ---
# If this repo customizes the framework Business layer, its edited *.cs live in
# base2-overlay\ as FILE-LEVEL copies (not patches). Overwrite the extract tree
# with them before the build. Copy-Item preserves bytes incl UTF-8 BOM (the base
# sources are UTF-8 BOM with Japanese comments); xcopy on a folder would also
# prompt F/D. Requires a FIXED $ref (develop moves the base under the overlay).
if (Test-Path $overlay) {
    Copy-Item -Path (Join-Path $overlay '*') -Destination $cs -Recurse -Force
}

# --- 2. Base build (net48 only: the two bats the skill specifies) ---
# pause at bat end -> feed NUL; run from CS so relative paths resolve.
Push-Location $cs
try {
    cmd /c ".\2_Build_NuGet_net48.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "2_Build_NuGet_net48 failed ($LASTEXITCODE)" }
    cmd /c ".\3_Build_Business_net48.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "3_Build_Business_net48 failed ($LASTEXITCODE)" }
} finally { Pop-Location }

# --- 2b. build Business.RichClient — the bats DON'T (needed for 2CS / rich client) ---
# 3_Build_Business_net48 builds Business + CustomControl only. The 2CS classes
# (MyBaseLogic2CS / MyFcBaseLogic2CS = OpenTouryo.Business.RichClient) live in a
# separate sln that no 2_/3_ script builds. This DLL is a *plain dependency* of the
# 2CS (2CSClientWin/WPF) and 3-tier rich-client (WSClient_*) SAMPLES — required
# whenever such a sample is used, INDEPENDENT of base2 customization. Without it
# those samples fail with CS0246. (This is the `setup-build-richclient.ps1` step.)
$needRichClient = $true    # set true when the target sample is 2CS / rich client, OR base2 customizes 2CS
if ($needRichClient -or (Test-Path $overlay)) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $msb = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild `
            -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
    $brc = Join-Path $cs 'Frameworks\Infrastructure\BusinessRichClient_net48.sln'
    # This sln is NON-SDK, HintPath-only (no PackageReference). `/t:restore` FAILS with
    # "Microsoft.NuGet.targets ... does not reference .NETFramework,Version=v4.8" -> build WITHOUT restore.
    # Also: the net48 & netcore RichClient csproj SHARE one obj\ . A prior netcore SDK restore
    # leaves obj\project.assets.json / obj\*.nuget.* that break THIS net48 build with the same
    # error -> purge them first. (This is why RichClient was built in isolation at C:\otr\rc.)
    # NOTE the paths: RichClient lives under Business\ AND CustomControl\ (verified as-built) --
    # NOT directly under Infrastructure\. Both obj\ dirs must be purged.
    foreach ($rcObj in @(
        (Join-Path $cs 'Frameworks\Infrastructure\Business\RichClient\obj'),
        (Join-Path $cs 'Frameworks\Infrastructure\CustomControl\RichClient\obj'))) {
        if (Test-Path $rcObj) {
            Get-ChildItem $rcObj -Filter 'project.assets.json' -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
            Get-ChildItem $rcObj -Filter '*.nuget.*'          -EA SilentlyContinue | Remove-Item -Force -EA SilentlyContinue
        }
    }
    & $msb $brc /t:build /p:Configuration=Release /nologo /v:m   # NO restore (non-SDK sln); build only
    if ($LASTEXITCODE -ne 0) { throw "BusinessRichClient build failed ($LASTEXITCODE)" }
}

# --- 3. Vendor -> OpenTouryoAssemblies\Build_net48 ---
$src = Join-Path $cs 'Frameworks\Infrastructure\Build_net48'
if (-not (Test-Path $src)) { throw "Build output not found: $src" }
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $vendor -Recurse -Force
# The .bat wrappers end with `pause` and swallow msbuild's exit code, so
# confirm the build actually produced the Business DLL (most prone to fail,
# e.g. MSB3553 MAX_PATH under a deep working tree).
if (-not (Test-Path (Join-Path $vendor 'OpenTouryo.Business.dll'))) {
    throw "Base build did not produce OpenTouryo.Business.dll (check the build output above)."
}
# When customizing 2CS, also confirm the RichClient Business DLL was produced.
if ((Test-Path $overlay) -and
    -not (Test-Path (Join-Path $vendor 'OpenTouryo.Business.RichClient.dll'))) {
    throw "base2-overlay present but OpenTouryo.Business.RichClient.dll not vendored (2b did not run?)."
}
Get-ChildItem $vendor -Filter 'OpenTouryo.*.dll' | Select-Object -ExpandProperty Name
```

## `setup-build-netcore.ps1`（net10.0 基盤ビルド → ベンダ）

net48 版と同型で、回すバッチが `*_netcore100` になる。**混在ランタイム repo（net48 は既にベンダ済みで
net10.0 だけ後から足す）では、既存の ZIP 展開ツリーを再 DL せず流用し、netcore のバッチだけ回す**。
ベンダ先 `Build_netcore100\` は **TFM サブフォルダ（`net10.0\` と `net10.0-windows7.0\`）を両方含む**ので丸ごとコピーする。

```powershell
$ErrorActionPreference = 'Stop'
$repo    = Split-Path -Parent $PSScriptRoot   # scripts\ に置く前提＝親がリポジトリ ルート
$ref     = '03-20'                       # net48 と同じタグに揃える（ask the user; not a default）
$work    = 'C:\otr'
$extract = Join-Path $work "OpenTouryo-$ref"
$cs      = Join-Path $extract 'root\programs\CS'
$vendor  = Join-Path $repo 'OpenTouryoAssemblies\Build_netcore100'
$needRichClient = $true   # 標的が 2CS / rich client（TFM net10.0-windows7.0）なら true。Web/MVC/Bat/CLI は false

# --- 1. 既存 extract を流用（無ければ ZIP 取得）。net48 で展開済みなら再 DL しない ---
if (-not (Test-Path $cs)) {
    $zip = Join-Path $work "OpenTouryo-$ref.zip"
    if (-not (Test-Path $zip)) {
        # See setup-build.ps1: WebClient's old TLS default 404s on GitHub codeload.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://github.com/OpenTouryoProject/OpenTouryo/archive/$ref.zip" -OutFile $zip
    }
    Expand-Archive -Path $zip -DestinationPath $work -Force
}

# --- 2. 基盤ビルド（net10.0 のバッチだけ。SDK の dotnet build を使う）---
Push-Location $cs
try {
    cmd /c ".\2_Build_NuGet_netcore100.bat    < nul"
    if ($LASTEXITCODE -ne 0) { throw "2_Build_NuGet_netcore100 failed ($LASTEXITCODE)" }
    cmd /c ".\3_Build_Business_netcore100.bat < nul"
    if ($LASTEXITCODE -ne 0) { throw "3_Build_Business_netcore100 failed ($LASTEXITCODE)" }

    # 2b. RichClient (2CS / rich client の netcore サンプルで必須。setup-build-richclient-netcore.ps1 相当)。
    # ★ netcore は net10.0-windows7.0\ に Business / Dam* / Business.RichClient が「ここで初めて」出る
    #    （3_Build_Business_netcore100 直後は無い）。フォルダ丸ごと再ベンダするため、この後ベンダで上書きされる。
    if ($needRichClient) {   # 標的が 2CS / rich client（TFM net10.0-windows7.0）なら true
        cmd /c ".\3_Build_BusinessRichClient_netcore100.bat < nul"
        if ($LASTEXITCODE -ne 0) { throw "3_Build_BusinessRichClient_netcore100 failed ($LASTEXITCODE)" }
    }
} finally { Pop-Location }

# --- 3. ベンダ（net10.0\ と net10.0-windows7.0\ の両サブフォルダを丸ごと）---
# RichClient を回した場合、net10.0-windows7.0\ に Business/Dam*/Business.RichClient が揃うので、
# 個別 DLL を拾わず「フォルダ丸ごと」コピーする（拾い漏らすと OpenTouryo.Business で CS0246）。
$src = Join-Path $cs 'Frameworks\Infrastructure\Build_netcore100'
if (-not (Test-Path $src)) { throw "Build output not found: $src" }
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $vendor -Recurse -Force
if (-not (Test-Path (Join-Path $vendor 'net10.0\OpenTouryo.Business.dll'))) {
    throw "netcore base build did not produce net10.0\OpenTouryo.Business.dll (check output)."
}
# 2CS / rich client 標的なら Windows TFM 側にも Business が在ることを確認（RichClient ビルド漏れ検知）。
if ($needRichClient -and
    -not (Test-Path (Join-Path $vendor 'net10.0-windows7.0\OpenTouryo.Business.dll'))) {
    throw "RichClient sample but net10.0-windows7.0\OpenTouryo.Business.dll missing (run 3_Build_BusinessRichClient_netcore100)."
}
```

> **既知の警告（本体側）**：core サンプル（例 Core MVC）は `log4net 3.2.0` を `PackageReference` で参照するため、
> ビルドで **`NU1902`（脆弱性・中）** が出ることがある。**ビルドは通る**。本体のバージョン更新待ちの既知事項なので、
> セットアップ側で無理に差し替えない（差し替えると本体構成から乖離する）。

## `build-app.ps1`（restore → WebForms ソリューションを一括ビルド → ツール）

**参照方式（更新）**：`WSServer_sample`/`WSIFType_sample` は **ProjectReference**（サンプル自身の B・D層/型＝P・B・D 並行開発。
`samples/webservices.md`）。よって**WS を別ビルドして `WS_sample\Build\` へ DLL コピーする旧手順は不要**＝WebForms
ソリューションに WS 2プロジェクトを含めて一括ビルドすれば WS も同時に建つ。`MySql.Data`/`Oracle`（3rd-party）だけは
DLL 参照のままベンダ先 `Build_net48\` を指す（`references/reference-rewrite.md`）。

```powershell
# Build the WebForms sample (3-layer, WS in-process) against the vendored
# OpenTouryo base DLLs. Reproducible from a fresh clone:
#   1. nuget restore + build the WebForms solution (WSServer/WSIFType are
#      ProjectReferences in the .sln -> built in-solution; no copy to Build\)
#   2. (optional) build the dev tools taken out under OT_Tools\
# Prereq: run setup-build.ps1 once first (populates OpenTouryoAssemblies\).
# Prereq: the .sln includes WSIFType_sample/WSServer_sample and the WebForms
#   csproj references them via <ProjectReference> (DLL HintPath to WS_sample\Build
#   removed); OpenTouryo.* -> OpenTouryoAssemblies\Build_net48 (all projects);
#   MySql.Data/Oracle.ManagedDataAccess -> the vendor folder. See webservices.md.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot   # scripts\ に置く前提＝親がリポジトリ ルート

# --- resolve msbuild (VS 2019/2022/18) via vswhere ---
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msb = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild `
        -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
if (-not $msb) { throw "MSBuild not found (install VS Build Tools / Community)" }

$nuget = Join-Path $repo 'tools\nuget.exe'

# --- 1. restore + build the WebForms solution (WS built in-solution via ProjectReference) ---
$wfSln = Join-Path $repo 'WebForms_Sample\WebForms_Sample.sln'
& $nuget restore $wfSln   # msbuild /t:restore won't restore packages.config
if ($LASTEXITCODE -ne 0) { throw "nuget restore failed ($LASTEXITCODE)" }
& $msb $wfSln /p:Configuration=Debug /nologo /v:m
if ($LASTEXITCODE -ne 0) { throw "WebForms build failed ($LASTEXITCODE)" }

# --- 2. (optional) build the dev tools (DaoGen_Tool / DPQuery_Tool) ---
# Taken out from Frameworks\Tools and grouped under OT_Tools\. Their csproj
# MIX <Reference>+HintPath (OpenTouryo.* / MySql.Data / Oracle -> rewrite to the
# vendor folder in ⑤; 2 levels deep => ..\..\) with <PackageReference>
# (Microsoft.Data.SqlClient etc.). PackageReference needs a restore even on net48
# (no packages.config); skipping it -> CS0234 on `using Microsoft.Data.SqlClient;`.
# Building them here surfaces that at setup time. (HintPaths already rewritten.)
foreach ($tool in 'DaoGen_Tool','DPQuery_Tool') {
    $toolSln = Join-Path $repo "OT_Tools\$tool\$tool.sln"
    if (-not (Test-Path $toolSln)) { continue }
    & $msb $toolSln /t:restore,build /p:Configuration=Debug /nologo /v:m
    if ($LASTEXITCODE -ne 0) { throw "$tool build failed ($LASTEXITCODE)" }
}
Write-Host "Build OK." -ForegroundColor Green
```

（ビルド後、実際に動くことの確認＝IIS Express でのスモークは `opentouryo-project-setup-config` の
`references/run-verify.md`。）
