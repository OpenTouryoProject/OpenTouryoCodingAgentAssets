---
name: opentouryo-shared-property
description: "OpenTouryo の共有情報取得機能を実装する。SPDefinition.xml に SharedProp 要素で key と value の組を定義し、GetSharedProperty.GetSharedPropertyValue() で取得する。定義ファイルのパスは appSettings の FxXMLSPDefinition で指定する。共有情報 / SharedProp / SPDefinition / GetSharedProperty / アプリケーション共通の値 を伴う作業のときに使う。appSettings / connectionStrings の設定値は opentouryo-config、メッセージは opentouryo-message を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 共有情報取得機能

## このスキルの適用範囲

`SPDefinition.xml` の書式と `GetSharedProperty` の呼び出し。

- 設定値（`appSettings` / `connectionStrings`）→ `opentouryo-config`
- メッセージ → `opentouryo-message`

## 何のための機能か

**アプリケーション全体で共有する値を、設定ファイルとは別の場所に持つ。**
`appSettings` との使い分けはプロジェクトの判断。

## 定義ファイル

パスは `appSettings` の **`FxXMLSPDefinition`** で指定する（`opentouryo-config` 参照）。
**ランタイムによらず XML のまま**（`appsettings.json` になっても、この定義ファイルは XML）。

```xml
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE SPD[
	<!ELEMENT SPD (SharedProp*)>
	<!ELEMENT SharedProp EMPTY>
	<!ATTLIST SharedProp
		key ID #REQUIRED
		value CDATA #REQUIRED>
]>
<!-- key(id)の先頭には、数字を使用できない。 -->
<SPD>
	<SharedProp key="ConnectionString1" value="てすと１"/>
	<SharedProp key="HostName1" value="てすと３"/>
</SPD>
```

| 要素・属性 | 内容 |
| --- | --- |
| ルート要素 | `SPD` |
| `SharedProp` の `key` | キー。**XML の `ID` 型** |
| `SharedProp` の `value` | 値 |

### DTD を省かない

**DTD を埋め込んだ形式。** 他の OpenTouryo の XML 定義ファイルと共通の作法。

### key の先頭に数字を使えない

`key` は XML の `ID` 型なので、**先頭に数字を使えない**（`0001` は不可、`Key0001` は可）。

## 取得する

```csharp
using Touryo.Infrastructure.Framework.Util;

string v = GetSharedProperty.GetSharedPropertyValue("HostName1");
```

## やってはいけないこと

- **`key` の先頭に数字を使う** — XML の `ID` 型なので不正
- **DTD を省く** — 埋め込み形式が前提
- **定義ファイルを書いただけで動くと考える** — `GetSharedProperty.GetSharedPropertyValue()` を
  呼ぶ側のコードとセット
- **`FxXMLSPDefinition` の設定を忘れる** — パスを設定しないとファイルが読まれない
- **この XML を `appsettings.json` に移そうとする** — ランタイムによらず XML のまま
