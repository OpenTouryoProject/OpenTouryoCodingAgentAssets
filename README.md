# OpenTouryoCodingAgentAssets

Assets used by coding agents utilizing OpenTouryo

[OpenTouryo](https://github.com/OpenTouryoProject/OpenTouryo) を利用したアプリケーション開発を、
コーディングエージェント（Claude Code / GitHub Copilot / Codex など）に行わせるためのアセット集。

## 構成

```
src/
  instructions/AGENTS.md        概要・規約（常時コンテキストに載る / これが原本）
  skills/                       全34スキル（用途別の一覧・使いどころは下の「スキル一覧」節）
install/
  install.ps1                   対象リポジトリへのインストーラ
docs/
  authoring.md                  アセット執筆ガイド
```

**インストラクション**（概要）と**スキル**（具体的なコードの書き方）に分かれている。
前者は常にコンテキストへ載り、後者はエージェントが必要と判断したときだけ読まれる。
使い分けの基準は [docs/authoring.md](docs/authoring.md) を参照。

## スキル一覧

用途・利用者で分類（アルファベット順ではない）。**エージェントは各スキルの `description` で自動的に選ぶ**ので、この表は
主に人が俯瞰するための索引。

### ① 立ち上げ・構成（初期設定：立ち上げ担当／纏め者。主に一度きり）

| スキル | 使いどころ |
| --- | --- |
| `opentouryo-project-setup` | 新規プロジェクトをゼロから立ち上げるときの**入口＝ファサード**（全体の流れと呼び出し順のみ） |
| `opentouryo-project-setup-selection` | ①② 起点サンプルの選択（全系列を提示）と取得元 `<ref>`（固定タグ / develop）の決定 |
| `opentouryo-project-setup-build` | ③ 基盤 DLL をローカルでビルドして `OpenTouryoAssemblies\` へベンダ（タグ更新の焼き直しにも単独で） |
| `opentouryo-project-setup-core` | ④⑤ サンプル（＋開発支援ツール）の取り出しと `OpenTouryo.*` HintPath 張替（3層/WS の CS0246 解消も） |
| `opentouryo-project-setup-config` | ⑥⑦ resource 移設・config パス張替（`%OT_RESOURCE_ROOT%`）・`.gitignore`・ビルド／実行検証 |
| `opentouryo-project-setup-db` | （選択式）ローカルのデータストア（SQL Server 等）を Docker で用意（LocalServicesOnDocker。既存 DB があれば不要） |
| `opentouryo-project-transform` | セットアップ後、取り出したサンプルを用途へ変形（2層化・サンプル整理・CS0246 解消） |
| `opentouryo-project-policy` | 「このプロジェクトではどうなっているか」（親クラス2 の実装で決まる仕様）が分からないとき |
| `opentouryo-base2-customize` | **纏め者が**親クラス2（基盤 Business 層）の共通処理をカスタマイズするとき（アプリ開発者は使わない） |

### ② 各層のコード実装（日常常用：アプリ開発者）

| スキル | 使いどころ |
| --- | --- |
| `opentouryo-layer-p-mvc` | ASP.NET MVC / ASP.NET Core MVC のコントローラを実装するとき |
| `opentouryo-layer-p-webforms-screen` | Web Forms の画面を新規作成するとき |
| `opentouryo-layer-p-webforms-event` | Web Forms のコントロールのイベントを実装するとき |
| `opentouryo-webforms-dialog` | Web Forms で子画面（ダイアログ・モーダル/モードレス）を表示するとき |
| `opentouryo-layer-p-winforms-screen` | Windows Forms の画面を新規作成するとき |
| `opentouryo-layer-p-winforms-event` | Windows Forms のコントロールのイベントを実装するとき |
| `opentouryo-p-call-business` | P層から B層を呼ぶとき（引数クラス・`DoBusinessLogic`・`ErrorFlag`） |
| `opentouryo-richclient-async` | リッチクライアント（WinForms / WPF）で B層を非同期に呼ぶとき |
| `opentouryo-layer-b` | 業務ロジックを実装するとき |
| `opentouryo-layer-d` | D層の全体像と Dao 3系統の使い分け |
| `opentouryo-dao-custom` | 個別Dao（業務固有のデータアクセス）を実装するとき |
| `opentouryo-dao-common` | 共通Dao（`CmnDao`）で単発の SQL を実行するとき |
| `opentouryo-dao-generated` | 自動生成Dao（テーブル単位の CRUD・楽観排他）を使うとき |
| `opentouryo-query-definition` | SQL 定義ファイル（`.sql` / `.xml`）を書くとき |

### ③ 制御・定義／横断機能（機能利用：必要になったとき参照）

| スキル | 使いどころ |
| --- | --- |
| `opentouryo-message` | メッセージを定義・取得するとき（`MSGDefinition.xml`） |
| `opentouryo-shared-property` | 共有情報を定義・取得するとき（`SPDefinition.xml`） |
| `opentouryo-transaction-control` | トランザクション パターンを定義するとき（`TCDefinition.xml`） |
| `opentouryo-screen-transition` | 画面遷移制御を定義するとき（`SCDefinition.xml`。Web Forms 専用） |
| `opentouryo-transmission` | 通信制御（サービス論理名で B層を呼ぶ）を扱うとき |
| `opentouryo-exception` | 例外を扱うとき。層を問わず参照する |
| `opentouryo-logging` | ログを出力するとき |
| `opentouryo-log-analysis` | 出力ログ（ACCESS/SQLTRACE 等）からエラー・性能の対応を提案するとき |
| `opentouryo-config` | 設定値を読むとき、構成ファイルを書くとき |
| `opentouryo-auth` | 認証・ユーザ情報を扱うとき |
| `opentouryo-oauth2-client` | 外部 IdP と連携するとき（OAuth2 / OIDC のクライアント＝RP） |
| `opentouryo-common-parts` | ユーティリティ（文字列チェック・エンコード等）を自作する前に既存の共通部品を探すとき |

## スキルの互換性

スキルは [Agent Skills のオープン標準](https://agentskills.io/specification)（`SKILL.md`）に準拠している。
Claude Code / GitHub Copilot / Cursor / Codex CLI / Gemini CLI など、標準に対応した
30以上のツールが同一のスキルを読める。**1回書けば全プロダクトで使える。**

プロダクト差分はインストラクション側にのみ存在し、インストーラが吸収する。

## インストール

このリポジトリを **git clone** し、**clone した場所からインストーラを実行する**。
`install.ps1` は隣接する `src/`（`instructions` / `skills`）を読むため、**単体でコピーしても動かない**。
導入先のアプリ リポジトリは `-TargetRoot` で指定する（既定はカレント ディレクトリ）。
**Windows PowerShell 5.1 / PowerShell 7 のどちらでも動く。**

```powershell
# ① このリポジトリを取得
git clone https://github.com/OpenTouryoProject/OpenTouryoCodingAgentAssets.git
cd OpenTouryoCodingAgentAssets

# ② clone した場所から実行。導入先は -TargetRoot（Claude Code 向けに全スキル）
./install/install.ps1 -Product claude -TargetRoot C:\git\MyApp

# 複数プロダクト・スキルを絞って
./install/install.ps1 -Product claude,copilot -Skill opentouryo-layer-d -TargetRoot C:\git\MyApp

# 実際には書き込まず、何が行われるか確認
./install/install.ps1 -Product agents -WhatIf -TargetRoot C:\git\MyApp
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
