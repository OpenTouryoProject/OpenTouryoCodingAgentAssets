---
name: opentouryo-screen-transition
description: "OpenTouryo の画面遷移制御機能を実装する。SCDefinition.xml に Screen / Transition / CmnTransition 要素で画面ごとの遷移先を定義し、FxScreenTransitionCheck 設定を on にしてフレームワークに自動チェックさせる。directLink=allow/deny による Get 直リンクの許可・拒否、定義にない遷移の FrameworkException による拒否を扱う。画面遷移 / 画面遷移制御 / 画面遷移定義 / SCDefinition / directLink / 直リンク拒否 / 不正遷移 を伴う作業のときに使う。ASP.NET Web Forms 専用（MVC / Windows Forms にはこの機能が無い）。Web Forms の画面実装は opentouryo-layer-p-webforms を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 画面遷移制御機能

> 📋 **コピー元スニペット**：`references/snippets.md`（ScreenTransition/FxTransfer/FxRedirect・SCDefinition.xml・config。実装時はここから写す）。

## このスキルの適用範囲

`SCDefinition.xml` の書式と、画面遷移チェックの有効化。

**ASP.NET Web Forms 専用。** MVC / Windows Forms にこの機能は無い。
Web Forms の画面実装そのものは `opentouryo-layer-p-webforms-screen` /
`opentouryo-layer-p-webforms-event` を参照。

## 実際の遷移手段は2通り（この機能は「チェック」の追加）

イベントハンドラで**遷移先を決める**基本手段はこの機能とは別にある。使い分け：

- **単純遷移**：ハンドラで URL を返す（`return "遷移先.aspx"`）、または `this.FxRedirect(url)` / `this.FxTransfer(url)`
  を呼ぶ。**SCDefinition 不要**。遷移しない（ポストバック）なら `return ""`（`opentouryo-layer-p-webforms-event`）。
- **論理名遷移＋チェック**：`this.ScreenTransition("遷移ラベル")` は `SCDefinition.xml` の**ラベル定義が必須**。
  併せて下の**チェック機能**で不正遷移を弾ける。

本スキルは主に後者（`SCDefinition.xml` とチェック）を扱う。単純遷移だけなら SCDefinition は要らない。

## 何のための機能か

**不正な画面遷移を検出して拒否する。** 定義にない遷移や、直リンク禁止の画面への Get アクセスを
`FrameworkException` で弾く。URL を直打ちして業務の途中から入る、といった操作を防ぐ。

**コードから呼ぶ API は無い。** 設定を ON にすれば、フレームワークが自動でチェックする。

## 有効化する（これを忘れると動かない）

**スイッチは `app.config` の `appSettings`（Web Forms 専用＝net48 なので XML。`appsettings.json` ではない）。**

```xml
<add key="FxScreenTransitionMode"  value="off"/>  <!-- T / R / off。off で機能そのものが無効 -->
<add key="FxScreenTransitionCheck" value="on"/>   <!-- 不正遷移チェックの on / off -->
```

| 設定値（`FxScreenTransitionCheck`） | 挙動 |
| --- | --- |
| `on` | 画面遷移をチェックする |
| `off` | チェックしない |
| **未設定** | **`off` 扱い**（チェックされない） |

※ `FxScreenTransitionMode` が `off` だと機能自体が無効（チェックも走らない）。
| 上記以外 | パラメータ・エラー（書式不正）で例外 |

**未設定だと黙って無効になる。** 定義ファイルを書いただけでは動かない。

## 定義ファイル

パスは `appSettings` の **`FxXMLSCDefinition`** で指定する（`opentouryo-config` 参照）。
**ランタイムによらず XML のまま。**

**定義例（DTD 埋め込み・`Screen`/`Transition`/`CmnTransition`・`directLink`=allow/deny・`mode`=T/R）は `references/snippets.md`。** 要素・属性は下表。

| 要素・属性 | 内容 |
| --- | --- |
| ルート要素 | `SCD` |
| `Screen` の `value` | 現画面の仮想パス |
| `Screen` の `directLink` | `allow` / `deny`。Get 直リンクを許すか。既定は `allow` |
| `Transition` の `value` | 遷移先の仮想パス |
| `Transition` の `label` | 遷移のラベル |
| `Transition` の `mode` | `T` / `R`。**DTD にあるが読み取る実装が無い**（後述） |
| `CmnTransition` | 全画面共通の遷移。`label` が `ID` 型 |

**`Screen` の `value` は `ID` 型にできない**（仮想パスに `/` を含むため）。
`CmnTransition` の `label` だけが `ID` 型で、**先頭に数字を使えない**。

### DTD を省かない

**DTD を埋め込んだ形式。** 他の OpenTouryo の XML 定義ファイルと共通の作法。

## directLink="deny" は Get による直リンクを拒否する

`deny` の画面へ URL 直打ち（Get）でアクセスすると **`FrameworkException`（画面遷移チェック
エラー）** になる。`allow` なら許可。

ログイン画面やメニュー画面は `allow`、業務の途中の画面は `deny` にする、という使い方。

`directLink` 属性そのものが無いと、これも `FrameworkException` になる（属性なしは許容されない）。
DTD の既定値は `allow` だが、**明示的に書く**。

## mode 属性は機能していない

DTD に `mode (T|R) #IMPLIED` と定義され、`FxLiteral.XML_SC_ATTR_MODE = "mode"` という定数も
あるが、**この定数を参照している実装が存在しない**。書いても効かない。

<!--
  確認済み: grep "XML_SC_ATTR_MODE" の結果は FxLiteral.cs の定義行のみ。
  Attributes["mode"] / GetAttribute("mode") も実装に無い。
  T=Transfer / R=Redirect の想定と見えるが、実装されていないため意味を断定しない。
  DevelopmentHistory.md 4.3 参照。
-->

## やってはいけないこと

- **`FxScreenTransitionCheck` を設定せずに `SCDefinition` を書く** — 未設定は `off` 扱い。
  **黙ってチェックされない**
- **`directLink` 属性を省く** — 属性なしは `FrameworkException` になる
- **`CmnTransition` の `label` の先頭に数字を使う** — XML の `ID` 型なので不正
- **DTD を省く** — 埋め込み形式が前提
- **`mode` 属性に意味があると考える** — DTD と定数だけで、読む実装が無い
- **MVC / Windows Forms でこの機能を使おうとする** — Web Forms 専用
- **この XML を `appsettings.json` に移そうとする** — ランタイムによらず XML のまま
