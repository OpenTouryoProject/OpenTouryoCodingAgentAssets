---
name: opentouryo-dao-custom
description: "OpenTouryo の個別Dao（業務固有のデータアクセスクラス）を実装する。MyBaseDao を継承した 個別Daoクラスの書き方、コンストラクタでの BaseDam の受け取り、SetSqlByFile2 / SetSqlByCommand による SQL の指定、SetParameter によるパラメタ設定（型・サイズ・ParameterDirection のオーバーロードを含む）、ExecSelectScalar / ExecSelectFill_DT / ExecSelectFill_DS / ExecSelect_DR / ExecInsUpDel_NonQuery による実行、GetParameter とストアドプロシージャ（戻り値・出力パラメタ）の実行、SetUserParameter の SQL インジェクション リスクを扱う。個別Dao / LayerD / 業務固有のデータアクセス / 複雑なSQL / ストアドプロシージャ を伴う作業のときに使う。共通Dao は opentouryo-dao-common、自動生成Dao は opentouryo-dao-generated、系統の選び方は opentouryo-layer-d を使う。"
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

// クラス名はプロジェクト依存（LayerD は個別Daoクラスのサンプル名。機能ごとに複数作る）
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
- **個別Daoクラス名はプロジェクト依存。`LayerD` はサンプルの名前で、`LayerD` になるとは限らない。**
  個別Daoクラスは**機能ごとに複数**作られる（テーブルや業務単位など）。名称付与規則は
  プロジェクトごとに決まるので、既存コードの命名に合わせる

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

## SetParameter のオーバーロード

**既定は基本形 `SetParameter(名前, 値)` を使う。** 型・サイズを指定するオーバーロードもあるが、
**指定する引数が増える**ので、むやみに使わない。

```csharp
protected void SetParameter(string name, object value);                                // 既定はこれ
protected void SetParameter(string name, object value, object dbTypeInfo);
protected void SetParameter(string name, object value, object dbTypeInfo, int size);
protected void SetParameter(string name, object value, object dbTypeInfo, int size,
    ParameterDirection paramDirection);
```

**型・サイズを明示するのは、暗黙の型変換による性能劣化が顕在化してから**
（先回りして指定しない。`opentouryo-query-definition` の該当節を参照）。
ただし `ParameterDirection`（下記ストアド）は出力を取るのに必要で、これは性能とは別。

**パラメタ名は接頭辞なし**（`"P1"`。`@` や `:` を付けない。接頭辞は DBMS ごとに
フレームワークが付ける）。**`dbTypeInfo` の型は DBMS 依存**：SQL Server は `SqlDbType.Int`、
Oracle は `OracleDbType.Int32` など（引数は `object` なのでどちらも渡せる）。

## ストアドプロシージャの実行

**入出力方向を `ParameterDirection` で指定し、戻り値・出力は `GetParameter` で取る。**

```csharp
public void CallProc(TestParameterValue pv, TestReturnValue rv)
{
    this.SetSqlByCommand("プロシージャ名");   // プロシージャ名を指定

    // 入力パラメタ（名前は接頭辞なし）
    this.SetParameter("P1", pv.Id);

    // 戻り値・出力パラメタは方向を指定して宣言する（型は DBMS 依存。下は SQL Server の例）
    this.SetParameter("ret", null, SqlDbType.Int, 4, ParameterDirection.ReturnValue);
    this.SetParameter("out", null, SqlDbType.Int, 4, ParameterDirection.Output);

    this.ExecInsUpDel_NonQuery();   // 実行

    // 実行後、GetParameter で取り出す
    rv.Ret = (int)this.GetParameter("ret");
    rv.Out = (int)this.GetParameter("out");
}
```

`ParameterDirection` は `ReturnValue` / `Output` / `InputOutput` / `Input`。
**出力系は `GetParameter(名前)` で取得する**（実行前は `null`、実行後に値が入る）。

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
- **先回りして `SetParameter` で型・サイズを指定する** — 既定は基本形。型指定は暗黙の型変換の
  性能劣化が顕在化してから（`ParameterDirection` はストアドの出力取得に必要で、これは別）
- **`ExecSelect_DR()` の `IDataReader` を閉じない** — コネクションが解放されない
- **`BaseDao` / `MyBaseDao` を修正しようとする** — バイナリで提供される
