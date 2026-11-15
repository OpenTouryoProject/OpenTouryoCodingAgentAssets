# 品質の羅針盤を入れる（AI が読む手順）

この手順は、**品質の羅針盤（`QUALITY.common.md`・`QUALITY.md`）の導入・入れ直しを頼まれたコーディング エージェント**が読む
（OpenTouryoCodingAgentAssets#21）。

- 人の頼み方の例：「OpenTouryoCodingAgentAssets の `src/compass/INSTALL.md` に従って、`C:\git\MyApp` に品質の羅針盤を入れて」
- このファイルは導入先に写さない
- **導入先の変更はワーキング ツリーまで。** `git add`・`commit`・`push`・`checkout` などの状態を変える操作は、人が行う
- 判断は人に聞く。**推奨を先頭に置き、候補は間引かない**（質問の道具が無ければ、番号付きの一覧で聞く）。
  1 回に聞くのは 1 件ずつ（品質マップなら 1 行ずつ）。会話や作業のファイルを知らない人が読めるように、背景と、選んだときに何が変わるかを添える
- 一時のファイル・写しは、エージェントの一時フォルダ（scratchpad など）に置く。導入先・原本のフォルダには置かない

## 0. 2 つのファイル

| ファイル（導入先のルート） | 持ち主 | 中身 | 入れ直し |
| --- | --- | --- | --- |
| `QUALITY.common.md` | 配布物（原本 `src/compass/QUALITY.common.md`） | どのリポジトリでも同じ決まり（3 段・トレーラー・CI で止まったとき・レビューの回し方・フィードバックの輪・計測の方法） | `install.ps1` が目録（`.opentouryo-agent-assets.json`。#20）で、手を入れていなければ上書きする |
| `QUALITY.md` | 導入先 | このリポジトリの値・品質マップ・観点・根拠の書き方・計測の基準 | **上書きしない。** 無いときだけ見本（原本 `src/compass/QUALITY.sample.md`）を置く |

- **節の番号は 2 つで同じ**（1 品質マップ・2 正の定義・3 期待値の変更と承認・4 レビューの観点・5 フィードバックの輪・6 計測・7 根拠の書き方・8 チェックリスト）
- `install.ps1 -IncludeQualityGuard` で、検出器と一緒に入る（common の 3 節が検出器を説明するため）。`-Product claude` なら、生成する `CLAUDE.md` が 2 つを読み込む
- 原本の羅針盤（方針の経緯）は NetDevInfraWiki の [OTR_QualityCompass](https://github.com/NetDevInfraWGinOSSConsortium/NetDevInfraWiki/wiki/OTR_QualityCompass)

## 1. 調べる（読むだけ）

| 何を | どこで | 何に使うか |
| --- | --- | --- |
| 作業ツリーの状態 | 導入先の `git status` | **関係の無い未コミットの変更があれば、先に人に聞く**（コミットが混ざる） |
| どの場合か | 導入先の `QUALITY.md`・`QUALITY.common.md`・目録の有無 | `QUALITY.md` が無い → 2。あって `QUALITY.common.md` が無い → 3（最初の 1 回）。両方ある → 4 |
| 検出器 | `git ls-files '*CheckExpectationChange.ps1'`、`expectation-change.yml` の `branches` | 「このリポジトリの値」の検出器の置き場所・宛先のブランチ。検出器が無ければ、先に `src/quality/ExpectationGuard/INSTALL.md` で入れる |
| 入れ方 | 目録のパス、`CLAUDE.md`・`.github/copilot-instructions.md` の有無と、生成の印（`opentouryo-agent-assets:generated`） | `-Product` を前と同じにする。導入先が自分で持つ `AGENTS.md`・`CLAUDE.md`（印が無い）には、`install.ps1` は触れない |

## 2. 新しく入れる（`QUALITY.md` が無い）

1. `install.ps1 -TargetRoot <導入先> -Product <…> -IncludeQualityGuard [-QualityGuardPath …]` を動かす。`QUALITY.common.md` と、見本の `QUALITY.md` が入る
2. **見本の「TODO」と「見本の行」を、導入先を調べて埋める。** 推測で埋めない。調べて分かったことは出典（ファイルとその箇所）を添えて案にし、決めることは人に聞く

   | 節 | 調べる所 | 人に聞くこと |
   | --- | --- | --- |
   | このリポジトリの値 | 検出器の置き場所・`expectation-change.yml`・`.claude/agents/` | 必須のチェックにしたか、共有の作業ブランチ |
   | 一次情報 | `README.md`・`TESTING.md`・`docs/spec/`・ビルドとテストの回し方の文書 | 仕様の文書の場所と版（リポジトリの外にあるとき） |
   | 1 品質マップ | プロジェクト（`.csproj`）・層・画面・業務・認証の有無・DB | **1 行ずつ**：単位の切り方、リスク、人が必ず見る箇所（推奨と、その理由を添える） |
   | 2 正の定義 | テスト仕様（`docs/spec/*-tests.md`）の根拠、静的解析の有無 | 観測を残すか、外部の基準 |
   | 4 レビューの観点 | 1 節の「高」「中〜高」の単位 | 見本の観点を残すか、単位ごとに足すか |
   | 6・7・8 | テストの属性（`[Basis]` など）、`rules.psd1` | 計測の基準を今取るか |

3. 採らなかった「見本の行」を消し、`TODO` が残っていないことを確かめる（`Select-String -Path QUALITY.md -Pattern 'TODO|見本の行'`）
4. **読み込み**：`-Product claude` で入れたなら、`CLAUDE.md` に `@QUALITY.common.md`・`@QUALITY.md` があることを確かめる。
   導入先が自分で持つ `AGENTS.md`・`CLAUDE.md` なら、「変更の前に `QUALITY.md`・`QUALITY.common.md` を読む」の 1 行と、`CLAUDE.md` の `@QUALITY.common.md`・`@QUALITY.md` を足すかを人に聞く
5. 検出器の `src/quality/ExpectationGuard/INSTALL.md` 2-5（書き忘れの組）は、品質マップの「高」の単位を使う。検出器を同時に入れるなら、この後に行う

## 3. 既存の `QUALITY.md` を、共通と固有に分ける（最初の 1 回）

`QUALITY.md` を前から手で持っている導入先（OpenTouryo・MultiPurposeAuthSite など）で、1 回だけ行う。以後は 4 の入れ直しになる。

1. `install.ps1` を動かす。`QUALITY.common.md` が入り、既存の `QUALITY.md` には触れない
2. **対応表を作る**：既存の `QUALITY.md` の段落・箇条・表の行を 1 つずつ、`QUALITY.common.md` と比べて、次に分ける

   | 分け方 | 扱い |
   | --- | --- |
   | (a) common が同じ意味で持つ | `QUALITY.md` から消す |
   | (b) このリポジトリ固有（品質マップ・観点・根拠の書き方・計測の値・パス・Issue の経緯） | `QUALITY.md` に残す。パス・ブランチ・チェックの名前・役の名前は「このリポジトリの値」の表に移す |
   | (c) common と意味が違う（例：観測を落とすか、レビュー役の名前） | 人に聞く：このリポジトリの決まりとして `QUALITY.md` に残す（推奨。common の「リポジトリで決める」に当たるもの）／原本を直す提案にする（別の Issue）／common に合わせて消す |
   | (d) common に無いが、どのリポジトリにも当てはまる | `QUALITY.md` に残し、原本に足す提案を報告に書く |

3. 節の番号を保ったまま、`QUALITY.md` を書き直す（見本 `src/compass/QUALITY.sample.md` の形。冒頭に common への参照と「このリポジトリの値」）
4. **内容が落ちていないことを確かめる**：
   - 対応表の (a) のすべての行に、common の節（とその文）を付ける。付けられない行は (a) ではない
   - 書き直す前の `QUALITY.md` の太字の文と、表の行の数を、書き直した後の 2 つのファイルで数え、差を対応表で説明する
5. **参照を直す**：導入先で `QUALITY.md` の節を指す箇所（`git grep -n 'QUALITY.md'`。`AGENTS.md`・役の定義・`rules.psd1` の `Reference` など）が、
   消した内容を指していれば `QUALITY.common.md` に向ける。節の番号は同じなので、番号だけの参照はそのままでよい
6. **読み込み**：2 の 4 と同じ
7. 人に渡すものに、対応表（特に (c)・(d)）を付ける

## 4. 入れ直す（両方ある）

1. `install.ps1` を、前と同じ指定で動かす（`install/INSTALL.md` 1）
   - `QUALITY.common.md` は、手を入れていなければ上書きされる。飛ばされたら、`install/INSTALL.md` の手順（3 つの版）で取り込む。
     **手を入れた箇所は、本来 `QUALITY.md` に書くもの**なので、取り込むときに `QUALITY.md` へ移すかを人に聞く
2. **見本の変更を `QUALITY.md` に取り込むかを聞く**（`QUALITY.md` は上書きされないため）：
   目録の `QUALITY.common.md` の `revision`（入れ直す前の値）から今までの、見本の差分を見る
   （`git -C <原本> diff <revision>..HEAD -- src/compass/QUALITY.sample.md src/compass/QUALITY.common.md`）。
   「このリポジトリの値」の項目が増えた・common が `QUALITY.md` に新しい欄を求めるようになったなら、その欄の案を作って人に聞く

## 5. 確かめて、人に渡す

- 変えたファイルの一覧、聞いたことと答え、3 なら対応表
- **コミット メッセージの案。** `CheckExpectationChange.ps1 -Proposed -MessageFile <案>` で確かめてから出す。
  `QUALITY.common.md`・`QUALITY.md` は仕組みのファイルではないが、同じコミットで検出器の写しも変わるなら `Expectation-Change:` が要る
