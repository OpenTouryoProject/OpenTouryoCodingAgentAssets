---
name: opentouryo-layer-d
description: "OpenTouryo の D層（データアクセス層）の全体像と、Dao 3系統（個別Dao / 共通Dao=CmnDao / D層自動生成ツールが生成する自動生成Dao）の使い分けを扱う。どの系統を使うべきかの判断基準、データアクセス親クラス1（BaseDao）・親クラス2（MyBaseDao）・データアクセスクラスの3階層、B層から this.GetDam() を渡して Dao を生成する共通の作法、Dao集約クラス（BaseConsolidateDao）による集約を扱う。D層 / データアクセス層 / Dao / DBアクセス / どのDaoを使うか / Dao集約クラス / BaseConsolidateDao を伴う作業のときに使う。実装の詳細は opentouryo-dao-custom（個別Dao）/ opentouryo-dao-common（共通Dao）/ opentouryo-dao-generated（自動生成Dao）を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# D層（データアクセス層）

> 📋 **コピー元スニペット**：`references/snippets.md`（データアクセスクラス骨格・SQL/パラメタ設定・実行5メソッド。実装時はここから写す）。

## このスキルの適用範囲

**D層の全体像と、Dao 3系統の使い分け。** 実装の詳細は系統ごとのスキルにある。

| 系統 | 実体 | 出所 | スキル |
| --- | --- | --- | --- |
| 個別Dao | `（機能名）: MyBaseDao`（**機能ごとに複数**。命名はプロジェクト依存） | 手書き | `opentouryo-dao-custom` |
| 共通Dao | `CmnDao : MyBaseDao` | フレームワーク提供。そのまま使う | `opentouryo-dao-common` |
| 自動生成Dao | `DaoXxx : MyBaseDao` | D層自動生成ツール（墨壺）が生成 | `opentouryo-dao-generated` |

**使う系統が決まっているなら、このスキルは読まずに該当スキルへ直行してよい。**

SQL 定義ファイルの中身は `opentouryo-query-definition`、B層からの呼び出しは
`opentouryo-layer-b`、例外は `opentouryo-exception` を参照。

## どの系統を使うか

1. **テーブル単位の CRUD で足りるか** → 足りるなら**自動生成Dao**。
   タイムスタンプ列があれば**楽観排他が組み込まれる**ので、更新系は特にこれを使う
2. **単発の SQL を実行するだけか** → **共通Dao**
3. **上記で表せないか**（複数クエリ、業務ロジックを伴う） → **個別Dao**

自動生成Dao は手で書き換えない。テーブル定義が変わったらツールで再生成する。

なお、プロジェクトによっては Dao を**Dao集約クラス**でまとめ、B層から直接呼ばせない方針をとる
（後述）。既存コードがその作りなら、それに合わせる。

## 実装場所

**3系統に共通。**

| 階層 | クラス | 修正 |
| --- | --- | --- |
| データアクセス親クラス1 | `BaseDao`（`Touryo.Infrastructure.Framework.Dao`） | **不可**（バイナリ提供） |
| データアクセス親クラス2 | `MyBaseDao`（`Touryo.Infrastructure.Business.Dao`） | **不可**（バイナリ提供） |
| データアクセスクラス | `MyBaseDao` を継承した Dao | **可**（ここに実装する） |

親クラス2 は `UOC_PreQuery` / `UOC_AfterQuery` に共通処理（性能測定・SQLトレースログ・例外振替）を
持つが、**バイナリで提供されるため利用側では変更できない。**

### なぜ個別Dao という系統があるのか

**`BaseDao` の実行系メソッドはすべて `protected`。** 外部から呼べない。

```csharp
protected void ExecSelectFill_DT(DataTable dt)
protected int  ExecInsUpDel_NonQuery()
```

したがって `MyBaseDao` を継承し、**業務的な名前の `public` メソッドとして公開する**のが個別Dao。
`CmnDao` は例外で、`public new` で親のメソッドを再公開している。

## 3系統に共通する作法

- **B層から `this.GetDam()` をコンストラクタに渡して生成する。** Dao 側で接続を張らない
- **Dao の中でコミット・ロールバックしない。** B層フレームワークが行う（`opentouryo-layer-b` 参照）
- **更新件数を捨てない。** 0 件は楽観排他の失敗などを意味する
- **ユーザ入力を `SetUserParameter` 系に渡さない。** 文字列置換なので SQL インジェクションになる

```csharp
// B層の業務コードクラスから
LayerD myDao     = new LayerD(this.GetDam());        // 個別Dao
CmnDao cmnDao    = new CmnDao(this.GetDam());        // 共通Dao
DaoShippers gen  = new DaoShippers(this.GetDam());   // 自動生成Dao
```

## Dao集約クラス

**複数の Dao の呼び出しを集約するレイヤ。系統を問わず使える。** 採用するかはプロジェクト基準による。

### 何のためにあるか

Dao を B層から直接使うと、**B層が DB スキーマや SQL の存在を知ることになる**。
特に自動生成Dao はテーブル単位なので、テーブル構成が変わるたびに B層が影響を受ける。

集約クラスを間に挟むと、B層は業務的な単位のメソッドを呼ぶだけになり、
どのテーブルをどう更新するかは集約クラスに閉じる。

```
【集約クラスなし】 B層 ──→ DaoShippers, DaoOrders, CmnDao …（B層がスキーマを知る）
【集約クラスあり】 B層 ──→ 集約クラス ──→ DaoShippers, DaoOrders, CmnDao …
```

### 書き方

`BaseConsolidateDao`（`Touryo.Infrastructure.Business.Dao`）を継承する。
**このクラスは `BaseDao` を継承していない。** Dao 自身ではなく、`Dam` を保持して
配るだけの `abstract` クラス。保持した `Dam` は `protected BaseDam Dam` で取得する。

**Dao の種類を限定しない。** 共通Dao も自動生成Dao も個別Dao も、同じように `this.Dam` を渡して
生成できる。

```csharp
public class ShippingConsolidateDao : BaseConsolidateDao
{
    public ShippingConsolidateDao(BaseDam dam) : base(dam) { }

    /// <summary>業務的な単位のメソッドを公開する</summary>
    public void RegisterShipping(TestParameterValue param)
    {
        // 保持している Dam を各 Dao へ配る（系統は問わない）
        DaoShippers daoShippers = new DaoShippers(this.Dam);   // 自動生成Dao
        CmnDao      cmnDao      = new CmnDao(this.Dam);        // 共通Dao

        // 複数テーブルへのアクセスをここに閉じ込める
        daoShippers.PK_ShipperID = param.Shipper.ShipperID;
        daoShippers.Set_CompanyName_forUPD = param.Shipper.CompanyName;
        daoShippers.S3_Update();

        cmnDao.SQLFileName = "OrderUpdate.sql";
        cmnDao.SetParameter("P1", param.Shipper.ShipperID);
        cmnDao.ExecInsUpDel_NonQuery();
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
  abstract クラス。Dao の種類を限定していない）と設計意図から起こしたもの。
  実プロジェクトの実装例が手に入ったら、そちらに差し替えるのが望ましい。
-->

### 採用しているプロジェクトでの注意

集約クラスを使う方針のプロジェクトでは、**B層から Dao を直接呼ばない**。
既存コードが集約クラス経由になっているなら、それに合わせる。

## やってはいけないこと

- **Dao の中で接続を張る** — コンストラクタで `BaseDam` を受け取る
- **Dao の中でコミット・ロールバックする** — B層フレームワークが行う
- **`BaseDao` / `MyBaseDao` を修正しようとする** — バイナリで提供される
- **自動生成Dao を手で書き換える** — 再生成で消える
- **集約クラスを使う方針のプロジェクトで、B層から Dao を直接呼ぶ** — 既存コードに合わせる
- **集約クラスが自動生成Dao 専用だと考える** — `BaseConsolidateDao` は `Dam` を保持する
  だけで、Dao の種類を限定しない。共通Dao も個別Dao も集約できる
