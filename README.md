# OpenTouryoCodingAgentAssets

Assets used by coding agents utilizing OpenTouryo

[OpenTouryo](https://github.com/OpenTouryoProject/OpenTouryo) を利用したアプリケーション開発を、
コーディングエージェント（Claude Code / GitHub Copilot / Codex など）に行わせるためのアセット集。

## 構成

```
src/
  instructions/AGENTS.md        概要・規約（常時コンテキストに載る / これが原本）
  skills/
    opentouryo-layer-p/         P層（プレゼンテーション層）の実装
    opentouryo-layer-b/         B層（業務ロジック層）の実装
    opentouryo-layer-d/         D層（データアクセス層）の実装
    opentouryo-exception/       例外処理方式
    opentouryo-common/          共通基盤（ログ・認証・設定）
install/
  install.ps1                   対象リポジトリへのインストーラ
docs/
  authoring.md                  アセット執筆ガイド
```

**インストラクション**（概要）と**スキル**（具体的なコードの書き方）に分かれている。
前者は常にコンテキストへ載り、後者はエージェントが必要と判断したときだけ読まれる。
使い分けの基準は [docs/authoring.md](docs/authoring.md) を参照。

## スキルの互換性

スキルは [Agent Skills のオープン標準](https://agentskills.io/specification)（`SKILL.md`）に準拠している。
Claude Code / GitHub Copilot / Cursor / Codex CLI / Gemini CLI など、標準に対応した
30以上のツールが同一のスキルを読める。**1回書けば全プロダクトで使える。**

プロダクト差分はインストラクション側にのみ存在し、インストーラが吸収する。

## インストール

```powershell
# Claude Code 向けに全スキルをインストール
./install/install.ps1 -Product claude -TargetRoot C:\git\MyApp

# 複数プロダクト・スキルを絞って
./install/install.ps1 -Product claude,copilot -Skill opentouryo-layer-d

# 実際には書き込まず、何が行われるか確認
./install/install.ps1 -Product agents -WhatIf
```

### 配置先

| プロダクト | インストラクション | スキル |
| --- | --- | --- |
| `claude` | `CLAUDE.md`（`AGENTS.md` を `@` import） | `.claude/skills/` |
| `copilot` | `.github/copilot-instructions.md`（複製） | `.github/skills/` |
| `agents` | `AGENTS.md` | `.agents/skills/` |

`AGENTS.md` はどのプロダクトでも対象リポジトリのルートへ配置される（これが原本）。
Claude Code は `AGENTS.md` を読まないため、それを `@` import する `CLAUDE.md` を別途生成する。

既存ファイルは、インストーラが生成したもの（生成マーカー付き）でない限り上書きされない。
上書きするには `-Force` を指定する。

## ライセンス

[MIT](LICENSE)
