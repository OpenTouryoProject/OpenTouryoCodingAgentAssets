# OpenTouryoCodingAgentAssets

Assets used by coding agents utilizing OpenTouryo

[OpenTouryo](https://github.com/OpenTouryoProject/OpenTouryo) を利用したアプリケーション開発を、
コーディングエージェント（Claude Code / GitHub Copilot / Codex など）に行わせるためのアセット集。

アセットは 3 つに分かれる。

| 部 | 何のためか | 中身（原本） | 導入（`install/install.ps1`） |
| --- | --- | --- | --- |
| [1. 書き方](#1-書き方--インストラクションスキル役の定義) | OpenTouryo でどう書くか | `src/instructions/`（`AGENTS.md`・`TESTING.md`）・`src/skills/`（46 本）・`src/agents/`（テスト先行の実装役・レビュー役） | `-Product` |
| [2. 守り方](#2-守り方--品質の仕組み) | 承認したテストを、後から黙って弱めさせない | `src/quality/ExpectationGuard/`（期待値の変更の検出器・トレーラーの検査・要確認） | **AI に頼む**（[手順](src/quality/ExpectationGuard/INSTALL.md)。中で `-IncludeQualityGuard` を使う。opt-in） |
| [3. 進め方](#3-進め方--見本検証教材) | spec → テスト → plan → 実装を通しで回す | `src/docs/`（spec・plan・prompt の見本。テスト先行は司令役の手順） | `-IncludeTutorial`（opt-in） |

```
src/
  instructions/AGENTS.md        1. 概要・規約（常時コンテキストに載る / これが原本）
  instructions/TESTING.md       1. テスト先行の進め方と、承認の 2 段（AGENTS.md から参照。AGENTS.md と同じくルートへ）
  skills/                       1. 全スキル（下の「スキル一覧」）
  agents/                       1. 役の定義：テスト先行の実装役・レビュー役（Claude Code 向け。.claude/agents へ）
  quality/ExpectationGuard/     2. 期待値の変更の検出器の原本（導入先へ写す。INSTALL.md は導入する AI が読む手順で、写さない）
  docs/                         3. spec・plan・prompt の見本（導入先の docs/ へ）
install/
  install.ps1                   対象リポジトリへのインストーラ
docs/
  authoring.md                  アセット執筆ガイド（このリポジトリ用・導入先へは配らない）
  expectation-guard.md          検出器の切り分け・設計・検証の記録（このリポジトリ用）
```

## インストール

このリポジトリを **git clone** し、**clone した場所からインストーラを実行する**。
`install.ps1` は隣接する `src/` を読むため、**単体でコピーしても動かない**。
導入先のアプリ リポジトリは `-TargetRoot` で指定する（既定はカレント ディレクトリ）。
**Windows PowerShell 5.1 / PowerShell 7 のどちらでも動く。**

```powershell
# ① このリポジトリを取得
git clone https://github.com/OpenTouryoProject/OpenTouryoCodingAgentAssets.git
cd OpenTouryoCodingAgentAssets

# ② 1. 書き方（Claude Code 向けに全スキル・役の定義）
./install/install.ps1 -Product claude -TargetRoot C:\git\MyApp

# 複数プロダクト・スキルを絞って
./install/install.ps1 -Product claude,copilot -Skill opentouryo-layer-d -TargetRoot C:\git\MyApp

# 実際には書き込まず、何が行われるか確認
./install/install.ps1 -Product agents -WhatIf -TargetRoot C:\git\MyApp

# 3. 進め方も併せて（opt-in）
./install/install.ps1 -Product claude -TargetRoot C:\git\MyApp -IncludeTutorial
```

**2. 守り方（検出器）は、コマンドではなく AI に頼んで導入する**（導入先ごとの判断が多いため。[2. 守り方](#2-守り方--品質の仕組み)）。

既存ファイルは、インストーラが生成したもの（生成マーカー付き）でない限り上書きされない。上書きするには `-Force` を指定する。
2・3 の扱い（導入先が持つファイル・写し）は、それぞれの部に書く。

---

## 1. 書き方 — インストラクション・スキル・役の定義

**インストラクション**（概要）と**スキル**（具体的なコードの書き方）に分かれている。
前者は常にコンテキストへ載り、後者はエージェントが必要と判断したときだけ読まれる。
使い分けの基準は [docs/authoring.md](docs/authoring.md) を参照。

- `AGENTS.md`：OpenTouryo を使うプロジェクトの概要・規約（層・例外・Git の扱い・コミット メッセージのトレーラーなど）。
- `TESTING.md`：テスト先行の進め方（テスト仕様 → Red → Green、根拠の ID、期待値の変更とトレーラー）と、**承認の 2 段**
  （テストの質は実装役と別のレビュー役が確かめ、人は**仕様の決定だけ**を GO/NOGO で判断する）。
- 役の定義（`src/agents/`）：テスト先行の**実装役**（`opentouryo-test-implementer`）と**レビュー役**（`opentouryo-test-reviewer`。編集できず、テストを自分で実行する）。
  司令役（指示を受けたセッション）がサブ エージェントとして回す。**Claude Code 向けのみ**（Copilot 向けは未対応）。

### スキル一覧

用途・利用者で分類（アルファベット順ではない）。**エージェントは各スキルの `description` で自動的に選ぶ**ので、この表は
主に人が俯瞰するための索引。

**`└` はファサード／概観スキルの配下**（親が呼び出す・詳細を委ねる先）を表す：`opentouryo-project-setup`＝セットアップ手順のファサード、
`opentouryo-layer-d`＝Dao 3系統の概観、`opentouryo-app-design`＝設計フェーズの地図（配下の子スキルは個別課題ごとに順次追加）。その他の関連（利用・相互参照）は厳密な親子ではなく、各スキルの `description` に記載。

#### ① 立ち上げ・構成（初期設定：立ち上げ担当／纏め者。主に一度きり）

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

#### ② 各層のコード実装（日常常用：アプリ開発者）

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
| `opentouryo-test-layer-b` | B層のルート メソッドの単体テスト（NUnit・`<Web>.Tests`）を先に書くとき（テスト先行＝`TESTING.md` の段 2） |
| `opentouryo-test-e2e-web` | 画面の E2E テスト（NUnit・Playwright・`<Web>.E2ETests`。ASP.NET Core MVC で実測）を先に書くとき |
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

#### ③ 制御・定義／横断機能（機能利用：必要になったとき参照）

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

#### ④ レビュー・フェーズ（実装・実行の後：実装。実行結果（ログ／エラー／性能）を分析して対応を提案）

| スキル | 使いどころ |
| --- | --- |
| `opentouryo-log-analysis` | 出力ログ（ACCESS / SQLTRACE 等）からエラー・性能の対応を提案するとき |

### スキルの互換性

スキルは [Agent Skills のオープン標準](https://agentskills.io/specification)（`SKILL.md`）に準拠している。
Claude Code / GitHub Copilot / Cursor / Codex CLI / Gemini CLI など、標準に対応した
30以上のツールが同一のスキルを読める。**1回書けば全プロダクトで使える。**

プロダクト差分はインストラクション側（と、Claude Code 向けの役の定義）にのみ存在し、インストーラが吸収する。

### 配置先

| プロダクト | インストラクション | スキル | 役の定義 |
| --- | --- | --- | --- |
| `claude` | `CLAUDE.md`（`AGENTS.md` を `@` import） | `.claude/skills/` | `.claude/agents/` |
| `copilot` | `.github/copilot-instructions.md`（複製） | `.github/skills/` | （未対応） |
| `agents` | `AGENTS.md` | `.agents/skills/` | （未対応） |

`AGENTS.md`・`TESTING.md` はどのプロダクトでも対象リポジトリのルートへ配置される（`AGENTS.md` が原本）。
Claude Code は `AGENTS.md` を読まないため、それを `@` import する `CLAUDE.md` を別途生成する。

---

## 2. 守り方 — 品質の仕組み

`-IncludeQualityGuard` を付けると、**承認したテストの期待値を後から変える変更**（テストの削除・Skip / Ignore の追加・根拠の削除・
検証の削除・Golden の変更・検出の仕組み自体の変更など）を検出し、コミット メッセージのトレーラー `Expectation-Change: <理由>` を求める仕組みを写す。
**アサーションの緩和は見ない**（機械的に判定できない。レビューの観点で拾う）。

| 段 | 何をするか | 導入先のファイル |
| --- | --- | --- |
| 1 | エージェントがテストを弱める編集をしたら、人の確認付きにする（止めない） | `.claude/hooks/ExpectationGuard.ps1`（`.claude/settings.json` に登録） |
| 2 | トレーラーの無い期待値の変更のコミットを拒否する | `.githooks/commit-msg`（`git config core.hooksPath .githooks`） |
| 3 | PR で同じ検出をする（**ベース側の版の検出器で見る**＝PR の中で検出器を緩めても素通りしない） | `.github/workflows/expectation-change.yml`（雛形） |

あわせて、次も行う。

| 検査 | 扱い |
| --- | --- |
| トレーラー `Found-By: <手段>`（バグの修正 `fixed #NNN` を、どこで・何で見つけたか） | 語彙に無い値は拒否、無ければ警告。どちらのときも語彙と意味の一覧を出す（語彙は `rules.common.psd1`） |
| トレーラー `Tested-with: <種類>`・`Reviewed-with: <役>`（そのコミットを、どの種類のテストで・どのレビュー役で確かめたか） | 語彙に無い値は拒否（役の語彙は `.claude/agents/` の役の定義の名前と `human`）。書き忘れは警告：コード（`.cs`・`.vb`。コメント・空行だけの変更を除く）を変えたのに `Tested-with:` が無い（`none` で満たせる）、期待値の変更に突き合わせ役の `Reviewed-with:` が無い、リポジトリの規則で足した組（例：リスク「高」の場所の `fixed`） |
| トレーラーの書き方（git が読む形か：最後の段落に置く・半角の「:」・名前の綴り・値が空でない） | 拒否。**書いた行・直した行・直した最後の段落・コミットの直し方を出す**（人がそのまま写して直せる） |
| `Expectation-Change:` の理由と差分の突き合わせ | 理由に Issue 番号・仕様の節が無ければ警告。文面を提案したら、コミットの前に**突き合わせ役**（`opentouryo-expectation-reviewer`。別モデル。検出器と一緒に `.claude/agents` へ入る）が、検出した一覧（`-Json`）・差分・原典と、網羅・一致・根拠・方向・範囲外を突き合わせる（止めない） |
| **要確認**（`[Obsolete]` の追加、`#pragma warning disable CS0618`・`618` の追加） | **止めない・トレーラーを求めない**。一覧に出し、CI では足した行に注釈を付ける（互換のための判断をレビューの目に入れる）。範囲は導入先が選ぶ（`ReviewScope`。省略時はリポジトリ全体） |
| 仕組みのファイル（フック・CI・本体・規則・`.claude/agents/`） | 変更・削除は期待値の変更と同じ扱い（追加は数えない） |

### 導入：AI に頼む

導入先ごとに決めることが多い（本体の置き場所・テストの範囲・要確認の範囲・CI の差・`-Force` の要否・導入先の文書の直し）。
そこで、**このリポジトリを clone し、コーディング エージェントに次のように頼む。**

> OpenTouryoCodingAgentAssets の `src/quality/ExpectationGuard/INSTALL.md` に従って、`C:\git\MyApp` に検出器を導入して。

エージェントは [INSTALL.md](src/quality/ExpectationGuard/INSTALL.md) に従い、次を行う。導入先の変更はワーキング ツリーまでで、コミットは人が行う。

1. 導入先を調べる：既存の検出器と版・CI・テストと製品のコードの在りか・`AGENTS.md`・`QUALITY.md`
2. 判断を対話で聞く：導入の形（新規・写し直し・置き換え）、`-Product` の要否、置き場所、`DiffScope`・`ReviewScope`、CI、文書の反映
3. `install.ps1` を、聞いた答えの引数で動かす（先に `-WhatIf`）
4. `rules.psd1` と、導入先の `AGENTS.md`・`QUALITY.md` のトレーラーの節を合わせる（上書きしない）
5. 判定の用例（5.1・7）・`-VerifyCopy`・実際のコミットでの `-Commit` で確かめ、人が行うことと、コミット メッセージの案を渡す

<details>
<summary>コマンドで導入するとき（AI が中で使うもの）</summary>

```powershell
# スキルと併せて（本体は tools/ExpectationGuard/。-QualityGuardPath で、判定の用例の場所は -QualityGuardTestsPath で変えられる）
./install/install.ps1 -Product claude -TargetRoot C:\git\MyApp -IncludeQualityGuard

# 検出器だけ（AGENTS.md・スキルには触れない。既に自前の検出器があるリポジトリの置き換えには -Force）
./install/install.ps1 -TargetRoot C:\git\MyApp -IncludeQualityGuard
```

コマンドだけで入れたときは、`rules.psd1` の範囲（`DiffScope`・`ReviewScope`）と導入先の文書を、手で合わせる。

</details>

### 写しと規則

- 何を期待値と呼ぶかは、導入先の `rules.psd1`（初回だけ見本から置く。以後は導入先が持つ）に書く。CI の雛形も、初回だけ置いて以後は導入先が持つ（`-Force` でも上書きしない）。
- 本体・共通の規則・フック・判定の用例は**写し**で、先頭付近に原本の版（`src/quality` に最後に触れたコミット）と SHA-256 の行が入る。
  **写しは直さず、原本を直して写し直す**（写し直しも仕組みの変更なので、トレーラーが要る）。導入先の CI は `-VerifyCopy` で写しのずれを警告する。
- 判定の用例（「この差分なら検出する／しない」）を本体と一緒に持ち、導入先の CI でも回す。
- OpenTouryo・MultiPurposeAuthSite も、この原本の写しを使っている。
- 詳細は [src/quality/ExpectationGuard/rules.sample.psd1](src/quality/ExpectationGuard/rules.sample.psd1) と [docs/expectation-guard.md](docs/expectation-guard.md)。

---

## 3. 進め方 — 見本（検証・教材）

規模のある変更は **spec → テスト → plan → 実装** で進めるのを推奨する（仕様を `docs/spec/`、計画を `docs/plan/` に置いてから実装）。
`-IncludeTutorial` を付けると、この流れを通しで試す見本（`src/docs/` の全ファイル）を、相対パスを保ったまま導入先の `docs/` へ配置する。
`docs/spec`・`docs/plan` は利用者の作業ディレクトリなので、**再実行しても既存ファイルは上書きしない**（`-Force` でのみ上書き）。

| 見本 | 中身 |
| --- | --- |
| `spec/`・`plan/` の `test1`〜`test5` | セットアップ・構成の変更、マスタ・トランザクションの画面の実装（仕様は [NorthwindDbSampleSpec](https://github.com/OpenTouryoProject/NorthwindDbSampleSpec)） |
| `spec/test6-testfirst*.md`・`plan/test6-testfirst*.md` | **テスト先行**：共通の決まりと対象（受注一覧 OrdTf）、**司令役の手順**（実装役・レビュー役をサブ エージェントで回す。人には仕様の決定だけを選択肢で聞き、決定記録の案も書く）、レビュー役の観点 |
| `prompt/検証プロンプト.md` | 上の見本を回すための短い指示（例：司令役への 1 文） |

- 見本の仕様（NorthwindDbSampleSpec）の本文は**意図的に不完全**にしてあり、テストを起こすエージェントが仕様の漏れを見つけられるかを試す教材になる。
  決まったことは本文ではなく `LLD/Decisions` に記録する。
- 見本を回す検証用リポジトリは、テンプレート [VerifyCodingAgentSkillsForOtTemplate](https://github.com/NetDevInfraWGinOSSConsortium/VerifyCodingAgentSkillsForOtTemplate) から作れる。

## ライセンス

[MIT](LICENSE)
