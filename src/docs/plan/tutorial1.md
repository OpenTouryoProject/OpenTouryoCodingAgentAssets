# 計画：Shippers 管理画面（チュートリアル1）

> `docs/spec/tutorial1.md` の仕様を実装するための計画の**見本**です。
> 「どう作るか」（使用スキル・作成/変更ファイル・手順）を書きます。着手前に、各手順で挙げたスキルを読みます。

## 方針

- **D層 → B層 → P層 の順（ボトムアップ）** で作る。各層の責務を越えない。
- CRUD は**自動生成 Dao（`DaoShippers`）**で実装する（Shippers はテーブル単位の CRUD で足りる）。
  検索は `CompanyName_Like` を使う。SQL は手書きしない（ツール生成物を使う）。
- 引数・戻り値は `BaseParameterValue` / `BaseReturnValue` の派生型で受け渡す。

## 使用スキル（着手前に読む）

| 手順 | スキル |
| --- | --- |
| D層（Dao・SQL 定義） | `opentouryo-layer-d` → `opentouryo-dao-generated`（＋必要なら `opentouryo-query-definition`） |
| B層（業務ロジック・トランザクション） | `opentouryo-layer-b`（＋例外は `opentouryo-exception`） |
| P層（画面・イベント） | `opentouryo-layer-p-webforms-screen` → `opentouryo-layer-p-webforms-event` |
| P層 → B層 の呼び出し | `opentouryo-p-call-business` |
| このプロジェクト固有の値が不明なとき | `opentouryo-project-policy` |

## 作成・変更するファイル（既存プロジェクトの配置に合わせる）

- `Dao/DaoShippers.cs` … **D層自動生成ツールで生成**（Shippers）。手書き・手修正しない。
- `Business/ShippersParameterValue.cs` / `ShippersReturnValue.cs` … 引数/戻り値クラス（`MethodName`・検索条件・明細を持つ）。
- `Business/LayerB_Shippers.cs` … B層 業務クラス（`MyFcBaseLogic` を継承。`UOC_` メソッドに Select/Insert/Update/Delete）。
- `Aspx/ShippersScreen.aspx` + `ShippersScreen.aspx.cs` … 画面（`MyBaseController` 継承）。一覧 `GridView`、入力 `TextBox`、
  操作は `btn` 接頭辞のボタン（自動結線）。
- サービス定義（論理名 → 実体）へ `LayerB_Shippers` を登録（既存の定義ファイルに追記）。

## 手順

1. **D層**：`DaoShippers` を生成する（`opentouryo-dao-generated`）。使うメソッド／プロパティ：
   - 一覧・検索 → `D2_Select(dt)`（`CompanyName_Like` に検索語を設定。空なら未設定＝全件）。
   - 追加 → `D1_Insert()`（`ShipperID` は自動採番なので設定しない。`CompanyName` / `Phone` を設定）。
   - 更新 → `S3_Update()`（`PK_ShipperID` で対象を指定、`Set_CompanyName_forUPD` / `Set_Phone_forUPD` に新値）。
   - 削除 → `S4_Delete()`（`PK_ShipperID` で対象を指定）。
2. **B層**：`LayerB_Shippers`（`MyFcBaseLogic` 継承）に `UOC_` メソッドを実装（`opentouryo-layer-b`）。
   - `this.GetDam()` を渡して `DaoShippers` を生成。接続・コミットは書かない（フレームワークが行う）。
   - 更新・削除は `ExecInsUpDel_NonQuery()` 相当の**更新件数**を受け取り、**0 件なら業務例外**（`opentouryo-exception`）。
   - `CompanyName` 未入力などの入力チェック違反も業務例外。**業務例外は自分で `catch` しない**（フレームワークが戻り値へ変換）。
3. **P層**：`ShippersScreen`（`opentouryo-layer-p-webforms-screen` で新規作成、`-event` でイベント）。
   - 一覧 `GridView` にバインド。検索/登録/更新/削除は `btnSearch` / `btnAdd` / `btnUpdate` / `btnDelete`（`btn` 接頭辞）→ `UOC_btnXxx_Click`。
   - 各ハンドラで引数クラスを組み立て、**`opentouryo-p-call-business` の手順**で B層をサービス論理名で呼ぶ。
   - 戻り値の `ErrorFlag` を判定し、`true` ならメッセージ表示（業務例外は例外では飛んでこない）。
4. **配線**：サービス定義に `LayerB_Shippers` を登録し、P層が渡す論理名で解決できるようにする（`opentouryo-transmission` 参照可）。

## 層分離の遵守点（実装中に自己チェック）

- 画面（P層）に SQL・業務判断を書いていない。
- B層で `try/catch` によるロールバックを書いていない（フレームワーク任せ）。業務例外をリスローしていない。
- D層（Dao）で接続を開いていない・コミットしていない（`this.GetDam()` を受け取るだけ）。
- 更新・削除で**更新件数 0 を検知**している。

## 検証

- `docs/spec/tutorial1.md` の受入条件チェックリストを 1 項目ずつ確認する。
- ビルドが通ること（net48 は msbuild）。一覧・検索・登録・更新・削除・件数0・入力チェックの各動作を手で確認する。
