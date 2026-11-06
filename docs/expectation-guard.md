# 期待値の変更の検出器：共通の本体と規則の切り分け（Issue #3）

このリポジトリ用の記録（導入先へは配らない）。
OpenTouryo（OpenTouryo#640）と MultiPurposeAuthSite（MultiPurposeAuthSite#315）に別々の実装で入っていた検出器を読み比べ、
**共通の本体**（`src/quality/ExpectationGuard/`。原本はこのリポジトリ）と、**リポジトリごとの規則**（導入先の `rules.psd1`）に分けた。

- 比べた版：OpenTouryo `origin/5th_agent` = `303611d5`、MultiPurposeAuthSite `origin/5th_agent` = `fed34aa8`（どちらも 2026-11-06）
- 段階 1〜3（切り分け・本体・`install.ps1 -IncludeQualityGuard`）はこのリポジトリで行った。
  段階 4（各リポジトリでの置き換え）は OpenTouryo#657・MultiPurposeAuthSite#335、段階 5（「要確認」）はその後。

## 1. 構成

```
src/quality/ExpectationGuard/          原本（install.ps1 -IncludeQualityGuard が写す）
  CheckExpectationChange.ps1           本体（段 1〜3 の判定。規則は持たない）
  rules.common.psd1                    共通の規則（写し。仕組みのファイル・コメントの行・承認のトレーラー・段 1 の書き込みの判定）
  rules.sample.psd1                    リポジトリごとの規則の見本（導入先に rules.psd1 が無いときだけ置く）
  ExpectationGuard.ps1                 段 1：PreToolUse フック（本体の -PreToolUse を呼ぶだけ）
  commit-msg                           段 2：Git フック
  expectation-change.yml               段 3：CI の雛形（無いときだけ置く。以後は導入先が持つ）
  tests/                               判定の用例（cases.psd1 ＋ Run-Tests.ps1。導入先では ExpectationGuard.Tests/）
docs/expectation-guard/                段階 4 の下書き（このリポジトリ用）
  rules.OpenTouryo.psd1                OpenTouryo の rules.psd1
  CompareGolden.OpenTouryo.ps1         OpenTouryo の Golden の比較（Comparer）
  rules.MultiPurposeAuthSite.psd1      MultiPurposeAuthSite の rules.psd1
  Compare-Detectors.ps1                置き換えの前後で、コミットごとの判定を比べる
```

導入先での配置（`-QualityGuardPath` の既定は `tools/ExpectationGuard`）：

| 原本 | 導入先 | 上書き |
| --- | --- | --- |
| `CheckExpectationChange.ps1`・`rules.common.psd1` | `<QualityGuardPath>/` | 印の行があれば上書き（写しは直さない） |
| `rules.sample.psd1` | `<QualityGuardPath>/rules.psd1` | **しない**（導入先が持つ） |
| `tests/*` | `<QualityGuardPath>/ExpectationGuard.Tests/` | 印の行があれば上書き |
| `ExpectationGuard.ps1` | `.claude/hooks/ExpectationGuard.ps1` | 印の行があれば上書き |
| `commit-msg` | `.githooks/commit-msg`（BOM 無し・LF） | 印の行があれば上書き |
| `expectation-change.yml` | `.github/workflows/expectation-change.yml` | **しない**（雛形。`-Force` のときだけ） |
| （本体が生成） | `.claude/settings.json` | **無いときだけ置く**。あれば登録の例を表示する |

## 2. 共通の処理（本体へ移したもの）

両方にあった処理。**中身は同じか、片方が他方の上位互換**だったので、本体に 1 つだけ持つ。

| 処理 | OpenTouryo | MultiPurposeAuthSite | 本体 |
| --- | --- | --- | --- |
| git の呼び出し（UTF-8 で受け取る・カレントを変えない・標準エラーを別に読む） | `Invoke-Git`（`OutFile` で blob をバイトのまま） | `Invoke-Git`（`Text` も返す） | 両方を持つ |
| 表示（パイプなら UTF-8 のバイトを直接書く。5.1 の化け対策） | `Write-Msg` | 同じ | 同じ ＋ `-Quiet` |
| `-Staged` / `-Commit` / `-Range`、MERGE_HEAD・マージ コミットの除外、空の木 | ○ | ○（同じ） | 同じ |
| 導入より前のコミットの除外（`-Range`） | 本体のパスが木にあるか | 同じ | 規則の `IntroducedBy`（省略時は本体の場所） |
| トレーラーの読み取り（`#` の行・`git commit -v` の切り取り線から後は見ない） | `Get-ExpectationTrailer` | `Get-Trailer`（名前を引数） | `Get-Trailer` |
| 仕組みのファイルの保護（変更・削除・名前の変更。追加は数えない） | ○ | ○ | 同じ。**本体と規則のファイル自身は自動で加える** |
| ファイルごとの差し引き（`diff -U0` を `diff --git` で分ける・`+++`/`---` を除く・`//` の行を数えない） | ○（NUnit） | ○（テスト） | 規則の `LineRules` |
| 呼び出しの引数の読み取り（文字列・文字リテラル・コメント・括弧の深さ） | — | `Get-CallArguments` | そのまま |
| 終了コード 0 / 1 / 2 | ○ | ○ | 同じ |

## 3. リポジトリごとの規則（`rules.psd1` へ移したもの）

| 規則のキー | OpenTouryo | MultiPurposeAuthSite |
| --- | --- | --- |
| `IntroducedBy` | `root/programs/CheckExpectationChange.ps1` | `root/CheckExpectationChange.ps1` |
| `DiffScope` | `root/programs/` | `root/programs/Tests/` |
| `Guard`（共通に足すもの） | `CheckExpectationChange.ps1`・`CompareResult.ps1`（・`CompareGolden.ps1`） | `CheckExpectationChange.ps1`・`TestReport.cs` |
| `FileRules` | Golden：`root/programs/*/Frameworks/Tests/Golden/**/Result*.txt`、`Comparer` で正規化して比べる | — |
| `LineRules` テストの削除 | `Test`・`TestCase`・`TestCaseSource` | ＋ `Fact`・`Theory`・`SkippableFact`・`SkippableTheory`・`InlineData`・`MemberData`・`ClassData` |
| `LineRules` 無効化の追加 | `Ignore`・`Explicit`・`Assert.Ignore(`（名前「Ignore の追加」） | `Skip.If(`・`Skip.IfNot(`・`Skip =`・`SkipException(`・`Ignore`・`Explicit`（名前「Skip の追加」） |
| `LineRules` 根拠・検証の削除 | `[Basis(` | `.Verify(`・`.VerifyEqual(`、`Tests/UnitTests/` の下だけ `Assert.`・`[Basis(`（**1 つの規則**。`Match` の要素に `Paths`） |
| `KeyedArgumentRules` | — | `Report(id, title, viewpoint, basis)` の basis を id ごとに |
| `GeneratedRules` | — | `TESTCASES.md`（`Report`・`Step`・`Note`・`Target`・`Verify`・`VerifyEqual`・`Observe`・メソッド名。`TestCases-Unchanged:`） |
| `Reference` | `QUALITY.md 3 節` | `QUALITY.md 3 節` |

- **MultiPurposeAuthSite に固有だった 2 つ（basis の比較・`TESTCASES.md` の確認）は、汎用の規則の種類として本体に入れた**（作者判断・2026-11-06）。
  アプリ開発（#4）でも、根拠の ID・テスト仕様の生成物に使い回せる。
- psd1 にはスクリプトを書けないので、**固有の比べ方は `Comparer`（スクリプトのパス）で差し込む**。
  約束：`& <Comparer> -Pairs <Path・Expected・Actual の並び>` → 対ごとに `Path`・`Changed`・`Detail`。
  コミットごとに 1 回だけ呼ぶ（OpenTouryo の `2_RunAllTests.ps1 -List` を毎ファイル呼ばないため）。
- `TrailerRules`（#5 の `Found-By:`）：語彙に無い値は止め（1）、`RequiredWhen` に当たるのに無ければ警告（0）。
  **語彙は承認前なので、見本ではコメントにしてある。**

## 4. 分かれていた点と、本体での扱い

| 点 | OpenTouryo | MultiPurposeAuthSite | 本体 |
| --- | --- | --- | --- |
| 仕組みのファイルを、ほかの規則でも見るか | 見ない（`continue`） | basis は見る | ファイル単位（`FileRules`）は見ない、キーごとの引数は見る（両方の今の判定どおり） |
| 検出の表示の桁 | 「テストの削除      :」（半角の空白） | 「テストの削除   :」 | 種類の最長に全角の空白でそろえる（`-PassThru` のオブジェクトが正） |
| 生成物の確認のスイッチ | — | `-CheckTestCases` | `-CheckGenerated`（**段階 4 で CI の呼び出しを変える**） |
| CI のジョブ名 | `expectation-change` | ＋ `testcases-regenerated` | 雛形は `expectation-change`・`generated-regenerated`・`expectation-guard-tests`。雛形は導入先が持つので、必須のチェックの名前は合わせてよい |
| 段 1：コマンドの書き込みの判定 | `git checkout`・`restore`・`reset` なども含む | 含まない | 共通の規則で **OpenTouryo の版（広い方）** |
| 段 1：単体テストの `Assert.`・`[Basis(` | — | 数えない（段 2・段 3 だけ） | 規則どおり数える（段 1 は止めないので、広くしても害は確認が増えるだけ） |
| 段 1：パスの当て方 | `/root/...` をどこでも | 同じ | `CLAUDE_PROJECT_DIR` からの相対パスに `^` で当てる |
| 文書の参照（「QUALITY.md 3 節」） | 固定 | 固定 | 規則の `Reference`（任意） |

## 5. 判定の用例（`tests/cases.psd1`）

一時のリポジトリで、`rules.test.psd1`（すべての種類を 1 つずつ持つ規則）を使って本体を動かす。
**本体の判定を固定するもので、導入先の規則を確かめるものではない。** 40 件（2026-11-06、Windows PowerShell 5.1・PowerShell 7.6 とも全件期待どおり）。

| 区分 | 用例 |
| --- | --- |
| 検出する | テストの削除、Ignore（属性の並び）・Skip（xUnit）の追加、根拠（`[Basis]`）の削除、検証の削除（単体の Assert・E2E の Verify）、根拠（Report）の変更（複数行）、仕組みのファイルの変更（`.githooks`・規則のファイル自身・共通の規則の削除）、Golden の変更・追加・削除、コメント アウト、`-Staged`、語彙に無い `Found-By:`、生成物の作り直しの漏れ、`-Range`、段 1（属性が減る Edit・Golden への Write・Golden を書き換えるコマンド・生成物の手での編集） |
| 検出しない（正しく） | 属性の引数の書き直し、テストの追加、仕組みのファイルの追加、正規化で消える Golden の差分、Report をファイルをまたいで移す、トレーラーでの承認、E2E の Assert の削除、`//` の行、語彙にある `Found-By:`、生成物の作り直し・免除のトレーラー・条件式だけの変更、導入より前のコミット、段 1（テストの追加・規則の外のファイル） |
| 警告 | `fixed #NNN` に `Found-By:` が無い |
| 既知の取りこぼし | アサーションの値の反転、同じファイルの中での入れ替え |
| 過検出（既知） | テストを別のファイルへ移す |

既知の取りこぼし・過検出は、**今の判定を固定する**用例である。直したら用例も直す（直ったことが分かる）。

## 6. 置き換えの前後の比較（段階 4 の予行）

`docs/expectation-guard/Compare-Detectors.ps1` で、導入の後の全コミットを旧（各リポジトリの検出器）と新（本体＋下書きの規則）の `-Commit` にかけ、
終了コードと検出の一覧（承認済みのコミットは、旧が一覧を出さないので件数）を比べた。**読むだけで、両リポジトリは変えていない。**

| リポジトリ | 範囲 | 結果 |
| --- | --- | --- |
| MultiPurposeAuthSite | `a9b9ec13`（導入）〜 `fed34aa8` | 47 件すべて同じ（検出のあった 7 件はいずれも承認済みで、件数も同じ）。生成物の確認も、範囲全体・コミットごと（46 件。作り直しの漏れが出る `8c2c2fa0` を含む）とも同じ |
| OpenTouryo | `0aa3fbd6`（導入）〜 `6a0a419d` | 64 件すべて同じ（Golden を変えた 4 件は `CompareGolden.OpenTouryo.ps1` を通した） |

段階 4 では、写した本体と `rules.psd1` で同じ比較をやり直す（`-New` に写した本体、`-Rules` に導入先の `rules.psd1`）。

### 6.1 段 3（GitHub Actions）の実地の試験（SANDBOX・2026-11-06）

SANDBOX（NetDevInfraWGinOSSConsortium/Sandbox）に `install.ps1 -TargetRoot . -IncludeQualityGuard`（原本 `e1f2257`）で写し、PR で確かめた。

| PR | シナリオ | 結果 |
| --- | --- | --- |
| #1 | 導入の PR（ベースに検出器が無い） | PR 側の版を使い `::warning::` が出る。3 ジョブとも成功。判定の用例 40 件が `windows-latest` の 5.1 で全件期待どおり |
| #2 | トレーラーの無いテストの削除（`--no-verify` で段 2 を迂回） | `expectation-change` が失敗（「テストの削除」）。メッセージを書き直して force push すると成功（承認済み） |
| #3 | PR の中で `rules.psd1` を緩め、テストを消す | **ベース側の版（とベースの規則）で見るので失敗**（「仕組みの変更」「テストの削除」） |
| #4 | 写し（`rules.common.psd1`）を手で直す（トレーラー付き） | `expectation-change` は成功、`Verify copies` が PR に警告の注釈を出す。続けてトレーラーの無いコミットを足すと、検査は失敗し、**写しの検査も回る** |

- **雛形を直した：** 検査のステップが落ちると、後ろの `Verify copies` が飛ばされていた（#3 で判明）→ `if: always()` を足した。#4 で確かめた。
- 段 2（commit-msg）も SANDBOX の手元で動いた（トレーラー付きのコミットを承認済みとして通した）。
- 未確認：Linux・macOS の clone での commit-msg の実行属性（`100755` で入っていることは確かめた）。

## 7. 実測した落とし穴

- **`Import-PowerShellDataFile` を使わない。** PowerShell 7 から起動した git の sh で commit-msg フックが `powershell.exe`（5.1）を動かすと、
  `PSModulePath` が 7 のモジュールを先に指し、5.1 からこのコマンドレットが見えなくなる（「not recognized」で終了コード 2 → コミットが止まる）。
  本体は psd1 をデータだけの言語（`CheckRestrictedLanguage`）として読み、commit-msg は `env -u PSModulePath` で起動する（2026-11-06 に実測）。
- Windows PowerShell 5.1 の `ConvertTo-Json` は `<` `>` を `<` `>` にする。用例の置き換えの印は `@ROOT@` にした。
- `.ps1`・`.psd1` は BOM 付き UTF-8 で置く（5.1 は BOM 無しを ANSI として読む）。commit-msg は BOM 無し・LF（`install.ps1` が改行を LF にそろえて書く。導入先で CRLF にされないよう、導入先の `.gitattributes` で `eol=lf` にしておく）。

## 8. 検討事項の決定（2026-11-06・作者）

- このリポジトリの範囲を広げ、原本をここに置く（アプリ開発にも配れる形にする。#4）。
- 写しと原本の一致は、**印の行の SHA-256 と、写しの中身を比べて警告**に留める（`-VerifyCopy`。ネットワークを使わない）。
  ハッシュは写したときの中身（パスの埋め込みの後）に対するもので、「写した後に手で直していない」ことを確かめる。
- `.claude/settings.json` は無いときだけ置く（利用者の他の設定を壊さない）。
- PowerShell 5.1 で動くこと（両リポジトリの前提）を保つ。用例は 5.1・7 の両方で回した。

## 9. 段階 4 で各リポジトリが行うこと（メモ）

- `install.ps1 -Product claude -TargetRoot <repo> -IncludeQualityGuard -QualityGuardPath <root/programs | root>`
  （本体が今の検出器と同じパスに来るので、`IntroducedBy` と手元のフックの設定は変わらない）。
- `docs/expectation-guard/` の下書きを `rules.psd1`（OpenTouryo は ＋ `CompareGolden.ps1`）として置く。
- 既存の `.github/workflows/expectation-change.yml` は雛形で上書きされないので、手で合わせる
  （MultiPurposeAuthSite は `-CheckTestCases` → `-CheckGenerated`、判定の用例のジョブを足す、`-VerifyCopy` の手順を足す）。
- 置き換えのコミット自体が「仕組みの変更」になる。トレーラーを付ける。
