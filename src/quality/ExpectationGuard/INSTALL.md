# 期待値の変更の検出器を導入する（AI が読む手順）

この手順は、**導入を頼まれたコーディング エージェント**が読む。導入先を調べ、判断を人に対話で聞き、
`install/install.ps1` を聞いた答えの引数で動かし、導入先の規則と文書を合わせる（OpenTouryoCodingAgentAssets#13）。

- 人の頼み方の例：「OpenTouryoCodingAgentAssets の `src/quality/ExpectationGuard/INSTALL.md` に従って、`C:\git\MyApp` に検出器を導入して」
- このファイルは導入先に写さない（`install.ps1` が写すのは、決まったファイルだけ）
- **導入先の変更はワーキング ツリーまで。** `git add`・`commit`・`push`・`checkout` などの状態を変える操作は、人が行う
- 判断は人に聞く。**推奨を先頭に置き、候補は間引かない**（質問の道具が無ければ、番号付きの一覧で聞く）

## 1. 調べる（読むだけ）

| 何を | どこで | 何に使うか |
| --- | --- | --- |
| 作業ツリーの状態・ブランチ | `git status`・`git branch --show-current` | **導入と関係の無い未コミットの変更があれば、先に人に聞く**（コミットが混ざる） |
| 既存の検出器と、写しの版 | 先頭付近の `expectation-guard-source:` の行（`CheckExpectationChange.ps1`・`rules.common.psd1`・`.githooks/commit-msg`） | 新規か・写し直しか・自前の検出器の置き換え（印の行が無い）か。写し直しなら、今の置き場所 |
| フックの有効化 | `git config core.hooksPath`・`.githooks/` | 段 2 が手元で効いているか |
| CI | `.github/workflows/`（`expectation-change.yml` の有無・ジョブ名） | 雛形を置くか、既存の workflow との差を手で合わせるか |
| 段 1 の登録 | `.claude/settings.json` の `hooks.PreToolUse` | あれば `install.ps1` は書き換えない。足す内容を人に示す |
| テストの在りか | テストのプロジェクト（`*.Tests.csproj` など）・Golden | `rules.psd1` の `DiffScope` と各規則の `Paths` |
| 製品のコードの在りか | ソリューション・`*.csproj` の場所 | `rules.psd1` の `ReviewScope`（要確認の範囲） |
| 役の定義 | `.claude/agents/*.md` | `Reviewed-with:` の語彙になる。突き合わせ役（`opentouryo-expectation-reviewer.md`）は検出器と一緒に写る（同じ名前の自前の定義があれば、聞く） |
| 文書のトレーラー・検出器の節 | 導入先の `AGENTS.md`・`QUALITY.md`（`Expectation-Change`・`Found-By`・「トレーラー」で探す） | 規則と食い違う記述（例：「付けるトレーラーは … だけ」） |

## 2. 聞く

1. **導入の形**：新規／写し直し（版を上げる）／自前の検出器の置き換え（`-Force` が要る）
2. **配布物の範囲**：検出器だけ（`-Product` なし。`AGENTS.md`・スキルに触れない）か、スキルと併せる（`-Product`）か。
   **`-Product` と `-Force` を併せると、導入先の `AGENTS.md` なども上書きされる。** 導入先が自分で書いた `AGENTS.md` があれば、`-Product` なしを勧める
3. **本体の置き場所**（`-QualityGuardPath`。既定 `tools/ExpectationGuard`。写し直しなら今の場所）。
   判定の用例は `<置き場所>/ExpectationGuard.Tests/` に固定である（選べるようにするのは #13 の残り）
4. **テストの範囲**（`DiffScope`）：期待値の変更を読む範囲。テストのプロジェクト・Golden を含める
5. **要確認の範囲**（`ReviewScope`）：`[Obsolete]`・`#pragma warning disable` を探す範囲。**製品のコードを含める。** 省略するとリポジトリ全体。
   取り込んだ他者のコード（`vendor/` など）を外したいときに絞る
6. **CI**：雛形を置く（無いとき）／既存の workflow に手で合わせる（ジョブ名・スイッチ名の差を示して聞く）
7. **文書の反映**：どの節を、どう直すか（6 で案を示す）

## 3. 写す

1. まず `-WhatIf` で、写すもの・そのままのものを人に示す
2. 聞いた答えの引数で動かす（例：`./install/install.ps1 -TargetRoot C:\git\MyApp -IncludeQualityGuard -QualityGuardPath root/programs -Force`）
3. 表示の「そのまま（導入先が持つ）」・「警告」を読み、手で合わせるもの（CI の雛形の変更・`.claude/settings.json`）を拾う。
   CI の雛形の変更は `git diff <前の版> <今の版> -- src/quality/ExpectationGuard/expectation-change.yml`（このリポジトリで）で分かる

## 4. 規則（`rules.psd1`）を合わせる

`rules.psd1` は導入先が持つ（初回だけ見本から置かれ、以後は上書きされない）。書き方は `rules.sample.psd1`。

- `DiffScope`・`ReviewScope`（2 の答え）、各規則の `Paths`（テストのプロジェクト名）、`Guard`（導入先の比較のスクリプトなど）
- 写し直しでは、原本の `rules.sample.psd1` に新しいキーが増えていないかを見る（例：`ReviewScope`）。増えていれば、要るかを聞く

## 5. 確かめる

- 判定の用例：`<置き場所>/ExpectationGuard.Tests/Run-Tests.ps1` を **Windows PowerShell 5.1 と PowerShell 7** で。すべて期待どおりであること
- 写しの検査：`CheckExpectationChange.ps1 -VerifyCopy` で、違いが 0 件であること
- 導入先の実際のコミットで `-Commit <sha>`：
  - 期待値の変更（テストの削除など）を含むコミット → 検出し、トレーラーで承認済みと出る
  - `[Obsolete]`・`#pragma warning disable` を足したコミット（`git log -G` で探す）→ 要確認に出る。出なければ `ReviewScope` を見直す
  - `Found-By:` などのトレーラーのあるコミット → 止まらない
- 自前の検出器の置き換え・版を上げたときは、導入の後のコミット（直近の数十件）を前後の検出器で `-Commit <sha> -PassThru -Quiet` し、
  終了コード・`Findings`・`Errors` が同じことを確かめる（違えば理由を書く。`Review`・`Warnings` は足した規則の分だけ増えてよい）。
  **前の検出器は、`git show HEAD:<置き場所>/…` で、リポジトリの中の同じ置き場所（別の作業ツリーなど）に置いて動かす。**
  本体は自分の隣の規則のファイルを仕組みのファイルに加えるので、リポジトリの外に置くと、前の側だけそれを数えず、見かけの差が出る
- 突き合わせ役：理由のある実際のコミットで `-Commit <sha> -Json` が `Findings`・`Approved`・`DiffCommand` を返すこと

## 6. 導入先の文書を合わせる

- **上書きしない。** `AGENTS.md`・`QUALITY.md` のトレーラー・検出器の節だけを、共通の規則（`rules.common.psd1`）に合わせて直す
- 語彙と意味は写さず、規則のファイルを指す（写すと、規則を変えるたびにずれる。#5）
- 今のトレーラー：`Expectation-Change:`（承認）・`Found-By:`（バグの見つけ方）・`Tested-with:`・`Reviewed-with:`（確かめ方）。
  **最後の段落に、空行を挟まずに並べる**（git はそこしか読まない）
- `Expectation-Change:` の理由には、Issue 番号か仕様の節を書く（無ければ警告）。リポジトリ固有の書き方（テストの ID など）は `rules.psd1` の `ApprovalReasonPatterns` に足す
- 文面を提案したら、コミットの前に突き合わせ役（`opentouryo-expectation-reviewer`）を回す（#6）。結果は報告に、回したことは `Reviewed-with:` に
- 直した差分を人に示す

## 7. 人に渡す

- 変えたファイルの一覧と、確かめた結果（5 の数）
- 人が行うこと：`git config core.hooksPath .githooks`（人ごと）、`git add --chmod=+x .githooks/commit-msg`、
  `.claude/settings.json` への段 1 の登録（既存の設定があったとき）
- **コミット メッセージの案。** 写し直し・置き換えは仕組みの変更なので `Expectation-Change:` を付ける（印の行の版が変わるだけでも止まる）。
  理由には、版の変化（`<前の版> → <今の版>`）と、判定が変わったか（足した規則・変えた規則）を書く。
  回した判定の用例は `Tested-with:` に書く（例：`Tested-with: unit (Run-Tests.ps1 <件数> 件。5.1・7)`）
