#Requires -Version 7.0
<#
.SYNOPSIS
    OpenTouryo 用のコーディングエージェント・アセットを、対象リポジトリへインストールする。

.DESCRIPTION
    src/instructions/AGENTS.md（概要）と src/skills/*（コードの書き方）を、
    プロダクトごとの規定の場所へ配置する。

    スキルは Agent Skills のオープン標準（SKILL.md）に準拠しているため全プロダクト共通で、
    配置先が異なるだけ。インストラクションのみプロダクト差分を吸収する。

      プロダクト   インストラクション                      スキル
      ---------------------------------------------------------------------
      claude       CLAUDE.md（AGENTS.md を @ import）      .claude/skills/
      copilot      .github/copilot-instructions.md（複製）  .github/skills/
      agents       AGENTS.md のみ                          .agents/skills/

    AGENTS.md はどのプロダクトでも対象リポジトリのルートに配置される（これが原本）。
    Claude Code は AGENTS.md を読まないため、@ import する CLAUDE.md を別途生成する。

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

.EXAMPLE
    ./install.ps1 -Product claude -TargetRoot C:\git\MyApp
    Claude Code 向けに全スキルをインストールする。

.EXAMPLE
    ./install.ps1 -Product claude,copilot -Skill opentouryo-layer-d,opentouryo-layer-b
    Claude Code と GitHub Copilot 向けに、D層とB層のスキルのみをインストールする。

.EXAMPLE
    ./install.ps1 -Product agents -WhatIf
    実際には書き込まず、何が行われるかを表示する。
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('claude', 'copilot', 'agents')]
    [string[]]$Product,

    [string]$TargetRoot = (Get-Location).Path,

    [string[]]$Skill,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# このスクリプトが生成したファイルの目印。再実行時の安全な上書き判定に使う。
$GeneratedMarker = '<!-- opentouryo-agent-assets:generated -->'

$SourceRoot = Split-Path -Parent $PSScriptRoot
$InstructionsSource = Join-Path $SourceRoot 'src/instructions/AGENTS.md'
$SkillsSource = Join-Path $SourceRoot 'src/skills'

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
        $existing = Get-Content -Path $Path -Raw
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
        Set-Content -Path $Path -Value $Content -Encoding utf8NoBOM -NoNewline
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

# ---- 実行 ----

if (-not (Test-Path $InstructionsSource)) {
    throw "インストラクションの原本が見つかりません: $InstructionsSource"
}

$TargetRoot = (Resolve-Path $TargetRoot).Path
$skills = Resolve-Skills -Requested $Skill
$instructionsBody = Get-Content -Path $InstructionsSource -Raw

Write-Host "インストール先: $TargetRoot"
Write-Host "対象プロダクト: $($Product -join ', ')"
Write-Host "対象スキル: $($skills.Name -join ', ')"
Write-Host ''

# AGENTS.md は全プロダクト共通の原本としてルートに配置する。
Write-Host 'インストラクション (共通):'
$agentsMd = "$GeneratedMarker`n$instructionsBody"
Write-AssetFile -Path (Join-Path $TargetRoot 'AGENTS.md') -Content $agentsMd

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
