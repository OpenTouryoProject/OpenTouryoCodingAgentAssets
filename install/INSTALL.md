# 導入する（コマンドと、エージェンティック・インストール）

導入のしかたは 2 つ。**上書きだけで済むものはコマンドで入れる。上書きだけで済まないもの（導入先ごとの判断・導入先の手入れとの取り込みが要るもの）は、
エージェントに頼む（エージェンティック・インストール）。**

| 何を | 方式 | 手順 |
| --- | --- | --- |
| 1. 書き方（インストラクション・スキル・役の定義）の初回の導入、手を入れていない導入先の入れ直し | コマンド | [コマンドで入れる](#コマンドで入れる人が実行する) |
| 3. 進め方（見本・プロンプト。`-IncludeTutorial`） | コマンド | 同上（既存のファイルは上書きしない） |
| 入れ直しで飛ばされたファイル（導入先で手を入れた・記録が無い）への、原本の変更の取り込み | エージェンティック | [入れ直しの取り込み](#入れ直しの取り込みai-が読む手順)（このファイルの後半） |
| 2. 確かめ方・残し方（検出器と品質の羅針盤。`-IncludeQualityGuard`） | エージェンティック | [`src/quality/ExpectationGuard/INSTALL.md`](../src/quality/ExpectationGuard/INSTALL.md)（羅針盤の埋め方・既存の `QUALITY.md` の分け方は [`src/compass/INSTALL.md`](../src/compass/INSTALL.md)） |

エージェンティック・インストールでは、エージェントが導入先を調べ、判断を人に聞き、`install.ps1` を中で動かす。導入先の変更はワーキング ツリーまでで、コミットは人が行う。

## コマンドで入れる（人が実行する）

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

### 配置先

| プロダクト | インストラクション | スキル | 役の定義 |
| --- | --- | --- | --- |
| `claude` | `CLAUDE.md`（`AGENTS.md` を `@` import） | `.claude/skills/` | `.claude/agents/` |
| `copilot` | `.github/copilot-instructions.md`（複製） | `.github/skills/` | `.github/agents/*.agent.md`（原本から変換。`model` は書かない） |
| `agents` | `AGENTS.md` | `.agents/skills/` | （未対応） |

`AGENTS.md`・`TESTING.md`・`AGENT-DASHBOARD.sample.md` はどのプロダクトでも対象リポジトリのルートへ配置される（`AGENTS.md` が原本）。
Claude Code は `AGENTS.md` を読まないため、それを `@` import する `CLAUDE.md` を別途生成する。

### 入れ直し

**入れ直しで、導入先で手を入れたファイルは上書きされない**（#20）。インストーラは書いたファイルを、導入先のルートの目録 `.opentouryo-agent-assets.json`
（ファイルごとの原本の版・原本のパス・中身の sha256。コミットして残す）に記録し、入れ直しでは次のどれかにする。

| 導入先のファイル | 動き |
| --- | --- |
| 今回の中身と同じ | 書かない（改行と BOM の違いは同じとみなす） |
| 目録の中身と同じ（手を入れていない） | 上書きする |
| それ以外（手を入れた・記録が無い） | **飛ばして警告する**（`-Force` のときだけ上書き） |

スキルも 1 ファイルずつ判定する（原本で消えたファイルは、手を入れていなければ消し、手を入れていれば残す。導入先で足したファイルには触れない）。
飛ばしたファイルに原本の変更を取り込むのは、エージェントに次の「入れ直しの取り込み」を頼む。

- 3. 進め方の見本：`docs/spec`・`docs/plan` は利用者の作業ディレクトリなので、**再実行しても既存ファイルは上書きしない**（`-Force` でのみ上書き）。
  見本のファイル名は 2026-11 に変えた（#15。例 `test6-testfirst.md` → `cmn-testfirst.md`）。前の版の名前のファイルは消さず、残っていればインストーラが警告する。
- 2. 検出器の写し・規則・CI の雛形・`QUALITY.md` の扱いは、[`src/quality/ExpectationGuard/INSTALL.md`](../src/quality/ExpectationGuard/INSTALL.md) と README の「2. 確かめ方・残し方」。

---

## 入れ直しの取り込み（AI が読む手順）

この手順は、**配布物（`AGENTS.md`・`TESTING.md`・スキル・役の定義など）の導入・入れ直しを頼まれたコーディング エージェント**が読む
（OpenTouryoCodingAgentAssets#20）。`install/install.ps1` は、導入先で手を入れたファイルを上書きせずに飛ばす。
飛ばしたファイルに原本の変更を取り込むのが、この手順の役目である。

- 人の頼み方の例：「OpenTouryoCodingAgentAssets の `install/INSTALL.md` に従って、`C:\git\MyApp` に配布物を入れ直して」
- このファイルは導入先に写さない
- **導入先の変更はワーキング ツリーまで。** `git add`・`commit`・`push`・`checkout` などの状態を変える操作は、人が行う
- 判断は人に聞く。**推奨を先頭に置き、候補は間引かない**（質問の道具が無ければ、番号付きの一覧で聞く）
- 一時のファイル・写しは、エージェントの一時フォルダ（scratchpad など）に置く。導入先・原本のフォルダには置かない
- 検出器（`-IncludeQualityGuard`）の導入・写し直しは、別の手順 `src/quality/ExpectationGuard/INSTALL.md`
- 品質の羅針盤（`QUALITY.common.md`・`QUALITY.md`。検出器と一緒に入る）の埋め方・既存の `QUALITY.md` の分け方は、別の手順 `src/compass/INSTALL.md`。
  `QUALITY.common.md` が飛ばされたときの取り込みは、この手順で行う（`QUALITY.md` は導入先が持つので、飛ばす・取り込むの対象ではない）

## 1. 調べる（読むだけ）

| 何を | どこで | 何に使うか |
| --- | --- | --- |
| 作業ツリーの状態 | 導入先の `git status` | **関係の無い未コミットの変更があれば、先に人に聞く**（コミットが混ざる） |
| 目録 | 導入先のルートの `.opentouryo-agent-assets.json` | ファイルごとの、書いたときの原本の版（`revision`）・原本のパス（`source`）・中身の sha256。無ければ、記録の無い導入先（初めての入れ直し） |
| 入れ方 | 目録のパス（`.claude/`・`.github/`・`.agents/`）、`CLAUDE.md`・`.github/copilot-instructions.md` の有無 | `-Product`（claude・copilot・agents）と `-Skill` を、前と同じにする。分からなければ人に聞く |
| 飛ばすファイル | `install.ps1 -TargetRoot <導入先> -Product <…> -WhatIf` の「スキップ」「残す」の行 | 2 以降で扱うファイルの一覧。無ければ 2・3 は要らない（4 だけ） |

## 2. 3 つの版を作る（一時の写しで）

飛ばすファイルごとに、次の 3 つを一時フォルダに作る。

1. **導入先の今**：導入先のファイルそのもの
2. **今回の版**：導入先の作業ツリーの写し（`.git` を除く）を一時フォルダに作って `git init` し、今の原本の `install.ps1 … -Force` をそこへ動かした結果
3. **前に配った版**：目録の、そのファイルの `revision` の原本で作ったもの。
   `git -C <原本> archive <revision> | tar -x -C <一時フォルダ>` で、その版の原本を取り出し、その中の `install/install.ps1 … -Force` を、2 と同じく導入先の写しへ動かした結果
   - `revision` に `+dirty` が付く・`unknown`・目録に記録が無いときは、作れない。**2 つの版（導入先の今・今回の版）で比べ、人に聞く**

## 3. 比べて、人に聞く

- 導入先で手を入れた箇所：「前に配った版」→「導入先の今」の差分
- 原本の変更：「前に配った版」→「今回の版」の差分
- 取り込んだ案：`git merge-file -p <導入先の今> <前に配った版> <今回の版>`（導入先の状態を変えない。衝突は `<<<<<<<` の印で出る）

**衝突が無く、取り込んだ案に導入先の手入れと原本の変更が両方残るファイルは、聞かずに 1 を選んでよい。**
そのときも、ファイルごとの 2 つの差分の要点を、5 の報告（PR を出すなら、その説明）に必ず書く。人はそこで確かめる。

**衝突があるファイル**は、ファイルごとに、2 つの差分の要点と取り込んだ案を示し、次から聞く（推奨を先頭に）。

1. **原本の変更を取り込み、手を入れた箇所を残す**（取り込んだ案。衝突のそれぞれで、どちらを採るかも聞く）
2. 原本で上書きする（手を入れた箇所は消える）
3. そのままにする（原本の変更は入らない。次の入れ直しでも飛ばされる）

「原本で消えたが、導入先で手を入れた」ファイル（`-WhatIf` の「残す」）は、衝突が無くても、「消す」「残す」を聞く。

## 4. 取り込む

- 飛ばさないファイル（原本の変更をそのまま入れてよいもの）は、`install.ps1`（`-Force` なし）を導入先に動かして入れる
- 1 を選んだファイルは取り込んだ案、2 を選んだファイルは今回の版を、**導入先の改行（CRLF/LF）と BOM を保って**書く
- **目録を合わせる**：1・2 を選んだファイルは、目録のその行を、2 の一時の写しの目録の同じ行（今回の版の `revision`・`sha256`）に置き換える。
  1 のファイルは中身が今回の版と違うので、次の入れ直しでも飛ばされ、そのときもこの手順で取り込む（手を入れた箇所は消えない）。
  3 を選んだファイルは、目録を変えない
- 目録は、`install.ps1` とこの手順のほかでは直さない

## 5. 確かめて、人に渡す

- もう一度 `install.ps1 … -WhatIf` を動かし、飛ばすのが 3 を選んだファイル（と 1 のファイル）だけになっていることを確かめる
- 変えたファイルの一覧、ファイルごとの選んだ答え（聞かずに 1 を選んだファイルは、そう書き、2 つの差分の要点を添える）、衝突をどう解いたか
- **コミット メッセージの案。** 検出器が入っていれば、`CheckExpectationChange.ps1 -Proposed -MessageFile <案>` で確かめてから出す（#18）
