# OpenTouryoCodingAgentAssets

Assets used by coding agents utilizing OpenTouryo

[OpenTouryo](https://github.com/OpenTouryoProject/OpenTouryo) を利用したアプリケーション開発を、
コーディングエージェント（Claude Code / GitHub Copilot / Codex など）に行わせるためのアセット集。

## 構成

```
src/
  instructions/AGENTS.md        概要・規約（常時コンテキストに載る / これが原本）
  skills/                       全スキル（用途別の一覧・使いどころは下の「スキル一覧」節）
  docs/                         配布物：spec/plan/tutorial の見本（-IncludeTutorial で導入先の docs/ へ）
install/
  install.ps1                   対象リポジトリへのインストーラ
docs/
  authoring.md                  アセット執筆ガイド（このリポジトリ用・導入先へは配らない）
```

**インストラクション**（概要）と**スキル**（具体的なコードの書き方）に分かれている。
前者は常にコンテキストへ載り、後者はエージェントが必要と判断したときだけ読まれる。
使い分けの基準は [docs/authoring.md](docs/authoring.md) を参照。

## スキル一覧

用途・利用者で分類（アルファベット順ではない）。**エージェントは各スキルの `description` で自動的に選ぶ**ので、この表は
主に人が俯瞰するための索引。

**`└` はファサード／概観スキルの配下**（親が呼び出す・詳細を委ねる先）を表す：`opentouryo-project-setup`＝セットアップ手順のファサード、
`opentouryo-layer-d`＝Dao 3系統の概観、`opentouryo-app-design`＝設計フェーズの地図（配下の子スキルは個別課題ごとに順次追加）。その他の関連（利用・相互参照）は厳密な親子ではなく、各スキルの `description` に記載。

### ① 立ち上げ・構成（初期設定：立ち上げ担当／纏め者。主に一度きり）

| スキル | 使いどころ |
| --- | --- |
| `opentouryo-project-setup` | 新規プロジェクトをゼロから立ち上げるときの**入口＝ファサード**（全体の流れと呼び出し順のみ・**配下は下記 `└`**） |
| └ `opentouryo-project-setup-selection` | ①② 起点サンプルの選択（全系列を提示）と取得元 `<ref>`（固定タグ / develop）の決定 |
| └ `opentouryo-project-setup-build` | ③ 基盤 DLL をローカルでビルドして `OpenTouryoAssemblies\` へベンダ（タグ更新の焼き直しにも単独で） |
| └ `opentouryo-project-setup-core` | ④⑤ サンプル（＋開発支援ツール）の取り出しと `OpenTouryo.*` HintPath 張替（3層/WS の CS0246 解消も） |
| └ `opentouryo-project-setup-config` | ⑥⑦ resource 移設・config パス張替（`%OT_RESOURCE_ROOT%`）・`.gitignore`・ビルド／実行検証 |
| └ `opentouryo-project-setup-db` | （選択式）ローカルのデータストア（SQL Server 等）を Docker で用意（LocalServicesOnDocker。既存 DB があれば不要） |
| └ `opentouryo-project-transform` | （セットアップ後）取り出したサンプルを用途へ変形（2層化・サンプル整理・CS0246 解消） |
| `opentouryo-project-policy` | 「このプロジェクトではどうなっているか」（親クラス2 の実装で決まる仕様）が分からないとき |
| `opentouryo-base2-customize` | **纏め者が**親クラス2（基盤 Business 層）の共通処理をカスタマイズするとき（アプリ開発者は使わない） |

### ② 各層のコード実装（日常常用：アプリ開発者）

| スキル | 使いどころ |
| --- | --- |
| `opentouryo-app-design` | **設計フェーズの地図**：spec/plan で決める設計事項（レイヤ/例外/Tx/データアクセス/画面/認証…）を各実装スキルへ割り付け（**配下の子スキルは今後追加**） |
| `opentouryo-layer-p-mvc` | ASP.NET MVC / ASP.NET Core MVC のコントローラを実装するとき |
| `opentouryo-layer-p-webforms-screen` | Web Forms の画面を新規作成するとき |
| `opentouryo-layer-p-webforms-event` | Web Forms のコントロールのイベントを実装するとき |
| `opentouryo-webforms-dialog` | Web Forms で子画面（ダイアログ・モーダル/モードレス）を表示するとき |
| `opentouryo-layer-p-winforms-screen` | Windows Forms の画面を新規作成するとき |
| `opentouryo-layer-p-winforms-event` | Windows Forms のコントロールのイベントを実装するとき |
| `opentouryo-p-call-business` | P層から B層を呼ぶとき（引数クラス・`DoBusinessLogic`・`ErrorFlag`） |
| `opentouryo-richclient-async` | リッチクライアント（WinForms / WPF）で B層を非同期に呼ぶとき |
| `opentouryo-layer-b` | 業務ロジックを実装するとき |
| `opentouryo-exception` | 例外を扱うとき（**全層で常用する横断・層を問わず参照**。「業務例外はリスローされない」等の必須ルール） |
| `opentouryo-layer-d` | D層の全体像と Dao 3系統の使い分け（**概観。配下は下記 `└`**） |
| └ `opentouryo-dao-custom` | 個別Dao（業務固有のデータアクセス）を実装するとき |
| └ `opentouryo-dao-common` | 共通Dao（`CmnDao`）で単発の SQL を実行するとき |
| └ `opentouryo-dao-generated` | 自動生成Dao（テーブル単位の CRUD・楽観排他）を使うとき |
| └ `opentouryo-daogen-cli` | 自動生成Dao をツール（墨壺）の CLI（`/CUI`・非対話）で生成するとき |
| `opentouryo-batch-update` | DataTable の RowState でグリッド明細を一括更新（追加/更新/削除）するとき |
| `opentouryo-webforms-crud-screens` | Web Forms のテーブル保守 CRUD 画面を作るとき（一覧→詳細／一覧＆更新・ページング・結果セット固定） |
| `opentouryo-mvc-crud-screens` | ASP.NET (Core) MVC のテーブル保守 CRUD 画面を作るとき（一覧→詳細／一覧＆更新・RowState バッチ・`@section`＋`form=`・Core は編集中 DataTable を `DTTables` JSON で Session 保持） |
| `opentouryo-winforms-crud-screens` | Windows Forms（2層C/S／3層WSクライアント）のテーブル保守 CRUD 画面を作るとき（一覧→詳細／一覧＆更新・DataGridView 自動バインド＝読み戻し/行内ボタン不要・CommitGridEdits・2CS 手動トランザクション） |
| `opentouryo-query-definition` | SQL 定義ファイル（`.sql` / `.xml`）を書くとき |
| `opentouryo-comment-convention` | **全層・全ファイル共通**：新規コードファイルのヘッダ（所属機能名／クラス情報／更新履歴）とコメント規則 |

### ③ 制御・定義／横断機能（機能利用：必要になったとき参照）

| スキル | 使いどころ |
| --- | --- |
| `opentouryo-message` | メッセージを定義・取得するとき（`MSGDefinition.xml`） |
| `opentouryo-shared-property` | 共有情報を定義・取得するとき（`SPDefinition.xml`） |
| `opentouryo-transaction-control` | トランザクション パターンを定義するとき（`TCDefinition.xml`） |
| `opentouryo-screen-transition` | 画面遷移制御を定義するとき（`SCDefinition.xml`。Web Forms 専用） |
| `opentouryo-transmission` | 通信制御（サービス論理名で B層を呼ぶ）を扱うとき |
| `opentouryo-webapi-server` | ASP.NET Core の Web API サーバ（OAuth2 リソースサーバ）を作るとき（`[MyBaseAsyncApiController]`・Bearer・DTTables JSON・OpenAPI/CORS） |
| `opentouryo-webapi-client` | その Web API を .NET から呼ぶとき（HTTP＋JSON・Bearer・DataTable を DTTables JSON で往復） |
| `opentouryo-logging` | ログを出力するとき |
| `opentouryo-config` | 設定値を読むとき、構成ファイルを書くとき |
| `opentouryo-auth` | 認証・ユーザ情報を扱うとき |
| `opentouryo-oauth2-client` | 外部 IdP と連携するとき（OAuth2 / OIDC のクライアント＝RP） |
| `opentouryo-common-parts` | ユーティリティ（文字列チェック・エンコード等）を自作する前に既存の共通部品を探すとき |

### ④ レビュー・フェーズ（実装・実行の後：実装。実行結果（ログ／エラー／性能）を分析して対応を提案）

| スキル | 使いどころ |
| --- | --- |
| `opentouryo-log-analysis` | 出力ログ（ACCESS / SQLTRACE 等）からエラー・性能の対応を提案するとき |

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

# 評価用チュートリアル一式（docs/spec|plan|tutorial/tutorial1.md）も配置（opt-in）
./install/install.ps1 -Product claude -TargetRoot C:\git\MyApp -IncludeTutorial
```

### 開発の進め方とチュートリアル

規模のある変更は **spec → plan → 実装** で進めるのを推奨する（仕様を `docs/spec/`、計画を `docs/plan/` に置いてから実装）。
`-IncludeTutorial` を付けると、この流れを通しで試すサンプル（`docs/spec|plan|tutorial/tutorial1.md`）を導入先へ配置する。
`docs/spec`・`docs/plan` は利用者の作業ディレクトリなので、**再実行しても既存ファイルは上書きしない**（`-Force` でのみ上書き）。

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
