---
name: opentouryo-layer-b
description: "OpenTouryo の B層（業務ロジック層）を実装する。業務コードクラス（MyFcBaseLogic の派生）、UOC_ メソッドへの業務処理の実装、レイトバインドによる自動振り分け、this.ReturnValue による戻り値の返し方、引数クラス（MyParameterValue の派生）と戻り値クラス（MyReturnValue の派生）、DoBusinessLogic / DoBusinessLogicAsync による呼び出し、UOC_ConnectionOpen での Dam 生成とトランザクション制御・分離レベルを扱う。リッチクライアント（2層C/S）用の MyFcBaseLogic2CS 系でも業務コードクラスの書き方は同じなので、その場合もこのスキルを使う（ただしトランザクション制御だけは別物なので opentouryo-layer-p-winforms を併せて読む）。B層 / 業務ロジック / LayerB / 業務コードクラス / トランザクション / 分離レベル / 2CS / 2層C/S を伴う作業のときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# B層（業務ロジック層）の実装

## このスキルの適用範囲

業務コードクラスに業務処理を実装する方法と、B層フレームワークの処理フローを扱う。

**対象は `BaseLogic` / `MyFcBaseLogic` 系（Web / MVC）。**

リッチクライアント（Windows Forms）は `BaseLogic2CS` / `MyFcBaseLogic2CS` 系だが、
**業務コードクラスの書き方はこのスキルがそのまま通用する。**
UOC のシグネチャ・自動振り分け・`this.ReturnValue`・直呼びガードはすべて同じ。
**読み替えるのは「継承元」と「トランザクション制御」の2点だけ**で、
どちらも `opentouryo-p-call-business` に書いてある（コネクションがグローバル、
コミットは手動、業務例外でロールバックしない）。

例外の型と処理方式は `opentouryo-exception`、Dao の実装は `opentouryo-layer-d`（3系統の使い分け）を参照。

## 実装場所（誰がどこに書くか）

| 階層 | クラス | 担当 | 書くもの |
| --- | --- | --- | --- |
| 業務コード親クラス1 | `BaseLogic`（`Touryo.Infrastructure.Framework.Business`） | フレームワーク | **触らない** |
| 業務コード親クラス2 | `MyFcBaseLogic`（`Touryo.Infrastructure.Business.Business`） | 纏め者 | 全業務共通の前後処理（`UOC_ConnectionOpen` / `UOC_PreAction` / `UOC_AfterAction` / `UOC_AfterTransaction` / `UOC_ABEND`） |
| 業務コードクラス | `MyFcBaseLogic` を継承した業務クラス | 開発者 | **`UOC_（メソッド名）` に業務処理のみ** |

**親クラス1・2 はビルド後のバイナリで提供されるため、ユーザプログラム開発プロジェクトでは
修正できない。** 以下の親クラス2 に関する記述は、**挙動を理解するためのもの**であって、
書き換えるためではない。作業対象は業務コードクラスの追加・修正だけ。

`MyBaseLogic` は非推奨。`MyFcBaseLogic` を継承する。

## 業務コードクラスの書き方

`MyFcBaseLogic` を継承する。クラス名はサンプルでは `LayerB` が多いが、機能名を付けたクラス
（`GetMasterData` など）も存在する。既存コードの命名に合わせる。

```csharp
using Touryo.Infrastructure.Business.Business;
using Touryo.Infrastructure.Business.Dao;

namespace MyApp.Logic.Business
{
    public class LayerB : MyFcBaseLogic
    {
        /// <summary>業務処理を実装</summary>
        private void UOC_SelectShipper(TestParameterValue testParameter)
        {
            // 戻り値クラスを生成して、事前に戻り値に設定しておく
            TestReturnValue testReturn = new TestReturnValue();
            this.ReturnValue = testReturn;

            // ↓業務処理

            // 個別Dao（this.GetDam() を渡す）
            LayerD myDao = new LayerD(this.GetDam());
            myDao.Select(testParameter, testReturn);

            // ↑業務処理
        }
    }
}
```

### UOC メソッドのシグネチャ

**この形以外は動かない。** 一般的な C# の感覚で書くと必ず外す。

```csharp
private void UOC_（メソッド名）(（BaseParameterValue の派生型） 引数)
```

| 要素 | 決まり | 理由 |
| --- | --- | --- |
| アクセス修飾子 | `private` で良い | レイトバインドで呼ばれるため。`public` にすると直呼びの危険がある |
| 戻り値の型 | **`void`** | 戻り値は `this.ReturnValue` で返す |
| 引数 | **1つだけ** | フレームワークが `object[] { parameterValue }` で渡す |
| 引数の型 | `BaseParameterValue` の派生型を指定可 | レイトバインドなので基底型である必要がない |
| メソッド名 | `UOC_` + 呼び出し側が渡す `MethodName` | 完全一致。ここがズレると実行時に見つからない |

### 戻り値は `this.ReturnValue` で返す

**メソッドの冒頭で、業務処理を書く前に設定する。** 順序が重要。

```csharp
TestReturnValue testReturn = new TestReturnValue();
this.ReturnValue = testReturn;   // ← 先に設定する
// 以降、testReturn に結果を詰めていく
```

理由：フレームワークは `finally` で `returnValue = this.ReturnValue;` を実行する。冒頭で設定して
おけば、**業務処理の途中で例外がスローされても戻り値が呼び出し側へ届く**。後で設定すると、
例外時に戻り値が失われる。

業務例外を投げても戻り値が返る（`opentouryo-exception` 参照）のは、この仕組みによる。

## 自動振り分け

`MyFcBaseLogic` が `UOC_DoAction` をオーバーライドし、レイトバインドで振り分ける。

```
呼び出し側が MethodName = "SelectShipper" を渡す
  → "UOC_" + MethodName = "UOC_SelectShipper"
  → Latebind.InvokeMethod(this, "UOC_SelectShipper", new object[]{ parameterValue })
  → finally で returnValue = this.ReturnValue
```

**振り分けはメソッド名の文字列一致**。コンパイラは検出しないので、`MethodName` と `UOC_` 以降の
綴りが一致しているかを目視で確認する。

ASP.NET Core MVC のサンプルでは、コントローラの `this.ActionName` を `MethodName` に渡している。
つまり **アクション名と `UOC_` メソッド名が対応する**。

## 引数クラス・戻り値クラス

```csharp
// 引数クラス：MyParameterValue を継承
public class TestParameterValue : MyParameterValue
{
    public ShipperViewModel Shipper { get; set; }

    // Base のコンストラクタに引数を渡すために必要
    public TestParameterValue(
        string screenId, string controlId, string methodName, string actionType, MyUserInfo user)
        : base(screenId, controlId, methodName, actionType, user) { }
}

// 戻り値クラス：MyReturnValue を継承
public class TestReturnValue : MyReturnValue
{
    public object Obj;
}
```

継承関係は `BaseParameterValue`（親1）← `MyParameterValue`（親2）← 業務用、
`BaseReturnValue`（親1）← `MyReturnValue`（親2）← 業務用。
名前空間は親2 が `Touryo.Infrastructure.Business.Common`。

`BaseParameterValue` が持つ `ScreenId` / `ControlId` / `MethodName` / `ActionType` は**読み取り専用**。
コンストラクタで渡す。

エラー系（`ErrorFlag` / `ErrorMessageID` / `ErrorMessage` / `ErrorInfo`）は `BaseReturnValue` が
持っているので、業務用の戻り値クラスに定義し直さない。

## 呼び出す（P層から）

```csharp
TestParameterValue pv = new TestParameterValue(
    this.ControllerName, "-", this.ActionName, actionType, this.UserInfo);

LayerB layerB = new LayerB();
TestReturnValue rv = (TestReturnValue)await layerB.DoBusinessLogicAsync(
    pv, DbEnum.IsolationLevelEnum.ReadCommitted);

if (rv.ErrorFlag)
{
    // 業務例外が発生していた（opentouryo-exception 参照）
}
```

エントリポイントは4つ。同期版と非同期版があり、それぞれ分離レベル指定の有無で2種類。

| メソッド | 用途 |
| --- | --- |
| `DoBusinessLogic(pv)` | 同期・既定の分離レベル |
| `DoBusinessLogic(pv, iso)` | 同期・分離レベル指定 |
| `DoBusinessLogicAsync(pv)` | 非同期・既定の分離レベル |
| `DoBusinessLogicAsync(pv, iso)` | 非同期・分離レベル指定 |

**非同期版は `BaseLogic2CS`（2層C/S）には無い。** 同期版の2つだけ。

**`UOC_` メソッドを直接呼んではならない。** `DoBusinessLogic` を経由しないと `this.ReturnValue` の
setter が `FrameworkException` をスローする（不正呼び出しとして検出される）。

## 処理フロー

`DoBusinessLogic` が以下の順で呼ぶ。**業務コードクラス側でこれらを書く必要はない。**

```
UOC_ConnectionOpen   … Dam 生成・接続・トランザクション開始（親クラス2）
try
  UOC_PreAction      … 前処理（親クラス2）
  UOC_DoAction       … 自動振り分け → UOC_（メソッド名）（業務コードクラス）
  UOC_AfterAction    … 後処理（親クラス2）
  Commit
  UOC_AfterTransaction … コミット後の後処理（親クラス2）
catch
  Rollback → UOC_ABEND（親クラス2）
finally
  コネクション切断
```

コミット・ロールバック・切断はすべてフレームワークが行う。**業務コードクラスに書かない。**

**これは `BaseLogic`（Web / MVC）の話。** `BaseLogic2CS`（Windows Forms）はコミットも切断も
自動で行わない（→「リッチクライアント（2CS）との差」）。

## トランザクション制御

`UOC_ConnectionOpen`（親クラス2）で Dam を生成し、`this.SetDam(dam)` で設定する。
業務コードクラスからは `this.GetDam()` で取得して Dao に渡す。

分離レベルは呼び出し側が `DbEnum.IsolationLevelEnum` で指定する。

| 値 | 意味 |
| --- | --- |
| `NotConnect` | **コネクションしない**（DB を使わない業務処理） |
| `NoTransaction` | 接続するがトランザクションを開始しない |
| `DefaultTransaction` | **DBMS の既定**の分離レベルで開始 |
| `ReadUncommitted` | 非コミット読み取りで開始 |
| `ReadCommitted` | コミット済み読み取りで開始 |
| `RepeatableRead` | 反復可能読み取りで開始 |
| `Serializable` | 直列化可能で開始 |
| `Snapshot` | スナップショットで開始 |
| `User` | **プロジェクトの既定**に委ねる（親クラス2 が振り替える） |

DBMS ごとに分離レベルの意味が異なるため、理解して設定する。

### `User` と `DefaultTransaction` の違い

どちらも「既定に任せる」だが、**誰の既定か**が違う。

| 値 | 誰の既定か | 決まる場所 |
| --- | --- | --- |
| `DefaultTransaction` | DBMS / データプロバイダ | Dam が引数なしの `BeginTransaction()` を呼ぶ |
| `User` | **プロジェクト** | 親クラス2（`MyFcBaseLogic`）が実際の分離レベルへ振り替える |

`User` は親クラス2 で消費されるマーカーで、Dam までは到達しない。

```csharp
// MyFcBaseLogic.UOC_ConnectionOpen の実装
if (iso == DbEnum.IsolationLevelEnum.User)
{
    // 自動トランザクション（規定の分離レベル）
    dam.BeginTransaction(DbEnum.IsolationLevelEnum.ReadCommitted);
}
else
{
    // 自動トランザクション（指定の分離レベル）
    dam.BeginTransaction(iso);
}
```

振替先は既定のテンプレートでは `ReadCommitted`。ただし**親クラス2 はプロジェクトごとに
整備されるため、この値はプロジェクトによって異なりうる**（バイナリで提供されるので、
ユーザプログラム開発プロジェクトからは変更できないし、中身も読めない）。

`User` は「このプロジェクトの標準の分離レベルに従う」という意味。呼び出し側に分離レベルを
意識させたくないときに使う。**`User` = `ReadCommitted` と決めつけない。**

`User` を Dam へ直接渡すと `ArgumentException`（無効な分離レベル）になる。`NotConnect` も同じ。

複数 DB を扱う場合は `SetDam(key, dam)` / `GetDam(key)` でキー付きの Dam を使う。
コミット・ロールバックは登録された全 Dam に対して実行される。

**キー付きの Dam は `BaseLogic2CS`（2層C/S）には無い。** Dam はアプリ全体で1つだけ。

## Dao の使い分け

業務コードクラスから使う Dao は3系統。**選び方は `opentouryo-layer-d`**、
実装の詳細は系統ごとのスキルを参照。

| 種類 | 生成 | 使う場面 | スキル |
| --- | --- | --- | --- |
| 個別Dao | `new LayerD(this.GetDam())` | 業務固有のデータアクセス | `opentouryo-dao-custom` |
| 共通Dao | `new CmnDao(this.GetDam())` | SQL ファイル / SQL 文を指定して実行 | `opentouryo-dao-common` |
| 自動生成Dao | `new DaoShippers(this.GetDam())` | テーブル単位の CRUD | `opentouryo-dao-generated` |

いずれも**コンストラクタに `this.GetDam()` を渡す**。Dao 側で接続を張らない。

## やってはいけないこと

- **`UOC_` メソッドに戻り値の型を付ける** — `void` にして `this.ReturnValue` で返す。
  レイトバインドなので戻り値は拾われない
- **`UOC_` メソッドの引数を2つ以上にする** — フレームワークは引数1つで呼ぶ。実行時に失敗する
- **`this.ReturnValue` の設定を業務処理の後に書く** — 例外時に戻り値が失われる。冒頭で設定する
- **`UOC_` メソッドを直接呼び出す** — `FrameworkException`（不正呼び出し）になる。
  `DoBusinessLogic` を経由する
- **業務コードクラスで `try`/`catch` してロールバックやコミットを書く** — フレームワークが行う
  （**2CS を除く**。`opentouryo-p-call-business` を参照）
- **業務コードクラスで `UOC_ABEND` などの前後処理を `override` する** — 親クラス2 の共通処理を潰す
- **`MyBaseLogic` を継承する** — 非推奨。`MyFcBaseLogic` を使う
- **Dao の中で接続を張る** — `this.GetDam()` を渡す
- **戻り値クラスにエラー系フィールドを定義し直す** — `BaseReturnValue` が持っている
