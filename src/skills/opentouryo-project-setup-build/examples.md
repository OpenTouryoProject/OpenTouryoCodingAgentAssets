# 参考：as-built セットアップ スクリプト（PowerShell 雛形）

実環境（WebForms_Sample / net48 / 固定タグ `03-20` / 深いリポ パス）で**実際に通した2本**。
本スキルが推奨する「生成スクリプトをリポジトリに残す・`.bat` より PowerShell ラッパ」の具体例で、
既知の落とし穴（MAX_PATH＝短い作業ルート、exit code 不信＝DLL 実在で判定、`.\`＋`< nul`、
WS の `bin\Debug` → `WS_sample\Build\` 配置）を織り込み済み。

**雛形化する際は `$ref`・パス・標的ランタイム（net48）をパラメタ化**する。フラット化しない
（配置維持）方針なら `build-app.ps1` の相対パスは配置に合わせて変える。

- `setup-build.ps1` — 本スキル ①②③（ZIP取得 → net48 基盤ビルド → ベンダ）。短パス `C:\ot` でビルド、
  `OpenTouryo.Business.dll` の実在で成否判定。
- `build-app.ps1` — アプリ側の取り出し後ビルド（`opentouryo-project-setup` ④⑤ / `samples/webforms.md` 構成A）。
  WS をビルド**して `WS_sample\Build\` へ配置**、`nuget restore` → WebForms ビルド。vswhere で msbuild 解決。

## `setup-build.ps1`（ZIP取得 → net48 基盤ビルド → ベンダ）

```powershell
# Download archive/<ref>.zip -> build net48 base -> vendor to
# OpenTouryoAssemblies\Build_net48. Idempotent; re-run to refresh a tag.
$ErrorActionPreference = 'Stop'
$repo    = $PSScriptRoot
$ref     = '03-20'                       # fixed tag (stable operation)
# Base build runs from a SHORT root (C:\ot), not <repo>\Temp: the legacy
# net48 Business build writes a very long generated .resources filename;
# under a deep repo path the fully-qualified path exceeds MAX_PATH (MSB3553).
# Only scratch/build output lives here; vendored DLLs land in <repo>.
$work    = 'C:\ot'
$zip     = Join-Path $work "OpenTouryo-$ref.zip"
$extract = Join-Path $work "OpenTouryo-$ref"
$cs      = Join-Path $extract 'root\programs\CS'
$vendor  = Join-Path $repo 'OpenTouryoAssemblies\Build_net48'

# --- 1. ZIP acquisition (not git clone) ---
New-Item -ItemType Directory -Force -Path $work | Out-Null
if (-not (Test-Path $extract)) {
    if (-not (Test-Path $zip)) {
        (New-Object System.Net.WebClient).DownloadFile(
            "https://github.com/OpenTouryoProject/OpenTouryo/archive/$ref.zip", $zip)
    }
    Expand-Archive -Path $zip -DestinationPath $work -Force
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
Get-ChildItem $vendor -Filter 'OpenTouryo.*.dll' | Select-Object -ExpandProperty Name
```

## `build-app.ps1`（WS ビルド＋`Build\` 配置 → restore → WebForms ビルド）

```powershell
# Build the WebForms sample (3-layer, WS in-process) against the vendored
# OpenTouryo base DLLs. Reproducible from a fresh clone:
#   1. build WS (WSServer builds WSIFType) and refresh WS_sample\Build
#   2. nuget restore + build the WebForms solution
# Prereq: run setup-build.ps1 once first (populates OpenTouryoAssemblies\).
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot

# --- resolve msbuild (VS 2019/2022/18) via vswhere ---
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$msb = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild `
        -find MSBuild\**\Bin\MSBuild.exe | Select-Object -First 1
if (-not $msb) { throw "MSBuild not found (install VS Build Tools / Community)" }

$vendor  = Join-Path $repo 'OpenTouryoAssemblies\Build_net48'
$wsRoot  = Join-Path $repo 'WS_sample'
$wsBuild = Join-Path $wsRoot 'Build'

# --- 1. build WS layer and refresh WS_sample\Build ---
# `.sln` build outputs to each project's bin\Debug; WS_sample\Build is NOT
# created by the sln build, so copy the DLLs there (that is where WebForms
# references them). Also place the two DB DLLs from the vendor folder.
& $msb (Join-Path $wsRoot 'WSServer_sample\WSServer_sample.sln') /p:Configuration=Debug /nologo /v:m
if ($LASTEXITCODE -ne 0) { throw "WS build failed ($LASTEXITCODE)" }
New-Item -ItemType Directory -Force -Path $wsBuild | Out-Null
Copy-Item (Join-Path $wsRoot 'WSIFType_sample\bin\Debug\WSIFType_sample.dll') $wsBuild -Force
Copy-Item (Join-Path $wsRoot 'WSServer_sample\bin\Debug\WSServer_sample.dll') $wsBuild -Force
Copy-Item (Join-Path $vendor 'MySql.Data.dll')               $wsBuild -Force
Copy-Item (Join-Path $vendor 'Oracle.ManagedDataAccess.dll') $wsBuild -Force

# --- 2. restore + build WebForms ---
$wfSln = Join-Path $repo 'WebForms_Sample\WebForms_Sample.sln'
& (Join-Path $repo 'tools\nuget.exe') restore $wfSln   # msbuild /t:restore won't restore packages.config
if ($LASTEXITCODE -ne 0) { throw "nuget restore failed ($LASTEXITCODE)" }
& $msb $wfSln /p:Configuration=Debug /nologo /v:m
if ($LASTEXITCODE -ne 0) { throw "WebForms build failed ($LASTEXITCODE)" }
Write-Host "Build OK." -ForegroundColor Green
```
