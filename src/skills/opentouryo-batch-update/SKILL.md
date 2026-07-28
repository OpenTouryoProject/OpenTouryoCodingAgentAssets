---
name: opentouryo-batch-update
description: "OpenTouryo で .NET DataTable の行編集状態（DataRowState：Added / Modified / Deleted）を使った明細一括（バッチ）更新を実装する。DataTable をバインドしたグリッド系 UI（Web Forms の GridView / ListView / Repeater / DataList、WinForms の DataGridView 等）で、グリッド外の追加ボタン→空行（Added）、グリッド内の削除ボタン→行を Delete（Deleted）、セル編集→Modified、を DataRow の RowState で判定し、自動生成 Dao（S1_Insert / D1_Insert・S3_Update / D3_Update・S4_Delete / D4_Delete・PK_列 / Set_列_forUPD）で一括反映する。DataRowVersion.Original を使った楽観排他、Deleted 行は Original しか読めない点、成功後の AcceptChanges、Web で複数ポストバックに跨る編集は DataTable を Session に保持、大量データ時の SQLUtility（GetInsertSQLParts / GetUpdateSQLParts）と BaseDao.ExecGenerateSQL を扱う。バッチ更新 / 一括更新 / 明細更新 / DataTable / RowState / グリッド / 追加行 / 削除行 / 楽観排他 / CommandBuilder の代替 を伴う作業のときに使う。自動生成 Dao は opentouryo-dao-generated、グリッドのイベントは opentouryo-layer-p-webforms-event。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# DataTable の RowState を使ったバッチ更新

> 📋 **RowState switch の全文・グリッド追加/削除・SQLUtility の実装は `references/snippets.md`**。
> 🖥 **Web Forms のテーブル保守 CRUD 画面パターン**（一覧→詳細／一覧＆更新、ページングと結果セット固定、自動生成→推奨実装への置き換え）は `references/webforms-crud-screens.md`。

## いつ使うか

**グリッド系 UI（Web Forms の `GridView` / `ListView` / `Repeater` / `DataList`、WinForms の `DataGridView` 等）に
`DataTable` をバインドして明細を編集し、まとめて更新する**とき。**特にリッチクライアント（WinForms）で
`DataGridView` に `DataTable`／`BindingSource` をバインドする構成で重宝する。**
一般的な仕様：**グリッド外の [追加] ボタンでグリッドに空行を足し、グリッド内の [削除] ボタンで行を消し、
セルを直接編集し、[更新] で一括反映**。この編集を **DataRow の `RowState`** が覚えているので、それで INSERT/UPDATE/DELETE を振り分ける。

- 出典：UserGuide ベターユース編 §4.3・§4.8、サンプル `Samples/2CS_sample/GenDaoAndBatUpd_sample`（実ソースで裏取り）。
- **`.NET の CommandBuilder / DataAdapter 自動更新は使わない**（タイムスタンプ アンマッチを拾えない・IDENTITY を INSERT に含める・全列比較の楽観排他で遅い、等）。代わりに `RowState` で自作する。

## UI 操作と RowState の対応

| UI 操作 | DataTable での操作 | 結果の `RowState` |
| --- | --- | --- |
| グリッド外 [追加] → 空行 | `DataRow nr = dt.NewRow(); …; dt.Rows.Add(nr);` | **`Added`** |
| セル編集 | 値を書き換え | **`Modified`** |
| グリッド内 [削除] | **`dr.Delete();`**（★ `Rows.Remove()` ではない） | **`Deleted`** |
| 変更なし | — | `Unchanged`（対象外） |

> ★ 削除は **`dr.Delete()`**。`dt.Rows.Remove(dr)` だと行が切り離され `Deleted` にならず、バッチが DELETE を出せない。

## B層での一括処理（核心）

`foreach (DataRow dr in dt.Rows)` で回し、**`switch (dr.RowState)`** で自動生成 Dao の CUD を呼ぶ。
行ごとに `dao.ClearParametersFromHt()` でパラメタをクリアする。コード全文は `references/snippets.md`。

- **`Added`** → `S1_Insert()`（**全列必須**＝生成 INSERT が全列に `@param` を持つ。列を1つでも設定しないと実行時エラー）。
  **一覧が全列でないなら `D1_Insert()`**（動的＝設定した列だけ INSERT する。生成 SQL を読んで判断＝`opentouryo-dao-generated`）。
- **`Modified`** → `PK_列` を設定、`Set_列_forUPD` に**現在値**、WHERE 用の列は**元の値**（下記）→ `S3_Update()` / `D3_Update()`。
- **`Deleted`** → `PK_列` を設定 → `S4_Delete()` / `D4_Delete()`。

（`S`=WHERE が主キー固定・`D`=WHERE 動的〔タイムスタンプ併用時〕。命名は `opentouryo-dao-generated`。）

## 楽観排他（`DataRowVersion.Original`）

**変更前の値**は `dr["列名", DataRowVersion.Original]` で取れる。UPDATE/DELETE の WHERE にこの元値
（またはタイムスタンプの元値）を入れると、**他者が先に更新していれば更新件数0**になる（＝タイムスタンプ アンマッチ。
`opentouryo-exception` / `opentouryo-dao-generated`）。件数0を業務例外にする。

> ★ **`Deleted` 行は `DataRowVersion.Original` しか読めない**（現在の値は存在しない）。削除行の PK も
> `dr["ProductID", DataRowVersion.Original]` で取る。

> ★ **複数行 DML の一般則（採番・実行順）と楽観排他方式は `opentouryo-layer-d`**。バッチ更新で特に効くのは：
> ①**IDENTITY 主キーは `S1_Insert()` で採番値が `DataTable` に戻らない**→ 反映後は一覧を再 SELECT して返す（追加直後の行に続けて操作しない）。
> ②同じキーを使い回すなら `switch(dr.RowState)` は **Deleted → Added の順**（Added を先に流すと旧行と衝突）。
> ③楽観排他は取得時の値を WHERE に入れて件数0で検知（タイムスタンプ列が無ければ全列 `Original`・`NULL`→`IS NULL`）。

## 反映後の後始末

- 成功後に **`dt.AcceptChanges()`** で `RowState` を `Unchanged` に戻す（保存済み状態に同期）。
- トランザクション境界は B層（`opentouryo-layer-b`）。途中で失敗したら業務例外/システム例外でロールバック。

## Web（複数ポストバックに跨る編集）

Web で複数回のポストバックに跨って編集する場合、**編集中の `DataTable` を `Session` などに保持**する
（`RowState` を保つため）。**サーバ メモリの消費に注意**（大きなデータを持たない・使用後は消す）。
**StateServer/SQLServer セッション モードなら保持する型は直列化可能に**（`DataTable` は可。`opentouryo-config`）。

### ★ Web グリッド ↔ DataRow の対応付け（index がずれる）

- **`Deleted` 行は `DefaultView`（既定の `RowStateFilter`）から外れてグリッドに表示されない** → **グリッドの
  `e.RowIndex` と `dt.Rows[i]` がずれる**。DataRow を引くときは `Deleted` を飛ばしながら数えるか、キーで引く。
  **素朴に `dt.Rows[e.RowIndex]` としない。**
- **`DataKeyNames`＋`DataKeys[i]` はバッチ更新では使えない**（`opentouryo-layer-p-webforms-event` は通常これを勧めるが、
  **追加行の主キーが未採番＝`DBNull`** なので成立しない）。バッチ更新時は DataRow 側で対応付ける。
- **セル編集は自動では `DataTable` に入らない** → グリッドのセルから **DataRow へ読み戻す**（`Modified` はこの代入で立つ）。
  **★ 元が `DBNull` の列に `""` を代入すると無駄な `Modified`（無駄 UPDATE）が量産される** → **現在値と一致するなら代入しない**。
  読み戻しスニペットは `references/snippets.md`。

## 大量データ（性能）

フレームワーク経由は 1 件 ≈ 0.5ms のオーバーヘッド。件数が多いなら次のいずれか：

- **配列バインド**（ODP.NET／HiRDB が対応）：`((DamManagedOdp)this.GetDam()).ArrayBindCount` に件数を設定し、各パラメタを
  **配列**で渡す（`OracleDbType` の明示が必須）。詳細は `opentouryo-dao-custom`。
- **バッチ SQL**（配列バインド非対応 DBMS の代替。サンプルは SQL Server）：**`SQLUtility`**（`Touryo.Infrastructure.Public.Db`）の
  `GetInsertSQLParts(dt)` / `GetUpdateSQLParts(dt, pk[])` で SQL パーツを生成し、1文に複数 VALUES を並べて `CmnDao` で実行（例は snippet）。
- **`ExecGenerateSQL`（実行せず SQL 文字列を生成）**：**自動生成 Dao は公開の2引数 `ExecGenerateSQL(fileName, sqlUtil)`** を持つ
  （内部で `SetSqlByFile2(fileName)`→`SetParametersFromHt()`→`base.ExecGenerateSQL(sqlUtil)`）。基底は `BaseDao.ExecGenerateSQL(sqlUtil)`（1引数・`protected`）／
  `CmnDao` は1引数 `public new`／実体は `BaseDam`。生成した静的 SQL を連結して `CmnDao` で流す。

## やってはいけないこと

- **CommandBuilder / DataAdapter の自動更新を使う** — フレームワーク非サポート。`RowState` で自作する
- **削除を `dt.Rows.Remove()` で行う** — `Deleted` にならず DELETE が出ない。**`dr.Delete()`** を使う
- **`Deleted` 行を現在値（`DataRowVersion` 省略）で読む** — 削除行は `Original` のみ。例外になる
- **楽観排他を忘れて主キーだけで UPDATE/DELETE する** — 上書き事故。WHERE に元値/タイムスタンプを入れ、件数0を検知する
- **更新後に `AcceptChanges()` を呼ばない** — 次の編集で `RowState` がズレる
- **Web で `DataTable` を Session に持ったまま肥大させる** — メモリを圧迫。使用後に消す
