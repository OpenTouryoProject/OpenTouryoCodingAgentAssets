# バッチ更新 コードスニペット（コピー元）

出典：UserGuide ベターユース編 §4.3・§4.8、`Samples/2CS_sample/GenDaoAndBatUpd_sample/Business/LayerB_BatUpd.cs`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## グリッド操作 → DataTable（RowState を作る）

```csharp
// [追加]（グリッド外のボタン）：空行を足す → RowState = Added
DataRow nr = dt.NewRow();
// nr["ProductName"] = "";  // 既定値を入れてよい
dt.Rows.Add(nr);

// [削除]（グリッド内のボタン）：★ Delete（Remove ではない）→ RowState = Deleted
dr.Delete();

// セル編集：値を書き換えると RowState = Modified
```

- **Web Forms（`GridView` / `ListView` / `Repeater` / `DataList`）**：削除ボタンの `UOC_gvw..._RowDeleting`（`GridView`）等で
  該当行を `Delete()`、追加ボタンの `UOC_btnAdd_Click` で `NewRow()`＋`Rows.Add()`（`opentouryo-layer-p-webforms-event`。
  `DataList` はイベント自動結線外＝ボタンで扱う）。複数ポストバックに跨るなら `DataTable` を Session に保持。
- **WinForms（`DataGridView`）**：`DataTable`（`BindingSource` 経由）をバインド。**[追加]／[削除] は通常のボタン**
  （`btn`＝`UOC_btnAdd_Click` / `UOC_btnDelete_Click`。`DataGridView` は自動結線外＝`opentouryo-layer-p-winforms-event`）。

```csharp
// WinForms: バインド
BindingSource bs = new BindingSource { DataSource = dt };
this.dataGridView1.DataSource = bs;

// [追加]（UOC_btnAdd_Click）：空行 → Added
DataRow nr = dt.NewRow();
dt.Rows.Add(nr);

// [削除]（UOC_btnDelete_Click）：選択行を Delete → Deleted
if (bs.Current is DataRowView drv) drv.Row.Delete();   // ★ Delete（Remove ではない）
```

## B層：RowState で振り分け（自動生成 Dao）

```csharp
DaoProducts dao = new DaoProducts(this.GetDam());

foreach (DataRow dr in dt.Rows)
{
    dao.ClearParametersFromHt();   // 行ごとにパラメタをクリア

    switch (dr.RowState)
    {
        case DataRowState.Added:
            // 全列を現在値で設定
            dao.PK_ProductID = dr["ProductID"].ToString();
            dao.ProductName  = dr["ProductName"].ToString();
            // …他の列…
            dao.S1_Insert();     // または D1_Insert()
            break;

        case DataRowState.Deleted:
            // ★ 削除行は Original しか読めない
            dao.PK_ProductID = dr["ProductID", DataRowVersion.Original].ToString();
            // 楽観排他するならタイムスタンプの Original もここで設定
            dao.D4_Delete();     // タイムスタンプ併用時は D4、主キーのみなら S4_Delete()
            break;

        case DataRowState.Modified:
            // WHERE 用：主キー＋（楽観排他するなら）元の値
            dao.PK_ProductID = dr["ProductID"].ToString();
            dao.ProductName  = dr["ProductName", DataRowVersion.Original].ToString();  // ← 元値で照合
            // …他の WHERE 列も Original…
            // SET 用：現在値
            dao.Set_ProductName_forUPD = dr["ProductName"].ToString();
            // …他の Set_列_forUPD も現在値…
            dao.D3_Update();     // タイムスタンプ併用時は D3、主キーのみの WHERE なら S3_Update()
            break;

        default:
            break;               // Unchanged はスキップ
    }
}

// 成功後：RowState を Unchanged に戻す
dt.AcceptChanges();
```

- `Set_列_forUPD`＝UPDATE の SET 句、`PK_列`＝WHERE、`列名`＝挿入/主キー以外（`opentouryo-dao-generated`）。
- 更新/削除の**件数0＝楽観排他の失敗**（タイムスタンプ アンマッチ）→ 業務例外（`opentouryo-exception`）。

## 大量データ：SQLUtility でバッチ INSERT（SQL Server のみ）

```csharp
// 第2・3引数は省略可（第2の既定は nvarchar）
SQLUtility su = new SQLUtility(DbEnum.DBMSType.SQLServer, "varchar", "yyyy/MM/dd");
string[] parts = su.GetInsertSQLParts(dt);   // [0]=列リスト, [1..]=各行の VALUES

string collist = parts[0];
StringBuilder sb = new StringBuilder();
for (int i = 1; i < parts.Length; i++) sb.Append(parts[i] + ",");
string values = sb.ToString().TrimEnd(',');

CmnDao cd = new CmnDao(this.GetDam());
cd.SQLText = string.Format("INSERT INTO Products{0} VALUES{1}", collist, values);
cd.ExecInsUpDel_NonQuery();
// → INSERT INTO Products([col..]) VALUES (..),(..),(..)  の1文
```

UPDATE は `su.GetUpdateSQLParts(dt, new string[]{ "ProductID" })`（第2引数＝キー列）。
自動生成 Dao 側に `ExecGenerateSQL(fileName, sqlUtil)`（`base.ExecGenerateSQL(sqlUtil)`）を足す手もある。

> ※ フレームワーク経由は 1 件 ≈ 0.5ms。件数が多いときだけバッチ SQL を検討（少数なら上の RowState ループで十分）。
