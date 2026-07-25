# チュートリアル1：spec → plan → 実装 を試す（Shippers 管理画面）

このチュートリアルは、**このスキル群を通しで動かして評価する**ためのものです。
同時に、`docs/spec` / `docs/plan` を使った**進め方の実例**にもなっています。

- サンプル仕様：`docs/spec/tutorial1.md`
- サンプル計画：`docs/plan/tutorial1.md`

## これで確認できること

- 作業に応じて**正しいスキルが自動でロードされるか**（`description` の効き具合）。
- エージェントが**層の責務・例外規約・トランザクション境界**を守って実装できるか。
- spec → plan → 実装 の流れが、この 3 ファイルで自然に回るか。

## 前提

- `opentouryo-project-setup`（必要なら `-db` の Docker サンプル DB）で**構築済みのプロジェクト**があること。
- サンプル DB に **Shippers** テーブルがあること。
- P層は **Web Forms / net48** を想定（既存が MVC / net10.0 なら読み替える）。

## 進め方

### ステップ1：仕様を読む
エージェントに `docs/spec/tutorial1.md` を読ませ、**何を作るか**を把握させる。

### ステップ2：計画を確認（または生成）する
次のどちらかを選ぶ。

- **(A) 付属の計画を使う**：`docs/plan/tutorial1.md` をそのまま採用する。
- **(B) 計画を作らせて見本と比べる**（推奨）：`docs/spec/tutorial1.md` だけを渡し、
  「この仕様の実装計画を `docs/plan/` の書式で作って」と指示する。できた計画を `docs/plan/tutorial1.md`（見本）と**突き合わせる**。
  使うスキル・層の分け方・件数0チェックの扱いが見本と揃っていれば、スキルが効いている。

### ステップ3：実装する
計画に沿って実装させる。指示は「`docs/plan/tutorial1.md` に沿って実装して。着手前に該当スキルを読むこと」で十分。

## 評価チェックリスト（実装後に確認）

エージェントの成果物を、次の観点で採点する。**×が出たら、どのスキルの description / 本文を直すべきかの手がかりになる。**

### スキルのロード
- [ ] D層の作業で `opentouryo-dao-generated`（または `-layer-d`）が読まれた。
- [ ] B層の作業で `opentouryo-layer-b` と `opentouryo-exception` が読まれた。
- [ ] P層の作業で `opentouryo-layer-p-webforms-screen` / `-event` が読まれた。
- [ ] P層→B層で `opentouryo-p-call-business` が読まれた。

### 層分離
- [ ] 画面（P層）に SQL・業務判断が書かれていない。
- [ ] B層がトランザクション境界になっている（D層・P層で接続やコミットをしていない）。
- [ ] 層をまたぐ受け渡しが `BaseParameterValue` / `BaseReturnValue` の派生型になっている。
- [ ] P層 → B層をサービス論理名で呼んでいる（層を直接 `new` していない）。

### 例外・トランザクション
- [ ] 業務例外（`BusinessApplicationException`）を**呼び出し側で `catch` していない**（戻り値の `ErrorFlag` で判定）。
- [ ] B層で `try/catch` によるロールバックを書いていない（フレームワーク任せ）。
- [ ] 更新・削除で**更新件数 0 を検知**し、やり直し可能なエラーにしている。

### Dao
- [ ] `DaoShippers` を手修正していない（ツール生成のまま）。
- [ ] `S3_Update` の SET は `Set_列_forUPD`、WHERE は `PK_` を使い分けている。
- [ ] `ExecInsUpDel_NonQuery()` の戻り値（更新件数）を捨てていない。

### 成果
- [ ] `docs/spec/tutorial1.md` の受入条件をすべて満たす。
- [ ] ビルドが通る。

## うまくいかないとき

- 想定スキルが読まれない → そのスキルの `description` にユーザ語彙・クラス名・メソッド名が足りているか見直す（`docs/authoring.md`）。
- 層をまたいだ実装になる → `AGENTS.md` の「アーキテクチャ／層間の呼び出し規約」と該当スキルの整合を確認する。
- 「このプロジェクトではどうなっているか」で詰まる → `opentouryo-project-policy` に沿って、ソースを読むか纏め者に確認する。
