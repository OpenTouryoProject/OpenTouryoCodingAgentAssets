---
name: opentouryo-layer-d
description: "OpenTouryo の D層（データアクセス層）を実装する。Dao 3系統（個別Dao / 共通Dao=CmnDao / D層自動生成ツールが生成する自動生成Dao）の使い分けと、Dao集約クラス（BaseConsolidateDao）、MyBaseDao の継承、SetSqlByFile2 / SQLFileName / SQLText による SQL の指定、SetParameter によるパラメタ設定、ExecSelectScalar / ExecSelectFill_DT / ExecSelectFill_DS / ExecSelect_DR / ExecInsUpDel_NonQuery の実行、自動生成Dao の S1_Insert / D2_Select / S3_Update / D4_Delete 等の命名体系と PK_ / Set_x_forUPD / x_Like プロパティ、タイムスタンプによる楽観排他を扱う。D層 / Dao / Dam / DB アクセス / SQL / CRUD / 楽観排他 を伴う作業のときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# D層（データアクセス層）の実装

## このスキルの適用範囲

Dao の実装と、3系統（個別 / 共通 / 自動生成）の使い分けを扱う。

B層からの呼び出しと Dam の取得は `opentouryo-layer-b`、例外は `opentouryo-exception` を参照。
**SQL 定義ファイル（`.sql` / `.xml`）の中身の書き方は `opentouryo-query-definition`** を参照。

## 実装場所（誰がどこに書くか）

| 階層 | クラス | 担当 | 書くもの |
| --- | --- | --- | --- |
| データアクセス親クラス1 | `BaseDao`（`Touryo.Infrastructure.Framework.Dao`） | フレームワーク | **触らない** |
| データアクセス親クラス2 | `MyBaseDao`（`Touryo.Infrastructure.Business.Dao`） | 纏め者 | `UOC_PreQuery` / `UOC_AfterQuery` に共通処理（性能測定・SQLトレースログ・例外振替） |
| データアクセスクラス | `MyBaseDao` を継承した Dao | 開発者 | データアクセス処理 |

### なぜ個別Dao を作るのか

**`BaseDao` の実行系メソッドはすべて `protected`。** 外部から呼べない。

```csharp
protected void ExecSelectFill_DT(DataTable dt)
protected int  ExecInsUpDel_NonQuery()
protected void SetParameter(string parameterName, object obj)
```

したがって `MyBaseDao` を継承し、**業務的な名前の `public` メソッドとして公開する**のが個別Dao。
`CmnDao` は例外で、`public new` で親のメソッドを再公開している（後述）。

## Dao 3系統の使い分け

いずれも `MyBaseDao` を継承する。B層からは**コンストラクタに `this.GetDam()` を渡して生成**する。

| 系統 | クラス | 出所 | 使う場面 |
| --- | --- | --- | --- |
| 個別Dao | `LayerD : MyBaseDao` | 手書き | 業務固有のデータアクセス。複雑な SQL、複数クエリの組み合わせ、業務的な単位でまとめたいとき |
| 共通Dao | `CmnDao : MyBaseDao` | フレームワーク提供。そのまま使う | SQL ファイル名か SQL 文を指定して単発で実行するとき |
| 自動生成Dao | `DaoXxx : MyBaseDao` | D層自動生成ツール（墨壺）が生成 | テーブル単位の CRUD |

### 選ぶ順序

1. **テーブル単位の CRUD で足りるか** → 足りるなら**自動生成Dao**。
   タイムスタンプ列があれば**楽観排他が組み込まれる**ので、更新系は特にこれを使う
2. **単発の SQL を実行するだけか** → **共通Dao**
3. **上記で表せないか**（複数クエリ、業務ロジックを伴う） → **個別Dao**

自動生成Dao は手で書き換えない。テーブル定義が変わったらツールで再生成する。

なお、プロジェクトによっては自動生成Dao を**Dao集約クラス**でまとめ、B層から直接呼ばせない方針を
とる（後述）。既存コードがその作りなら、それに合わせる。

## 個別Dao

```csharp
using Touryo.Infrastructure.Business.Dao;
using Touryo.Infrastructure.Public.Db;

public class LayerD : MyBaseDao
{
    public LayerD(BaseDam dam) : base(dam) { }

    public void Select(TestParameterValue testParameter, TestReturnValue testReturn)
    {
        // SQL を指定する（ファイル名 or SQL 文のいずれか）
        this.SetSqlByFile2("ShipperSelect.sql");
        //this.SetSqlByCommand("SELECT * FROM Shippers WHERE ShipperID = @P1");

        // パラメタを設定する
        this.SetParameter("P1", testParameter.Shipper.ShipperID);

        // 実行する
        DataTable dt = new DataTable();
        this.ExecSelectFill_DT(dt);

        // 戻り値クラスに詰める
        testReturn.Obj = dt;
    }
}
```

- コンストラクタで `BaseDam` を受け取り `base(dam)` に渡す。**Dao 側で接続を張らない**
- メソッドは `public`。引数クラス・戻り値クラスを引数に取るのが慣例
- SQL の指定は `SetSqlByFile2(ファイル名)`（`MyBaseDao` が `public` で追加）または
  `SetSqlByCommand(SQL文)`

## 共通Dao（CmnDao）

**SQL の指定方法が個別Dao と違う。** メソッドではなく**プロパティ**で指定する。

```csharp
CmnDao cmnDao = new CmnDao(this.GetDam());

cmnDao.SQLFileName = "ShipperSelect.sql";        // ファイルから
//cmnDao.SQLText   = "SELECT * FROM Shippers";   // SQL 文を直接

cmnDao.SetParameter("P1", testParameter.Shipper.ShipperID);

DataTable dt = new DataTable();
cmnDao.ExecSelectFill_DT(dt);
```

`SQLFileName` に `.sql` を渡せば静的パラメタライズドクエリ、`.xml` を渡せば動的パラメタライズド
クエリになる（`opentouryo-query-definition` 参照）。

`SQLFileName` と `SQLText` は**排他**。片方を設定すると、もう片方は内部でクリアされる。

**`CmnDao` に `SetSqlByFile2()` / `SetSqlByCommand()` を直接呼んではならない。** 継承しているので
コンパイルは通るが動かない。`CmnDao` の `ExecXxx()` は内部で `SQLFileName` / `SQLText` を読んで
SQL を組み立てるため、プロパティが空のままだと実行時に `BusinessSystemException`
（`CMN_DAO_ERROR`）になる。

## 実行メソッド

個別Dao（`this.` 経由）でも共通Dao でも同じ。

| メソッド | 戻り値 | 用途 |
| --- | --- | --- |
| `ExecSelectScalar()` | `object` | 先頭1セルを取得（件数取得など） |
| `ExecSelectFill_DT(dt)` | `void` | `DataTable` に格納 |
| `ExecSelectFill_DS(ds)` | `void` | `DataSet` に格納 |
| `ExecSelect_DR()` | `IDataReader` | データリーダを取得。**使い終わったら `Close()` する** |
| `ExecInsUpDel_NonQuery()` | `int` | INSERT / UPDATE / DELETE。**更新件数を返す** |

`ExecInsUpDel_NonQuery()` の戻り値（更新件数）は捨てない。0 件は楽観排他の失敗などを意味する。

## 自動生成Dao

D層自動生成ツール（墨壺）がテーブル単位で生成する。クラス名は `Dao<テーブル名>`。

### メソッドの命名体系

**`S` = 主キー指定（WHERE が主キー固定）／`D` = 任意の検索条件（WHERE も動的）。**

| メソッド | 意味 |
| --- | --- |
| `S1_Insert()` | 全列を指定して1レコード挿入（静的SQL `.sql`） |
| `D1_Insert()` | **パラメタで指定した列のみ**挿入（動的SQL `.xml`） |
| `S2_Select(dt)` | 主キーを指定し、1レコード参照 |
| `D2_Select(dt)` | 検索条件を指定し、結果セットを参照 |
| `S3_Update()` | 主キーを指定し、1レコード更新 |
| `D3_Update()` | 任意の検索条件で更新 |
| `S4_Delete()` | 主キーを指定し、1レコード削除 |
| `D4_Delete()` | 任意の検索条件で削除 |
| `D5_SelCnt()` | レコード件数を取得 |

Insert だけは主キー条件がないため、`S1` = 全列固定、`D1` = 指定列のみ、という区別になる。

### プロパティの命名体系

**値の設定はプロパティで行う。** 用途ごとに接頭辞・接尾辞が決まっている。

| プロパティ | 用途 |
| --- | --- |
| `PK_<列名>` | 主キーの値。**WHERE 句**に使われる |
| `<列名>` | 一般列の値。INSERT の値、D系の WHERE 条件に使われる |
| `Set_<列名>_forUPD` | **UPDATE の SET 句**の値 |
| `<列名>_Like` | LIKE 検索の条件 |

UPDATE では **WHERE 用（`PK_`）と SET 用（`Set_..._forUPD`）を必ず使い分ける**。
混同すると更新対象が変わる。

```csharp
DaoShippers genDao = new DaoShippers(this.GetDam());

// 参照（主キー指定）
genDao.PK_ShipperID = testParameter.Shipper.ShipperID;
DataTable dt = new DataTable();
genDao.S2_Select(dt);

// 更新（WHERE = 主キー、SET = Set_x_forUPD）
genDao.PK_ShipperID          = testParameter.Shipper.ShipperID;
genDao.Set_CompanyName_forUPD = testParameter.Shipper.CompanyName;
genDao.Set_Phone_forUPD       = testParameter.Shipper.Phone;
int count = genDao.S3_Update();

// 挿入（列の値をそのまま設定）
genDao.CompanyName = testParameter.Shipper.CompanyName;
genDao.Phone       = testParameter.Shipper.Phone;
genDao.D1_Insert();
```

## 楽観排他（タイムスタンプ）

タイムスタンプ列を持つテーブルの自動生成Dao には、**楽観排他が自動的に組み込まれる**。
生成される UPDATE 文が次の形になる。

```xml
SET
  <DELCMA>
    <IF>[val] = @Set_val_forUPD,</IF>
    [ts] = RAND(),          <!-- タイムスタンプ列は無条件に更新 -->
  </DELCMA>
<WHERE>
  WHERE
    <IF>AND [id] = @id<ELSE>AND [id] IS NULL</ELSE></IF>
    <IF>AND [ts] = @ts<ELSE>AND [ts] IS NULL</ELSE></IF>   <!-- 取得時の値と一致するか -->
</WHERE>
```

他者が先に更新していればタイムスタンプが一致せず、**更新件数が 0 になる**。

したがって**更新件数の 0 件チェックが楽観排他の判定そのもの**。0 件だったら業務例外
（タイムスタンプ アンマッチ）をスローする。詳細は `opentouryo-exception` を参照。

```csharp
int count = genDao.S3_Update();
if (count == 0)
{
    // 楽観排他の失敗。リトライ可能なので業務例外
    throw new BusinessApplicationException(
        "W0002", GetMessage.GetMessageDescription("W0002"), "");
}
```

## SetUserParameter にユーザ入力を渡さない

`SetParameter` と `SetUserParameter` は**別物**。

| メソッド | 仕組み | ユーザ入力 |
| --- | --- | --- |
| `SetParameter(名前, 値)` | パラメタライズドクエリのパラメタ | **渡してよい** |
| `SetUserParameter(名前, 値)` | **SQL 文字列への置換** | **渡してはならない** |

`SetUserParameter` は動的 SQL 中のプレースホルダを文字列置換するもので、ORDER BY の列名など
パラメタにできない箇所に使う。**ユーザ入力をそのまま渡すと SQL インジェクションになる。**

正しい使い方は、入力値を**コード側で安全な値に変換してから**渡す。

```csharp
// 入力値そのものではなく、コード内で決めた列名に変換して渡す
string orderColumn = "";
if (testParameter.OrderColumn == "c1")      { orderColumn = "ShipperID"; }
else if (testParameter.OrderColumn == "c2") { orderColumn = "CompanyName"; }

cmnDao.SetUserParameter("COLUMN", " " + orderColumn + " ");
```

前後に空白を付けているのは、動的 SQL の `VAL` タグが前後の空白をつめることがあるため。

## Dao集約クラス

**テーブル単位の自動生成Dao の呼び出しを集約するレイヤ。** 採用するかはプロジェクト基準による。

### 何のためにあるか

自動生成Dao はテーブル単位なので、B層から直接使うと**B層が DB スキーマを知ることになる**。
テーブル構成が変わるたびに B層が影響を受ける。

集約クラスを間に挟むと、B層は業務的な単位のメソッドを呼ぶだけになり、
どのテーブルをどう更新するかは集約クラスに閉じる。

```
【集約クラスなし】 B層 ──→ DaoShippers, DaoOrders …（B層がスキーマを知る）
【集約クラスあり】 B層 ──→ 集約クラス ──→ DaoShippers, DaoOrders …
```

### 書き方

`BaseConsolidateDao`（`Touryo.Infrastructure.Business.Dao`）を継承する。
**このクラスは `BaseDao` を継承していない。** Dao 自身ではなく、`Dam` を保持して
配るだけの `abstract` クラス。保持した `Dam` は `protected BaseDam Dam` で取得する。

```csharp
public class ShippingConsolidateDao : BaseConsolidateDao
{
    public ShippingConsolidateDao(BaseDam dam) : base(dam) { }

    /// <summary>業務的な単位のメソッドを公開する</summary>
    public void RegisterShipping(TestParameterValue param)
    {
        // 保持している Dam を各 Dao へ配る
        DaoShippers daoShippers = new DaoShippers(this.Dam);
        DaoOrders   daoOrders   = new DaoOrders(this.Dam);

        // 複数テーブルへの更新をここに閉じ込める
        daoShippers.PK_ShipperID = param.Shipper.ShipperID;
        daoShippers.Set_CompanyName_forUPD = param.Shipper.CompanyName;
        daoShippers.S3_Update();

        // ...
    }
}
```

B層からは他の Dao と同じく `this.GetDam()` を渡して生成する。

```csharp
ShippingConsolidateDao dao = new ShippingConsolidateDao(this.GetDam());
dao.RegisterShipping(testParameter);
```

<!--
  補足: BaseConsolidateDao は「Dao集約クラスのベースクラスの例」というコメントのみで、
  Samples / Samples4NetCore に利用実例が無い。上記コード例は、クラス定義（Dam を保持する
  abstract クラス）と設計意図から起こしたもの。
  実プロジェクトの実装例が手に入ったら、そちらに差し替えるのが望ましい。
-->

### 採用しているプロジェクトでの注意

集約クラスを使う方針のプロジェクトでは、**B層から自動生成Dao を直接呼ばない**。
既存コードが集約クラス経由になっているなら、それに合わせる。

## やってはいけないこと

- **Dao の中で接続を張る** — コンストラクタで `BaseDam` を受け取る。B層が `this.GetDam()` で渡す
- **Dao の中でコミット・ロールバックする** — B層フレームワークが行う（`opentouryo-layer-b` 参照）
- **自動生成Dao を手で書き換える** — 再生成で消える。ツールで生成し直す
- **`ExecInsUpDel_NonQuery()` の戻り値を捨てる** — 更新件数 0 は楽観排他の失敗を意味する
- **UPDATE で `Set_<列名>_forUPD` ではなく `<列名>` に値を入れる** — SET 句ではなく WHERE 条件になる
- **`SetUserParameter()` にユーザ入力を渡す** — 文字列置換のため SQL インジェクションになる
- **`ExecSelect_DR()` の `IDataReader` を閉じない** — コネクションが解放されない
- **`CmnDao` に `SetSqlByFile2()` / `SetSqlByCommand()` を直接呼ぶ** — コンパイルは通るが、
  実行時に `BusinessSystemException`（`CMN_DAO_ERROR`）になる。`SQLFileName` / `SQLText` を使う
