# テーブル・メンテナンス画面（一覧・詳細・更新）の P層パターン

`opentouryo-batch-update` の on-demand 参照。**Web Forms のテーブル保守 CRUD 画面**を、一覧/詳細/更新でどう分けるかの型。
出典：自動生成サンプル `Aspx/sample/3Tier/Products{ConditionalSearch,Detail,SearchAndUpdate}.aspx(.cs)`＋`ProductsTableAdapter.cs`＋実ソース `Business/Business/_3TierEngine.cs`・`Business/Presentation/CmnTableAdapter.cs`。

> **★ サンプルは自動生成（墨壺２）で、汎用エンジン `_3TierEngine`（`TableName`＋`Dictionary`＋`actionType` を渡すと内部で自動生成 SQL を直利用）を使う＝OpenTouryo の推奨実装とは少し違う。** 構造（画面分割・状態遷移・結果セット固定・RowState バッチ）を参考にし、**推奨部品**（`LayerB`/`DoBusinessLogic`＋自動生成 Dao＋DPQ＋RowState）で実装する。自動生成そのままを写さない。

## 2方式（どちらで作るか）

| 方式 | 画面構成 | 追加/更新/削除 | 使いどころ |
| --- | --- | --- | --- |
| **(1) 一覧→詳細**（`→`＝画面遷移） | 検索一覧 → **詳細** | すべて詳細画面で（単一レコード CRUD） | **オーソドックス。基本はこちら** |
| **(2) 一覧＆更新**（`＆`＝同一画面） | 検索一覧＝その場で更新/削除 | **UPDATE/DELETE は一覧で（複数行＝RowState バッチ）**・INSERT だけ詳細 | 一覧で直接編集したいとき（仕様がやや特殊） |

## (1) 一覧→詳細

- **検索一覧画面**：AND/OR/Like 条件 → WHERE を組む（推奨＝**動的クエリ DPQ** `.xml`。サンプルは条件を `Dictionary` で `_3TierEngine` に渡す）。GridView＋ページング（下記）。
  **行選択で主キー（＋タイムスタンプ）を `Session` に入れて**詳細へ遷移（`return "ProductsDetail.aspx"`）。追加ボタンも詳細へ（Session に PK を入れない＝新規モード）。
- **詳細画面**：**`Session` の PK 有無でモード分岐** — **無＝INSERT モード**（編集可・更新/削除ボタン不活性）、**有＝表示モード**（レコード取得・`ReadOnly`・編集ボタンで編集可に）。Insert/Update/Delete を実行。
  更新/削除は **PK＋タイムスタンプで楽観排他**（件数0チェック＝`opentouryo-layer-d`・`opentouryo-dao-generated`）。
- **状態持ち回り**：選択→詳細は別画面・別ポストバックをまたぐので **`Session` に PK＋TS**（`opentouryo-app-design/references/state-management.md`）。

## (2) 一覧＆更新（特殊）

- 一覧に行ごとの **[更新][削除]列**。**編集前はページング有効**（ObjectDataSource＝サーバ側ページング）。
- **★ 最初の [更新]/[削除] で「結果セットを固定」する**：`UOC_gvwGridView1_RowCommand` で当該行を編集（セル読み戻し→`Modified` ／ `dr.Delete()`→`Deleted`）した後、
  **ページングを止め（`AllowPaging=false`）、GridView を `Session` の `DataTable` にバインドし直す**（`DataSource=dt; DataSourceID=null; DataBind()`）。
  **理由：ページングはページ切替で再取得するため `RowState` を保てない。** 固定後は同一結果セット上で複数行を編集し、**[バッチ更新] で RowState バッチ更新**（`opentouryo-batch-update` 本文）。
- **INSERT は一覧でやらず詳細画面へ**（採番・全列入力が要るため）。
- グリッド index↔DataRow は **`Deleted` を飛ばして数える**、セルは **DataRow へ読み戻す**（`opentouryo-batch-update`「Web グリッド ↔ DataRow」＝本サンプルが実例）。

## ページング（P層 ⇄ D層）

- **P層**：GridView `AllowPaging`＋ObjectDataSource `EnablePaging`＝`SelectMethod(startRowIndex, maximumRows)`＋`SelectCountMethod()`（`CmnTableAdapter` 派生）でサーバ側ページング。ソートは `Session` に保持して SelectMethod へ。
- **D層**：**`ROW_NUMBER() OVER (ORDER BY …) BETWEEN @from AND @to`** で SQL ページング（DBMS 別＝SQL Server は `WITH … CTE`／Oracle は別式。`opentouryo-app-design/references/list-paging.md`）。総件数は別途 `COUNT`。
  ※ サンプルの `_3TierEngine` は内部でこの ROW_NUMBER SQL を自動生成している（`_3TierEngine.cs`）。

## 推奨実装への置き換え（自動生成 → 推奨）

| 自動生成サンプル | OpenTouryo 推奨実装 |
| --- | --- |
| 汎用エンジン `_3TierEngine`（`TableName`＋`Dictionary`＋`actionType`） | 業務ごとの **`LayerB`**（`UOC_Select/Insert/Update/Delete/BatchUpdate`）＋業務 **`ParameterValue`/`ReturnValue`** 派生（`opentouryo-layer-b`・`opentouryo-p-call-business`） |
| P→B＝`new _3TierEngine().DoBusinessLogic(pv, iso)` | **Web は `new LayerB().DoBusinessLogic(pv, iso)` 直呼び**（`opentouryo-p-call-business`「呼び出し経路の選択」） |
| 条件を `Dictionary` で渡す | **動的クエリ（DPQ）** の `.xml`（`opentouryo-query-definition`） |
| engine 内部の自動生成 SQL 直利用 | 自動生成 **Dao** を業務 Dao から呼ぶ（`S1/D1_Insert`・`S3/D3_Update`・`S4/D4_Delete`・件数 `D5_SelCnt`・ページング。`opentouryo-dao-generated`・`opentouryo-batch-update`） |
| `CmnTableAdapter`＋`ObjectDataSource`（ページング） | ページング機構は残してよい。ただし `SelectMethod` は engine でなく**業務 `LayerB` を呼ぶ** |

## やってはいけないこと

- **(2) でページングを止めずに複数行編集する** — ページ切替で再取得＝`RowState` が消える。**最初の編集で結果セットを固定**する。
- **一覧で INSERT を許す**（(2)）— 採番・全列入力が要る。INSERT は詳細画面へ。
- **グリッド index をそのまま DataRow index に使う** — `Deleted` で必ずずれる（`opentouryo-batch-update`）。
- **自動生成（`_3TierEngine`）のまま実装を残す** — 構造の参考に留め、推奨部品で書く。

> ※ WORKSPACE のサンプルは 2層化・整理で削除・変更されうる＝**本パターン（と上表の置き換え）を正とする**。
