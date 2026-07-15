---
name: opentouryo-dao-custom
description: "OpenTouryo の個別Dao（業務固有のデータアクセスクラス）を実装する。MyBaseDao を継承した LayerD クラスの書き方、コンストラクタでの BaseDam の受け取り、SetSqlByFile2 / SetSqlByCommand による SQL の指定、SetParameter によるパラメタ設定、ExecSelectScalar / ExecSelectFill_DT / ExecSelectFill_DS / ExecSelect_DR / ExecInsUpDel_NonQuery による実行、SetUserParameter の SQL インジェクション リスクを扱う。個別Dao / LayerD / 独自Dao / 業務固有のデータアクセス / 複雑なSQL を伴う作業のときに使う。共通Dao は opentouryo-dao-common、自動生成Dao は opentouryo-dao-generated、系統の選び方は opentouryo-layer-d を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 個別Dao

## このスキルの適用範囲

**業務固有のデータアクセスクラス**（`MyBaseDao` を継承して手で書く Dao）の実装。

| 系統 | スキル |
| --- | --- |
| **個別Dao** | **このスキル** |
| 共通Dao（`CmnDao`） | `opentouryo-dao-common` |
| 自動生成Dao | `opentouryo-dao-generated` |
| 3系統の選び方 | `opentouryo-layer-d` |

SQL 定義ファイルの中身は `opentouryo-query-definition`、B層からの呼び出しは
`opentouryo-layer-b` を参照。

## 使う場面

**業務固有のデータアクセス。** 複雑な SQL、複数クエリの組み合わせ、業務的な単位でまとめたいとき。

テーブル単位の CRUD で足りるなら自動生成Dao、単発の SQL 実行だけなら共通Dao を使う
（`opentouryo-layer-d` 参照）。

## なぜ個別Dao を作るのか

**`BaseDao` の実行系メソッドはすべて `protected`。** 外部から呼べない。

```csharp
protected void ExecSelectFill_DT(DataTable dt)
protected int  ExecInsUpDel_NonQuery()
protected void SetParameter(string parameterName, object obj)
```

したがって `MyBaseDao` を継承し、**業務的な名前の `public` メソッドとして公開する**のが個別Dao。

## 実装場所

| 階層 | クラス | 修正 |
| --- | --- | --- |
| データアクセス親クラス1 | `BaseDao`（`Touryo.Infrastructure.Framework.Dao`） | **不可**（バイナリ提供） |
| データアクセス親クラス2 | `MyBaseDao`（`Touryo.Infrastructure.Business.Dao`） | **不可**（バイナリ提供） |
| データアクセスクラス | `MyBaseDao` を継承した Dao | **可**（ここに実装する） |

親クラス2 は `UOC_PreQuery` / `UOC_AfterQuery` に共通処理（性能測定・SQLトレースログ・例外振替）を
持つが、**バイナリで提供されるため利用側では変更できない。**

## 書き方

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
- クラス名は `LayerD` が慣例

### SQL の指定

| メソッド | 内容 |
| --- | --- |
| `SetSqlByFile2(ファイル名)` | SQL 定義ファイルから。`MyBaseDao` が `public` で追加 |
| `SetSqlByCommand(SQL文)` | SQL 文を直接指定 |

`SetSqlByFile2` に `.sql` を渡せば静的パラメタライズドクエリ、`.xml` を渡せば動的
パラメタライズドクエリになる（`opentouryo-query-definition` 参照）。

## 実行メソッド

`this.` 経由で呼ぶ。

| メソッド | 戻り値 | 用途 |
| --- | --- | --- |
| `ExecSelectScalar()` | `object` | 先頭1セルを取得（件数取得など） |
| `ExecSelectFill_DT(dt)` | `void` | `DataTable` に格納 |
| `ExecSelectFill_DS(ds)` | `void` | `DataSet` に格納 |
| `ExecSelect_DR()` | `IDataReader` | データリーダを取得。**使い終わったら `Close()` する** |
| `ExecInsUpDel_NonQuery()` | `int` | INSERT / UPDATE / DELETE。**更新件数を返す** |

`ExecInsUpDel_NonQuery()` の戻り値（更新件数）は捨てない。0 件は楽観排他の失敗などを意味する。

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

this.SetUserParameter("COLUMN", " " + orderColumn + " ");
```

前後に空白を付けているのは、動的 SQL の `VAL` タグが前後の空白をつめることがあるため。

## Dao集約クラスでまとめる方針のプロジェクト

プロジェクトによっては、Dao の呼び出しを**Dao集約クラス**でまとめ、B層から直接呼ばせない
方針をとる。集約クラスは**系統を問わず使える**仕組みで、詳細は `opentouryo-layer-d` を参照。
既存コードが集約クラス経由になっているなら、それに合わせる。

## やってはいけないこと

- **Dao の中で接続を張る** — コンストラクタで `BaseDam` を受け取る。B層が `this.GetDam()` で渡す
- **Dao の中でコミット・ロールバックする** — B層フレームワークが行う（`opentouryo-layer-b` 参照）
- **`ExecInsUpDel_NonQuery()` の戻り値を捨てる** — 更新件数 0 は楽観排他の失敗を意味する
- **`SetUserParameter()` にユーザ入力を渡す** — 文字列置換のため SQL インジェクションになる
- **`ExecSelect_DR()` の `IDataReader` を閉じない** — コネクションが解放されない
- **`BaseDao` / `MyBaseDao` を修正しようとする** — バイナリで提供される
