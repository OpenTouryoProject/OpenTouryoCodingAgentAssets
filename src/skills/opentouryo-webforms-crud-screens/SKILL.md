---
name: opentouryo-webforms-crud-screens
description: "OpenTouryo の ASP.NET Web Forms でテーブル保守（マスタメンテ）の CRUD 画面を実装する。2方式＝(1) 一覧→詳細（検索一覧で行選択して詳細画面で単一レコードの追加・更新・削除。オーソドックス・既定）、(2) 一覧＆更新（一覧でその場で複数行を更新・削除＝RowState バッチ、追加だけ詳細画面）。検索条件（AND/OR/Like）→動的クエリ、GridView と ObjectDataSource による一覧・ページング・ソート、行選択で主キー＋タイムスタンプを Session に持ち回り、詳細画面の INSERT/表示モード分岐、(2) の「最初の編集で結果セットを固定＝ページング停止」、グリッド↔DataRow の対応付けを扱う。自動生成（_3TierEngine / CmnTableAdapter / ObjectDataSource）を推奨実装（LayerB/DoBusinessLogic＋自動生成 Dao＋DPQ＋RowState）へ置き換える指針も示す。テーブルメンテナンス画面 / 一覧画面 / 検索画面 / 詳細画面 / 一覧→詳細 / 一覧＆更新 / CRUD 画面 / マスタメンテ / GridView の更新・削除 を伴う作業のときに使う。バッチ更新の中核は opentouryo-batch-update、一覧ページングの SQL は opentouryo-app-design の list-paging を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# テーブル・メンテナンス画面（一覧・詳細・更新）の P層パターン

**Web Forms のテーブル保守 CRUD 画面**を、一覧/詳細/更新でどう分けるかの型。**ASP.NET Web Forms（net48）専用。**
実装の中核部品は `opentouryo-batch-update`（RowState バッチ）／`opentouryo-layer-p-webforms-screen`・`-event`（画面・グリッド）／`opentouryo-screen-transition`（遷移）／`opentouryo-app-design/references/list-paging.md`（ページング）。
出典：自動生成サンプル `Aspx/sample/3Tier/Products{ConditionalSearch,Detail,SearchAndUpdate}.aspx(.cs)`＋`ProductsTableAdapter.cs`＋実ソース `Business/Business/_3TierEngine.cs`・`Business/Presentation/CmnTableAdapter.cs`。

> 📋 **コピー元スニペット＋「何処を→どう書き換えるか」（自動生成→推奨）の対比は `references/snippets.md`**（サンプルは削除されうるのでスニペットを正とする）。

> **★ サンプルは自動生成（墨壺２）で、汎用エンジン `_3TierEngine`（`TableName`＋`Dictionary`＋`actionType` を渡すと内部で自動生成 SQL を直利用）を使う＝OpenTouryo の推奨実装とは少し違う。** 構造（画面分割・状態遷移・結果セット固定・RowState バッチ）を参考にし、**推奨部品**（`LayerB`/`DoBusinessLogic`＋自動生成 Dao＋DPQ＋RowState）で実装する。自動生成そのままを写さない。

## 2方式（どちらで作るか）

| 方式 | 画面構成 | 追加/更新/削除 | 使いどころ |
| --- | --- | --- | --- |
| **(1) 一覧→詳細**（`→`＝画面遷移） | 検索一覧 → **詳細** | すべて詳細画面で（単一レコード CRUD） | **オーソドックス。基本はこちら** |
| **(2) 一覧＆更新**（`＆`＝同一画面） | 検索一覧＝その場で追加/更新/削除 | **追加・更新・削除すべて一覧で（複数行＝RowState バッチ・[追加] はグリッド外ボタンで空行＝Added）** | 一覧で直接編集したいとき（**オプショナル**） |

> **★ Web系（MVC／Web Forms）ではバッチ更新〔(2)〕はオプショナル＝通常は (1) 一覧→詳細（詳細画面で単一レコード CRUD）で処理する。** 一覧でその場に複数行を編集したいときだけ (2) を採る。**(2) の追加・更新・削除は MVC と同一仕様**（`opentouryo-mvc-crud-screens`／`opentouryo-batch-update`）。

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
- **[追加] はグリッド外のボタンで一覧に空行を足す**（`dt.NewRow()`＋`dt.Rows.Add()`＝**Added**）＝**MVC と同一**（`opentouryo-mvc-crud-screens`／`opentouryo-batch-update`）。**DB 側 NOT NULL 列には値を入れる**（`DBNull` のまま INSERT で `SqlException 515`）・**IDENTITY は `D1_Insert`**・仮採番は仮 PK を使うときだけ。※ サンプル（`ProductsSearchAndUpdate`）は追加を詳細画面でやる as-built だが、**本パターンはグリッド外 [追加] で一覧に空行**（追加・更新・削除を一覧で完結）。
- グリッド index↔DataRow は **`Deleted` を飛ばして数える**、セルは **DataRow へ読み戻す**（`opentouryo-batch-update`「Web グリッド ↔ DataRow」＝本サンプルが実例）。
- **★ 行ボタンの配置は3パターン**（MVC も同型＝`opentouryo-mvc-crud-screens`。ただし MVC は `formaction`＋`RowIndex` で分岐＝`ButtonField`/`RowCommand`/`EditIndex` は使わない）：**① [削除] のみ／② [更新][削除]／③ [編集][削除]**。サンプル（`ProductsSearchAndUpdate.aspx`）は行に **`<asp:ButtonField CommandName="Update" Text="更新"/>`＋`CommandName="Delete" Text="削除"`**＝**② 型**。`UOC_gvwGridView1_RowCommand` で **`fxEventArgs.InnerButtonID`** を `switch` し、`PostBackValue` の表示 index から当該 `DataRow` を引く（`Added`/`Deleted` を飛ばして数える）。
  - **[更新]＝当該行の更新イベント**：その行の `txt<列>`/`ddl<列>` を `DataRow` に読み戻して **`Modified`**（DB へはまだ出さない）。
  - **[編集]＝当該行だけ編集可**にする（GridView の `EditIndex` にその行を設定＝他行は表示のまま）→ 編集後に **[更新]** を押して読み戻す。※ 本サンプルは全行を常時 TextBox 編集可＝[編集] 無しの ② 型。
  - **[削除]＝`dr.Delete()`**（`Deleted`。`Added` 行は Delete できないのでスキップ）。
  - **どの行ボタンも実 CUD は出さない＝`RowState` を作るだけ。実反映はグリッド外 [バッチ更新]（`btnBatUpd`「下記の結果セットをバッチ更新する」）で一括**。行ボタン押下後は結果セット固定（`AllowPaging=false`→`DataSource=dt` 再バインド）＝上記のとおり。
  - **★ 読み戻しは「追加行は常に／既存行はその行の [更新] のときだけ／削除行は対象外」（重要・実測）**：`RowCommand` は再バインド（`DataSource=dt`）を伴う。**追加行は DB に戻す値が無く、読み戻しを落とすと再バインドで空行に戻る**＝どの行ボタンでも毎回読み戻す。**既存行は取得時の値が `DataTable` に残る**＝その行の [更新] が押されたときだけ読み戻せばよい（読み戻さない＝「未確定」で [更新] を押すまで DB に出ない。**無駄 `Modified`／過敏な楽観排他も減る**）。判定1行＝`if (dr.RowState != DataRowState.Added && 表示index != 対象index) continue;`（[更新]＝当該行 index・[削除]/[バッチ更新]＝-1＝追加行のみ）。**※ 行 [更新] を置かない（[削除]のみ）パターンは、既存行を per-row 確定する手段が無いので [バッチ更新] で全レコードを読み戻す。**

## ページング（P層 ⇄ D層）

- **P層**：GridView `AllowPaging`＋ObjectDataSource `EnablePaging`＝`SelectMethod(startRowIndex, maximumRows)`＋`SelectCountMethod()`（`CmnTableAdapter` 派生）でサーバ側ページング。ソートは `Session` に保持して SelectMethod へ。
- **D層**：**`ROW_NUMBER() OVER (ORDER BY …) BETWEEN @from AND @to`** で SQL ページング（DBMS 別＝SQL Server は `WITH … CTE`／Oracle は別式。`opentouryo-app-design/references/list-paging.md`）。総件数は別途 `COUNT`。
  ※ サンプルの `_3TierEngine` は内部でこの ROW_NUMBER SQL を自動生成している（`_3TierEngine.cs`）。
- **★ (2) はバッチ更新のため編集中の `DataTable` を `Session` に持つ＝件数がメモリを圧迫する。** **レコード件数に上限を設けるか、ページングを前提にする**
  （Web Forms は net48＝`DataTable` は binary シリアライズ可能で InProc も StateServer/SQLServer も直列化の手当ては要らない。Core の MVC で JSON 化が要る話は `opentouryo-mvc-crud-screens`）
  （大量一覧では必須）。**ページングする場合は編集開始後にページングを止める**（上記「結果セット固定」。`opentouryo-batch-update`）。
- **★ 置き場は `Session` か `ViewState` か**：(2) は同一画面のポストバックで完結するので **`ViewState` も検討する**（`this.ViewState["dt"] = dt;`／復元 `(DataTable)this.ViewState["dt"]` を `Session` の代わりに使い、`DataSource=dt` で GridView に再バインド）。
  **NW オーバーヘッドは増える（`__VIEWSTATE` に全表が載って往復する）が、サーバ メモリを使わず後始末が要らない**のが大きな利点（`Session` は使用後に消す／LRU 上限が要る）。件数が多いと ViewState が肥大するので上限/ページングは同様に要る（`opentouryo-app-design/references/state-management.md`）。

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
- **追加行の DB 側 NOT NULL 列を空のまま [バッチ更新] する**（(2)）— INSERT で `SqlException 515`。グリッド外 [追加] で空行を足したら NOT NULL 列に値を入れる（`opentouryo-batch-update`）。
- **グリッド index をそのまま DataRow index に使う** — `Deleted` で必ずずれる（`opentouryo-batch-update`）。
- **自動生成（`_3TierEngine`）のまま実装を残す** — 構造の参考に留め、推奨部品で書く。

> ※ 配布サンプルは 2層化・整理で削除・変更されうる＝**本パターン（と上表の置き換え）を正とする**。
