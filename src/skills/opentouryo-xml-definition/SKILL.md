---
name: opentouryo-xml-definition
description: "OpenTouryo の XML 定義ファイルを書く。共有情報（SPDefinition.xml）、メッセージ（MSGDefinition.xml）、画面遷移制御（SCDefinition.xml）、トランザクション制御（TCDefinition.xml）、通信制御（TMProtocolDefinition.xml / TMInProcessDefinition.xml）の6種の書式と、GetSharedProperty / GetMessage / TransactionControl / ProtocolNameService / InProcessNameService による読み出し、メッセージの %1 / %2 プレースホルダ、カルチャ別ファイルによる国際化を扱う。SPDefinition / MSGDefinition / SCDefinition / TCDefinition / TMProtocolDefinition / TMInProcessDefinition / メッセージ定義 / 共有情報 / 画面遷移定義 / トランザクション パターン を伴う作業のときに使う。SQL 定義ファイルは opentouryo-query-definition を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# XML 定義ファイル

## このスキルの適用範囲

フレームワークが読む6種の XML 定義ファイルの書式。

**SQL 定義ファイル（`.sql` / `.xml`）は別物。** `opentouryo-query-definition` を参照。
設定値の取得全般は `opentouryo-config`。

## 6種の定義ファイル

**パスは `appSettings` の `Fx` キーで指定する**（`opentouryo-config` 参照）。
**ランタイムによらず XML のまま**（`appsettings.json` になっても、これらは XML）。

| 設定キー | ファイル | 用途 | 読み出す API |
| --- | --- | --- | --- |
| `FxXMLSPDefinition` | `SPDefinition.xml` | 共有情報 | `GetSharedProperty` |
| `FxXMLMSGDefinition` | `MSGDefinition.xml` | メッセージ | `GetMessage` |
| `FxXMLSCDefinition` | `SCDefinition.xml` | 画面遷移制御 | P層フレームワーク（**Web Forms のみ**） |
| `FxXMLTCDefinition` | `TCDefinition.xml` | トランザクション制御 | `TransactionControl` |
| `FxXMLTMProtocolDefinition` | `TMProtocolDefinition.xml` | 通信制御（プロトコルの名前解決） | `ProtocolNameService` |
| `FxXMLTMInProcessDefinition` | `TMInProcessDefinition.xml` | 通信制御（インプロセス呼び出しの名前解決） | `InProcessNameService` |

ファイル名は慣例。設定でパスを指定するので任意の名前にできる。

## 6種に共通する書式

**すべて DTD を埋め込んだ XML。** ルート要素はファイルごとに違う（`SPD` / `MSGD` / `SCD` /
`TCD` / `TMD`）。

```xml
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE SPD[
	<!ELEMENT SPD (SharedProp*)>
	<!ELEMENT SharedProp EMPTY>
	<!ATTLIST SharedProp
		key ID #REQUIRED
		value CDATA #REQUIRED>
]>
<SPD>
	...
</SPD>
```

### id の先頭に数字を使えない

**全ファイル共通の制約。** `id` / `key` 属性は XML の `ID` 型なので、
**先頭に数字を使えない**（`0001` は不可、`E0001` は可）。

各ファイルの先頭にこのコメントが入っている。

```xml
<!-- idの先頭には、数字を使用できない。 -->
```

## SPDefinition.xml（共有情報）

`key` と `value` の組を定義する。

```xml
<SPD>
	<SharedProp key="ConnectionString1" value="てすと１"/>
	<SharedProp key="HostName1" value="てすと３"/>
</SPD>
```

```csharp
string v = GetSharedProperty.GetSharedPropertyValue("HostName1");
```

## MSGDefinition.xml（メッセージ）

`id`（メッセージID）と `description`（メッセージの雛形）の組を定義する。

```xml
<!-- 先頭Eは異常系、先頭Iは正常系など -->
<MSGD>
	<Message id="I0001" description="～メッセージIDに対応する記述１（正常系）～"/>
	<Message id="E0001" description="○△□エラー、%1が%2しました。"/>
</MSGD>
```

**メッセージID は例外の `messageID` と対応する**（`opentouryo-exception` 参照）。
`I` = 正常系、`E` = 異常系という接頭辞は慣例で、フレームワークは解釈しない。

```csharp
string msg = GetMessage.GetMessageDescription("E0001");
```

### %1 / %2 は例外のフィールドで置換される

**`GetMessage` は置換しない。** 置換するのは P層の親クラス2。

| プレースホルダ | 置換される値 |
| --- | --- |
| `%1` | 業務例外の `Message`（可変文字列） |
| `%2` | 業務例外の `Information`（エラー情報） |

```csharp
// MyBaseController（Web Forms の親クラス2）の UOC_ABEND での実装
messageDescription = messageDescription.Replace("%1", baEx.Message);
messageDescription = messageDescription.Replace("%2", baEx.Information);
```

つまり**例外の `Message` は「完成した文」ではなく「雛形に埋める可変部分」**として使う。

```csharp
// MSGDefinition.xml: <Message id="E0001" description="○△□エラー、%1が%2しました。"/>
throw new BusinessApplicationException("E0001", "受注番号", "重複");
// → 「○△□エラー、受注番号が重複しました。」
```

<!--
  注意: この置換を実装しているのは MyBaseController（Web Forms の親クラス2）だけ。
  MVC / Core MVC / リッチクライアントの親クラス2 には Replace("%1", ...) が無い。
  実装コメントにも「方式は、プロジェクト毎に検討のこと。」とある。
  → 雛形＋可変文字列の方式は Web Forms のテンプレートが示す一例であって、
    フレームワークが強制する仕組みではない。
-->

**この置換は Web Forms の親クラス2 が行っているもの。** 実装にも
`// 方式は、プロジェクト毎に検討のこと。` とあり、MVC やリッチクライアントの親クラス2 には
この処理が無い。**使っているプロジェクトの親クラス2 の実装に依存する。**

### カルチャ別ファイルで国際化する

`FxExceptionMessageCulture` 設定と連動し、**ファイル名にカルチャ名を挟んだファイル**を探す。

```
MSGDefinition.xml          ← 既定
MSGDefinition_ja-JP.xml    ← ja-JP のとき
```

命名は `（ファイル名）_（カルチャ名）.xml`。

```csharp
string msg = GetMessage.GetMessageDescription("E0001", new CultureInfo("ja-JP"));
```

## TCDefinition.xml（トランザクション制御）

**トランザクション パターン**（接続文字列 + 分離レベル）と、
それを束ねた**トランザクション グループ**を定義する。

```xml
<TCD>
	<!-- トランザクション グループ：パターンをカンマ区切りで並べる -->
	<TransactionGroup id="SQL" value="SQL_NT,SQL_UC,SQL_RC,SQL_RR,SQL_SZ,SQL_SS,SQL_DF"/>

	<!-- トランザクション パターン -->
	<TransactionPattern id="SQL_RC" connkey="ConnectionString_SQL" isolevel="rc"/>
	<TransactionPattern id="SQL_SZ" connkey="ConnectionString_SQL" isolevel="sz"/>
</TCD>
```

| 属性 | 内容 |
| --- | --- |
| `connkey` | 接続文字列のキー（`connectionStrings` セクションのキー名） |
| `isolevel` | 分離レベル。**2文字の略号**。既定は `rc` |

### isolevel の略号

`DbEnum.IsolationLevelEnum` に対応する（`opentouryo-layer-b` 参照）。

| 略号 | 分離レベル |
| --- | --- |
| `nc` | コネクションしない（`NotConnect`） |
| `nt` | ノー トランザクション（`NoTransaction`） |
| `uc` | リード アン コミット（`ReadUncommitted`） |
| `rc` | リード コミット（`ReadCommitted`）**既定** |
| `rr` | リピータブル リード（`RepeatableRead`） |
| `sz` | シリアライザブル（`Serializable`） |
| `ss` | スナップ ショット（`Snapshot`） |
| `df` | デフォルト（規定の分離レベル。`DefaultTransaction`） |

**`User` に対応する略号は無い**（`User` は親クラス2 が振り替えるためのマーカーで、
Dam へ渡らない。`opentouryo-layer-b` 参照）。

## SCDefinition.xml（画面遷移制御）

**Web Forms 専用**（`opentouryo-layer-p-webforms` 参照）。画面ごとに、遷移してよい先を定義する。

```xml
<SCD>
	<Screen value="/ProjectX_sample/Aspx/start/menu.aspx" directLink="allow">
	</Screen>
	<Screen value="/ProjectX_sample/Aspx/testScreenCtrl/WebForm1.aspx" directLink="deny">
		<Transition value="/ProjectX_sample/Aspx/testScreenCtrl/WebForm2.aspx" label="1→2"/>
	</Screen>
</SCD>
```

| 要素・属性 | 内容 |
| --- | --- |
| `Screen` の `value` | 現画面の仮想パス |
| `Screen` の `directLink` | `allow` / `deny`。直リンクを許すか。既定は `allow` |
| `Transition` の `value` | 遷移先の仮想パス |
| `Transition` の `label` | 遷移のラベル |
| `Transition` の `mode` | `T` / `R`。**DTD にあるが、読み取る実装が無い**（後述） |
| `CmnTransition` | 全画面共通の遷移 |

**`Screen` の `value` は `ID` 型にできない**（仮想パスに `/` を含むため）。
`CmnTransition` の `label` だけが `ID` 型。

### mode 属性は機能していない

DTD に `mode (T|R) #IMPLIED` と定義され、`FxLiteral.XML_SC_ATTR_MODE = "mode"` という定数も
あるが、**この定数を参照している実装が存在しない**。書いても効かない。

<!--
  確認済み: grep "XML_SC_ATTR_MODE" の結果は FxLiteral.cs の定義行のみ。
  Attributes["mode"] / GetAttribute("mode") も実装に無い。
  DTD と定数だけが残っている状態。T=Transfer / R=Redirect の想定と見えるが、
  実装されていないため意味を断定しない。
-->

## TMInProcessDefinition.xml（通信制御・インプロセス）

**サービス論理名から、呼び出すアセンブリとクラスを解決する。**

```xml
<TMD>
  <Transmission id="testInProcess" assemblyName="WSServer_sample"
                className="WSServer_sample.Business.LayerB" />
</TMD>
```

| 属性 | 内容 |
| --- | --- |
| `id` | サービス論理名 |
| `assemblyName` | アセンブリ名 |
| `className` | クラス名（名前空間を含む完全名） |

## TMProtocolDefinition.xml（通信制御・プロトコル）

**サービス論理名から、呼び出すプロトコルと URL を解決する。**

```xml
<TMD>
  <!-- マスタ データ -->
  <Url id="url_c" value="net.tcp://localhost:7777/WCFService/WCFTCPSvcForFx/"/>
  <Prop id="prop_a" value="..."/>

  <!-- 明細 -->
  <Transmission id="testWebService" protocol="2" url_ref="url_c" timeout="60"/>
</TMD>
```

| 属性 | 内容 |
| --- | --- |
| `protocol` | **`1` = InProcess、`2` = WebService** |
| `url` / `url_ref` | URL を直接指定するか、`Url` 要素を参照する（`IDREF`） |
| `prop_ref` | `Prop` 要素を参照する（`IDREF`） |
| `timeout` | タイムアウト |

**`Url` / `Prop` をマスタとして定義し、`Transmission` から `url_ref` / `prop_ref` で参照する**
構造。同じ URL を複数のサービスで使う場合に重複を避けられる。

### Prop はプロパティ文字列

`Prop` の `value` には **`名前=値;` を並べた文字列**を書く。

```xml
<Prop id="prop_a" value="aaa=AAA;bbb=BBB;ccc=CCC;"/>
<Transmission id="testWebService" protocol="2" url_ref="url_c" prop_ref="prop_a"/>
```

フレームワークがこれを `Dictionary<string, string>` に展開して呼び出し側へ渡す
（`ProtocolNameService.NameResolutionProtocolUrl(name, out url, out timeout, out props)`）。

`prop_ref` で参照した `Prop` に `value` 属性が無いと `FrameworkException` になる。

## やってはいけないこと

- **`id` / `key` の先頭に数字を使う** — XML の `ID` 型なので不正。`E0001` のように英字で始める
- **DTD を省く** — 各ファイルは DTD を埋め込んだ形式。書式が検証される
- **例外の `Message` に完成した文を入れる（雛形を使うプロジェクトで）** — `%1` に埋める
  可変部分として使う。ただし置換するかは親クラス2 の実装次第
- **`%1` / `%2` を `GetMessage` が置換すると考える** — 置換するのは P層の親クラス2。
  しかも Web Forms のテンプレートにしか実装が無い
- **`TCDefinition` の `isolevel` に `IsolationLevelEnum` の名前を書く** — 2文字の略号
  （`rc` / `sz` など）
- **`SCDefinition` を Web Forms 以外で使おうとする** — 画面遷移制御は Web Forms 専用
- **これらの XML を `appsettings.json` に移そうとする** — ランタイムによらず XML のまま
