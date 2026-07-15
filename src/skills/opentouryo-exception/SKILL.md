---
name: opentouryo-exception
description: "OpenTouryo の例外処理方式を実装する。例外の型（BusinessApplicationException=業務例外 / BusinessSystemException=システム例外 / FrameworkException=フレームワーク例外）の選択、スロー、B層 BaseLogic による自動処理、戻り値クラス（BaseReturnValue の ErrorFlag / ErrorMessageID / ErrorMessage / ErrorInfo）への変換、UOC_ABEND での例外振替を扱う。例外 / エラー / エラーハンドリング / try / catch / throw / 業務例外 / システム例外 / 入力チェックエラー / 排他エラー / ロールバック を伴う作業のときに使う。B層・D層・P層のいずれのコードを書くときも、例外を扱うなら必ず参照する。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# OpenTouryo の例外処理方式

## 適用範囲

OpenTouryo の全層に共通する例外処理の規約。例外の型の選択、スローの仕方、B層フレームワークが
自動で行う処理、呼び出し側での受け取り方を扱う。

ログ出力・認証・構成ファイルは扱わない（`opentouryo-common` を参照）。

## 最重要：業務例外はリスローされない

OpenTouryo で最も間違えやすい規約。**一般的な .NET の作法と逆になる。**

B層で `BusinessApplicationException`（業務例外）をスローすると、フレームワークが捕捉して
**正常系の戻り値に変換する**。呼び出し側に例外は伝播しない。

```
B層で throw new BusinessApplicationException(...)
  → BaseLogic が catch → ロールバック → 戻り値へ変換 → リスローしない
  → 呼び出し側には「例外なし・戻り値あり」で返る
  → 呼び出し側は returnValue.ErrorFlag を判定して検知する
```

したがって、**呼び出し側で業務例外を `catch` してはならない**（飛んでこない）。
また **B層で業務例外を自分で `catch` してはならない**（フレームワークの変換が働かなくなる）。

## 例外の型

名前空間は `Touryo.Infrastructure.Framework.Exceptions`。すべて `System.Exception` を継承する。

| 型 | クラス | 区分 | 業務の続行 |
| --- | --- | --- | --- |
| 業務例外 | `BusinessApplicationException` | ユーザ定義エラー | 続行可能（リトライ可） |
| システム例外 | `BusinessSystemException` | ユーザ定義エラー | 続行不可能 |
| フレームワーク例外 | `FrameworkException` | ランタイムエラー | 続行不可能 |
| その他 | `Exception` 一般 | ランタイムエラー | 続行不可能 |

### コンストラクタとプロパティ

```csharp
// 業務例外：エラー情報（information）を持つのはこの型だけ
new BusinessApplicationException(string messageID, string message, string information);
new BusinessApplicationException(string messageID, string message, string information, Exception innerException);

// システム例外
new BusinessSystemException(string messageID, string message);
new BusinessSystemException(string messageID, string message, Exception innerException);

// フレームワーク例外（フレームワークが検知した例外に使う。業務コードから通常スローしない）
new FrameworkException(string messageID, string message);
new FrameworkException(string messageID, string message, Exception innerException);
```

| プロパティ | 型 | 保持する型 |
| --- | --- | --- |
| `messageID` | `string` | 全型（**小文字始まり**） |
| `Message` | `string` | 全型（`Exception` 由来） |
| `Information` | `string` | `BusinessApplicationException` のみ |

`messageID` は C# の命名規則に反して**小文字始まり**。`MessageID` と書くとコンパイルが通らない。

### 型を増やさない

**ユーザ定義エラー用の例外の型を追加してはならない。** エラーの種類は `messageID` の値で識別する。
新しいエラーが必要なら、新しい型ではなく新しい `messageID` を定義する。

### 型の選択基準

**業務例外** — リトライ可能なエラー。

- 単項目チェック、関連チェックのエラー
- 検索件数 0 件、更新件数 0 件（タイムスタンプ アンマッチ＝楽観排他の失敗）
- 追加時のキー重複、デッドロック、ロックタイムアウト
- 対象イベントのみ閉塞している場合（オンライン バッチ排他。例：参照系のみ許可、更新系は閉塞）

**システム例外** — アプリケーションで検出したが、リトライ不可能 or リトライさせたくないエラー。

- システムが閉塞している場合（休日・祝日、運用日程・時間スケジュールによる停止）
- リトライ不可能な、業務的なデータ不整合・インターフェイス不整合
- リトライさせたくない、業務的なデータ不整合・インターフェイス不整合

迷ったら「利用者がやり直せば成功しうるか」で判断する。しうるなら業務例外、しえないならシステム例外。

## B層フレームワークの自動処理

`BaseLogic.DoBusinessLogic()` が型ごとに異なる処理を行う。**業務コード側で書く必要はない。**

| スローした型 | ロールバック | 呼ばれる `UOC_ABEND` | リスロー | 呼び出し側への到達形 |
| --- | --- | --- | --- | --- |
| `BusinessApplicationException` | する | `(pv, rv, baEx)` | **しない** | 正常系の戻り値（`ErrorFlag = true`） |
| `BusinessSystemException` | する | `(pv, rv, bsEx)` | **する** | 例外 |
| その他すべて | する | `(pv, ref rv, ex)` | **しない** | `UOC_ABEND` の実装次第 |

コネクションの切断は `finally` で行われる。これも業務コード側で書かない。

### 注意：FrameworkException は個別に捕捉されない

`BaseLogic` は `FrameworkException` を個別に `catch` していない。`catch (Exception)` に落ちて
「その他」として扱われる。型としては独立しているが、B層での挙動は一般例外と同じ。

### 業務例外のとき戻り値へ自動設定される内容

```csharp
returnValue.ErrorFlag      = true;
returnValue.ErrorMessageID = baEx.messageID;
returnValue.ErrorMessage   = baEx.Message;
returnValue.ErrorInfo      = baEx.Information;
```

`returnValue` が `null` の場合は `BaseReturnValue` が生成される。

## 実装場所（誰がどこに書くか）

例外処理は3階層に分かれる。**書く場所を間違えると動かない、または共通処理を壊す。**

| 階層 | クラス | 担当 | 例外処理で書くこと |
| --- | --- | --- | --- |
| 業務コード親クラス1 | `BaseLogic`（`Touryo.Infrastructure.Framework.Business`） | フレームワーク | **触らない**。`UOC_ABEND` は `virtual` の空実装 |
| 業務コード親クラス2 | `MyFcBaseLogic`（`Touryo.Infrastructure.Business.Business`） | 纏め者 | `UOC_ABEND` を `override` し、ログ出力・例外振替などの**共通処理**を実装 |
| 業務コードクラス | `MyFcBaseLogic` を継承した業務クラス | 開発者 | `UOC_DoAction` / `UOC_（メソッド名）` に**業務処理**を実装。例外は**スローするだけ** |

<!--
  この分界は 利用ガイド の「纏め者編／開発者編」の切り分けに対応する。
  親クラス2 は Touryo.Infrastructure.Business（業務フレームワーク＝プロジェクト固有・
  カスタマイズ可能な層）に属するテンプレートで、纏め者が中身を編集する前提。
-->

`UOC_ABEND` は**親クラス2で一度だけ共通実装する**もの。業務コードクラス側で `override` してはならない。

### 親クラス2 は `MyFcBaseLogic` を使う

`MyBaseLogic` は非推奨。`[Obsolete("MyBaseLogic is deprecated, please use MyFcBaseLogic instead.")]`
が付いている。新規に書くコードで `MyBaseLogic` を継承してはならない。

リッチクライアント用も同様に、`MyBaseLogic2CS` は非推奨で `MyFcBaseLogic2CS` を使う。

## スローする（開発者）

業務コードクラスの `UOC_` メソッド内で、そのままスローする。try/catch もロールバックも書かない。

```csharp
using Touryo.Infrastructure.Framework.Exceptions;
using Touryo.Infrastructure.Framework.Util;

// 検索 0 件 → リトライ可能なので業務例外
if (dt.Rows.Count == 0)
{
    throw new BusinessApplicationException(
        "W0001",
        GetMessage.GetMessageDescription("W0001"),
        "");
}

// 更新 0 件（タイムスタンプ アンマッチ）→ 業務例外
if (rowsAffected == 0)
{
    throw new BusinessApplicationException(
        "W0002",
        GetMessage.GetMessageDescription("W0002"),
        "");
}

// システム閉塞 → リトライ不可なのでシステム例外
if (isSystemBlocked)
{
    throw new BusinessSystemException(
        "E0001",
        GetMessage.GetMessageDescription("E0001"));
}
```

`Information` には入力チェック結果などの付随情報を入れる。`string` なので、複雑な情報を返す
場合は戻り値クラス（`BaseReturnValue` の派生）を使う。

## 受け取る（開発者）

### 業務例外 — 戻り値を判定する

```csharp
MyReturnValue returnValue = (MyReturnValue)logic.DoBusinessLogic(parameterValue);

if (returnValue.ErrorFlag)
{
    // 業務例外が発生していた
    // returnValue.ErrorMessageID / ErrorMessage / ErrorInfo を使って
    // 利用者向けメッセージの生成、入力エラーの表示などを行う
}
```

### システム例外 — catch する

```csharp
try
{
    returnValue = (MyReturnValue)logic.DoBusinessLogic(parameterValue);
}
catch (BusinessSystemException bsEx)
{
    // bsEx.messageID / bsEx.Message を使う
}
```

## 例外振替（纏め者）

**親クラス2（`MyFcBaseLogic`）の `UOC_ABEND` に実装する共通処理。** 業務コードクラスには書かない。

一般例外を業務例外・システム例外へ振り替える場合は `UOC_ABEND(pv, ref rv, ex)` を使う。
このオーバーロードだけ `returnValue` が `ref` なのは、振替によって戻り値を差し替えるため。

```csharp
// 親クラス2（MyFcBaseLogic を継承したプロジェクトのテンプレート）に実装する
protected override void UOC_ABEND(
    BaseParameterValue parameterValue, ref BaseReturnValue returnValue, Exception ex)
{
    if (/* 業務例外へ振り替える条件 */)
    {
        returnValue.ErrorFlag      = true;
        returnValue.ErrorMessageID = "W0003";
        returnValue.ErrorMessage   = GetMessage.GetMessageDescription("W0003");
        returnValue.ErrorInfo      = "";
        // リスローしない → 正常系の戻り値として返る
    }
    else if (/* システム例外へ振り替える条件 */)
    {
        throw new BusinessSystemException("E0002", GetMessage.GetMessageDescription("E0002"));
    }
    else
    {
        // そのまま。スタックトレースを保って再スローする
        ExceptionDispatchInfo.Capture(ex).Throw();
    }
}
```

そのまま再スローするときは `throw ex;` ではなく `ExceptionDispatchInfo.Capture(ex).Throw()` を使う
（`throw ex;` はスタックトレースを破壊する）。

## やってはいけないこと

- **業務例外をリスローする** — フレームワークが戻り値へ変換する前提が崩れる
- **呼び出し側で業務例外を `catch` する** — 業務例外は伝播しないので、その `catch` は永久に実行されない
- **B層の `UOC_` メソッド内で `try`/`catch` してロールバックを書く** — `BaseLogic` が行うため二重になる
- **業務コードクラスで `UOC_ABEND` を `override` する** — 親クラス2 の共通処理を潰す。
  `UOC_ABEND` は纏め者が親クラス2 に一度だけ実装する
- **`MyBaseLogic` / `MyBaseLogic2CS` を継承する** — 非推奨。`MyFcBaseLogic` / `MyFcBaseLogic2CS` を使う
- **`MessageID` と書く** — 正しくは `messageID`（小文字始まり）
- **ユーザ定義エラー用の例外の型を新設する** — `messageID` で識別する
- **`throw ex;` で再スローする** — スタックトレースが失われる。`ExceptionDispatchInfo` を使う
- **入力チェックエラーにシステム例外を使う** — 利用者がやり直せるので業務例外
