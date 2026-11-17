# OpenTouryoCodingAgentAssets

Assets used by coding agents utilizing OpenTouryo

[OpenTouryo](https://github.com/OpenTouryoProject/OpenTouryo) を利用した業務系アプリケーションの開発を、
コーディング エージェント（CA：Claude Code / GitHub Copilot / Codex など）に行わせるための **CA ワークベンチ**。

> **CA ワークベンチ**：CA が書くための道具（スキル）だけでなく、何をどれだけ確かめるかを人が決める基準（品質の羅針盤）、
> 確かめたことを残す記録（コミットのトレーラー）とその守り（検出器）、通しで回して試す題材（検証・入門プロンプト）までを揃えた作業台。
> 当初はスキル集として始め、テスト先行の検証を重ねるうちに、ここまで広がった。

ワークベンチは 3 つの部からなる。

| 部 | 何のためか | 中身（原本） | 導入 |
| --- | --- | --- | --- |
| [1. 書き方](#1-書き方--インストラクションスキル役の定義) | OpenTouryo でどう書くか | `src/instructions/`（`AGENTS.md`・`TESTING.md`）・`src/skills/`（46 本）・`src/agents/`（テスト先行の実装役・レビュー役、変更のレビュー役） | コマンド |
| [2. 確かめ方・残し方](#2-確かめ方残し方--品質の羅針盤とトレーラー) | どこを・何で・どれだけ確かめるかを人が決め、確かめたことをコミットに残し、集計して基準へ戻す | `src/compass/`（品質の羅針盤 `QUALITY.md`）・`src/quality/ExpectationGuard/`（トレーラーの検査・期待値の変更の検出器・突き合わせ役） | エージェンティック（opt-in） |
| [3. 進め方](#3-進め方--業務系アプリ開発の検証入門プロンプト) | 業務系アプリの開発を spec → テスト → plan → 実装で通しで回し、ワークベンチを検証し、学ぶ | `src/docs/`（spec・plan の見本、検証・入門プロンプト。テスト先行は司令役の手順） | コマンド（opt-in） |

3 つの部は、次のようにつながる。

```text
人      ：品質の羅針盤（QUALITY.md）で、どこを・何で・どれだけ確かめるかを決める            … 2
            ↓
司令役  ：spec → テスト → plan → 実装 を、スキルを使う実装役と、別モデルのレビュー役で回す     … 1・3
          （人に聞くのは仕様の決定だけ）
            ↓
コミット：確かめ方をトレーラーに残す（Tested-with・Reviewed-with・Found-By・Expectation-Change）  … 2
          └ 検出器が 3 段（エージェント・commit-msg・CI）で、記録の漏れとテストの弱めを塞ぐ
            ↓
計測    ：git log でトレーラーを集計し、回帰テスト・レビューの観点・品質マップへ戻す             … 2
          （フィードバックの輪 → 羅針盤を直す）
```

```
src/
  instructions/AGENTS.md        1. 概要・規約（常時コンテキストに載る / これが原本）
  instructions/TESTING.md       1. テスト先行の進め方と、承認の 2 段（AGENTS.md から参照。AGENTS.md と同じくルートへ）
  instructions/AGENT-DASHBOARD.sample.md  1. 作業の見える化のダッシュボードの見本（ルートへ。本体の AGENT-DASHBOARD.md は .gitignore に足す）
  skills/                       1. 全スキル（一覧は docs/skills.md）
  agents/                       1. 役の定義：テスト先行の実装役・レビュー役、変更のレビュー役（Claude Code は .claude/agents、Copilot は .github/agents へ変換）
  compass/                      2. 品質の羅針盤：共通の決まり QUALITY.common.md と、導入先が持つ QUALITY.md の見本（検出器と一緒にルートへ。INSTALL.md は写さない）
  quality/ExpectationGuard/     2. トレーラーの検査・期待値の変更の検出器・突き合わせ役の原本（導入先へ写す。INSTALL.md は導入する AI が読む手順で、写さない）
  docs/                         3. spec・plan の見本と、検証・入門プロンプト（導入先の docs/ へ）
install/
  install.ps1                   対象リポジトリへのインストーラ
  INSTALL.md                    導入の手順：コマンドと、エージェンティック・インストール（導入先へは写さない）
docs/
  skills.md                     スキル一覧（このリポジトリ用・導入先へは配らない）
  authoring.md                  アセット執筆ガイド（このリポジトリ用）
  expectation-guard.md          検出器の切り分け・設計・検証の記録（このリポジトリ用）
  expectation-guard/            検出器の比べ合わせのスクリプトと、OpenTouryo・MultiPurposeAuthSite の規則（このリポジトリ用）
```

## 導入

**上書きだけで済むものはコマンド（`install/install.ps1`）で入れ、上書きだけで済まないものはエージェントに頼む（エージェンティック・インストール）。**
手順は [install/INSTALL.md](install/INSTALL.md)。

| 何を | 方式 |
| --- | --- |
| 1. 書き方・3. 進め方（初回、手を入れていない導入先の入れ直し） | コマンド：`./install/install.ps1 -Product claude -TargetRoot C:\git\MyApp`（3. は `-IncludeTutorial`）。clone した場所から動かす |
| 入れ直しで飛ばされたファイル（導入先で手を入れた）への、原本の変更の取り込み | エージェンティック：「OpenTouryoCodingAgentAssets の `install/INSTALL.md` に従って、`C:\git\MyApp` に配布物を入れ直して」 |
| 2. 確かめ方・残し方（検出器と品質の羅針盤） | エージェンティック：「OpenTouryoCodingAgentAssets の `src/quality/ExpectationGuard/INSTALL.md` に従って、`C:\git\MyApp` に検出器を導入して」 |

---

## 1. 書き方 — インストラクション・スキル・役の定義

**インストラクション**（概要）と**スキル**（具体的なコードの書き方）に分かれている。
前者は常にコンテキストへ載り、後者はエージェントが必要と判断したときだけ読まれる。
使い分けの基準は [docs/authoring.md](docs/authoring.md) を参照。

- `AGENTS.md`：OpenTouryo を使うプロジェクトの概要・規約（層・例外・Git の扱い・コミット メッセージのトレーラーなど）。
- `TESTING.md`：テスト先行の進め方（テスト仕様 → Red → Green、根拠の ID、期待値の変更とトレーラー）と、**承認の 2 段**
  （テストの質は実装役と別のレビュー役が確かめ、人は**仕様の決定だけ**を GO/NOGO で判断する）。
- `AGENT-DASHBOARD.sample.md`：作業の見える化のダッシュボードの見本。サブ エージェントを呼ぶか人に依頼・判断を仰ぐ作業で、主のセッションが
  ルートの `AGENT-DASHBOARD.md`（git の管理外。インストーラが `.gitignore` に足す）に、処理状況・人への依頼・今の判断の材料を書き続ける。
  作業の途中で呼ぶことになったら、呼ぶ前に作る（#19）。
- 役の定義（`src/agents/`）：テスト先行の**実装役**（`opentouryo-test-implementer`）と**レビュー役**（`opentouryo-test-reviewer`。編集できず、テストを自分で実行する）と、
  **変更のレビュー役**（`opentouryo-change-reviewer`。テスト先行に限らない変更を、`fixed` のコミットの前に別モデルでレビューする。編集できず、ビルド・テストも流さない）。
  司令役（指示を受けたセッション）がサブ エージェントとして回す。Claude Code と GitHub Copilot 向け（Copilot はサブ エージェントを続けて呼べないので、手順に書き分けがある）。

### スキル

46 本を用途・利用者で 4 つに分けている。一覧と使いどころは **[docs/skills.md](docs/skills.md)**。
**エージェントは各スキルの `description` で自動的に選ぶ**ので、一覧は主に人が俯瞰するための索引。

| 分類 | 本数 | 主な利用者 |
| --- | --- | --- |
| ① 立ち上げ・構成 | 9 | 立ち上げ担当・纏め者（主に一度きり） |
| ② 各層のコード実装 | 24 | アプリ開発者（日常常用。テスト先行の B層・E2E のテストも含む） |
| ③ 制御・定義／横断機能 | 12 | 必要になったとき参照 |
| ④ レビュー・フェーズ | 1 | 実装・実行の後（ログの分析） |

スキルは [Agent Skills のオープン標準](https://agentskills.io/specification)（`SKILL.md`）に準拠している。
Claude Code / GitHub Copilot / Cursor / Codex CLI / Gemini CLI など、標準に対応した
30以上のツールが同一のスキルを読める。**1回書けば全プロダクトで使える。**
プロダクト差分はインストラクション側と役の定義にのみ存在し、インストーラが吸収する（配置先は [install/INSTALL.md](install/INSTALL.md#配置先)）。

---

## 2. 確かめ方・残し方 — 品質の羅針盤とトレーラー

人は個々の変更を細かく見るより、**羅針盤を決める役**を担う。エージェントは、作業が品質マップのどの単位に当たるかを羅針盤で引き、
その重みで確かめ、確かめたことをコミットのトレーラーに残す。トレーラーは Git だけで集計でき、見つかった問題は羅針盤へ戻す。

### 品質の羅針盤（`QUALITY.md`）

**どこを・何で・どれだけ確かめるか**を決める文書を、導入先のルートに置く（#21。方針は NetDevInfraWiki の [OTR_QualityCompass](https://github.com/NetDevInfraWGinOSSConsortium/NetDevInfraWiki/wiki/OTR_QualityCompass)）。

| ファイル | 持ち主 | 中身 |
| --- | --- | --- |
| `QUALITY.common.md` | 配布物（入れ直しで、手を入れていなければ上書き） | どのリポジトリでも同じ決まり（3 段・CI で止まったとき・トレーラー・レビューの回し方・フィードバックの輪・計測） |
| `QUALITY.md` | 導入先（無いときだけ見本を置く） | このリポジトリの値・品質マップ・レビューの観点・根拠の書き方・計測の基準 |

- 節は 2 つで同じ番号：1 品質マップ・2 正の定義・3 期待値の変更と、その承認・4 レビューの観点・5 フィードバックの輪・6 計測・7 期待値の根拠の書き方・8 エージェント向けチェックリスト
- `-Product claude` で生成する `CLAUDE.md` が両方を読み込む。テスト先行の司令役は、着手と終わりに羅針盤を引く（[3. 進め方](#3-進め方--業務系アプリ開発の検証入門プロンプト)）
- 見本の埋め方（エージェントが調べて人に聞く）と、前から持つ `QUALITY.md` を共通と固有に分ける手順は [src/compass/INSTALL.md](src/compass/INSTALL.md)

### トレーラー（確かめたことを、コミットに残す）

| トレーラー | 何を残すか | 何に使うか |
| --- | --- | --- |
| `Expectation-Change: <理由>` | 承認したテストの期待値を変えた理由 | 無ければ検出器がコミットを拒否する。突き合わせ役が理由と差分を突き合わせる |
| `Found-By: <手段>` | バグの修正（`fixed #NNN`）を、どこで・何で見つけたか | 計測：見つけた手段の内訳 |
| `Tested-with: <種類>` | そのコミットを、どの種類のテストで確かめたか | 計測：後でバグが見つかったコミットと突き合わせる |
| `Reviewed-with: <役>` | どのレビュー役（別モデル）で確かめたか | 同上。別モデルのレビューの効きを見る |

計測は Git だけでできる（`QUALITY.common.md` 6 節）。

```text
git log --format='%h %(trailers:key=Found-By,valueonly,separator=|)' <範囲>
git log --format='%h %(trailers:key=Tested-with,valueonly,separator=|) %(trailers:key=Reviewed-with,valueonly,separator=|)' <範囲>
```

### 検出器（記録の漏れとテストの弱めを塞ぐ）

**承認したテストの期待値を後から変える変更**（テストの削除・Skip / Ignore の追加・根拠の削除・検証の削除・Golden の変更・検出の仕組み自体の変更など）を検出し、
トレーラー `Expectation-Change:` を求める。**アサーションの緩和は見ない**（機械的に判定できない。レビューの観点で拾う）。

| 段 | 何をするか | 導入先のファイル |
| --- | --- | --- |
| 1 | エージェントがテストを弱める編集をしたら、人の確認付きにする（止めない） | `.claude/hooks/ExpectationGuard.ps1`（`.claude/settings.json` に登録） |
| 2 | トレーラーの無い期待値の変更のコミットを拒否する | `.githooks/commit-msg`（`git config core.hooksPath .githooks`） |
| 3 | PR で同じ検出をする（**ベース側の版の検出器で見る**＝PR の中で検出器を緩めても素通りしない） | `.github/workflows/expectation-change.yml`（雛形） |

あわせて、次も行う。

| 検査 | 扱い |
| --- | --- |
| トレーラー `Found-By:` | 語彙に無い値は拒否、無ければ警告。どちらのときも語彙と意味の一覧を出す（語彙は `rules.common.psd1`） |
| トレーラー `Tested-with:`・`Reviewed-with:` | 語彙に無い値は拒否（役の語彙は `.claude/agents/` の役の定義の名前と `human`）。書き忘れは警告：コード（`.cs`・`.vb`。コメント・空行だけの変更を除く）を変えたのに `Tested-with:` が無い（`none` で満たせる）、期待値の変更に突き合わせ役の `Reviewed-with:` が無い、リポジトリの規則で足した組（例：リスク「高」の場所の `fixed`） |
| トレーラーの書き方（git が読む形か：最後の段落に置く・半角の「:」・名前の綴り・値が空でない） | 拒否。**書いた行・直した行・直した最後の段落・コミットの直し方を出す**（人がそのまま写して直せる） |
| `Expectation-Change:` の理由と差分の突き合わせ | 理由に Issue 番号・仕様の節が無ければ警告。文面を提案したら、コミットの前に**突き合わせ役**（`opentouryo-expectation-reviewer`。別モデル。検出器と一緒に `.claude/agents` へ入る）が、検出した一覧（`-Json`）・差分・原典と、網羅・一致・根拠・方向・範囲外を突き合わせる（止めない） |
| **要確認**（`[Obsolete]` の追加、`#pragma warning disable CS0618`・`618` の追加） | **止めない・トレーラーを求めない**。一覧に出し、CI では足した行に注釈を付ける（互換のための判断をレビューの目に入れる）。範囲は導入先が選ぶ（`ReviewScope`。省略時はリポジトリ全体） |
| 仕組みのファイル（フック・CI・本体・規則・`.claude/agents/`） | 変更・削除は期待値の変更と同じ扱い（追加は数えない） |

### 写しと規則

- 何を期待値と呼ぶかは、導入先の `rules.psd1`（初回だけ見本から置く。以後は導入先が持つ）に書く。CI の雛形も、初回だけ置いて以後は導入先が持つ（`-Force` でも上書きしない）。
- 本体・共通の規則・フック・判定の用例は**写し**で、先頭付近に原本の版（`src/quality` に最後に触れたコミット）と SHA-256 の行が入る。
  **写しは直さず、原本を直して写し直す**（写し直しも仕組みの変更なので、トレーラーが要る）。導入先の CI は `-VerifyCopy` で写しのずれを警告する。
- 判定の用例（「この差分なら検出する／しない」）を本体と一緒に持ち、導入先の CI でも回す。
- OpenTouryo・MultiPurposeAuthSite も、この原本の写しと、共通と固有に分けた `QUALITY.md` を使っている。
- 詳細は [src/quality/ExpectationGuard/rules.sample.psd1](src/quality/ExpectationGuard/rules.sample.psd1) と [docs/expectation-guard.md](docs/expectation-guard.md)。

### 導入

導入先ごとに決めることが多い（本体の置き場所・テストの範囲・要確認の範囲・CI の差・`-Force` の要否・導入先の文書の直し）ので、
**エージェンティック・インストール**にしている。手順は [src/quality/ExpectationGuard/INSTALL.md](src/quality/ExpectationGuard/INSTALL.md)
（導入先を調べる → 判断を対話で聞く → `install.ps1 -IncludeQualityGuard` を中で動かす → `rules.psd1` と `AGENTS.md`・`QUALITY.md` を合わせる → 確かめて人に渡す）。

---

## 3. 進め方 — 業務系アプリ開発の検証・入門プロンプト

規模のある変更は **spec → テスト → plan → 実装** で進めるのを推奨する（仕様を `docs/spec/`、計画を `docs/plan/` に置いてから実装）。
`-IncludeTutorial` を付けると、この流れを業務系アプリの題材で通しで試す見本とプロンプト（`src/docs/` の全ファイル）を、相対パスを保ったまま導入先の `docs/` へ配置する。
ワークベンチ自体の検証（スキル・役・羅針盤・検出器が実地で効くか）にも、使い方を学ぶ教材にもなる。

| 見本 | 中身 |
| --- | --- |
| `plan/cmn-setup.md`・`cmn-transform.md`、`spec/cmn-framework.md` | セットアップ（起点サンプルごとのケース）・構成の変更（2層化・最小化・親クラス2 のカスタマイズ）、フレームワーク毎の共通仕様（規約） |
| `spec/`・`plan/` の `test1`・`test2` | 業務系の画面の実装：マスタ・テーブルのバッチ更新、トランザクション・テーブルのバッチ更新・条件検索一覧からの詳細・明細の追加（仕様は [NorthwindDbSampleSpec](https://github.com/OpenTouryoProject/NorthwindDbSampleSpec)） |
| `spec/cmn-testfirst.md`・`spec/test3-testfirst-*.md`、`plan/cmn-testfirst*.md`・`plan/test3-testfirst-*-review.md` | **テスト先行**：共通の決まりと対象（受注一覧 OrdTf）、**司令役の手順**（実装役・レビュー役をサブ エージェントで回す。人には仕様の決定だけを選択肢で聞き、決定記録の案も書く。着手と終わりに品質の羅針盤を引き、段 4 の後は B層のカバレッジで仕様と突き合わせる場所を探す）、レビュー役の観点 |
| `prompt/検証プロンプト.md` | 上の見本を回すための短い指示：セットアップ・変形のケース、マスタ・トランザクションの実装と変更のレビュー役、テスト先行（司令役への 1 文と、決定記録・仕様の更新の返し方） |
| `prompt/入門プロンプト.md` | 入門（チュートリアル）のプロンプト（準備中） |

- 題材の仕様（NorthwindDbSampleSpec）の本文は**意図的に不完全**にしてあり、テストを起こすエージェントが仕様の漏れを見つけられるかを試す教材になる。
  決まったことは本文ではなく `LLD/Decisions` に記録する。
- 見本を回す検証用リポジトリは、テンプレート [VerifyCodingAgentSkillsForOtTemplate](https://github.com/NetDevInfraWGinOSSConsortium/VerifyCodingAgentSkillsForOtTemplate) から作れる。
- 導入はコマンド（`-IncludeTutorial`）。`docs/spec`・`docs/plan` の既存ファイルは上書きしない（[install/INSTALL.md](install/INSTALL.md#入れ直し)）。

## ライセンス

[MIT](LICENSE)
