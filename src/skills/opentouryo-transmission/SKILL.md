---
name: opentouryo-transmission
description: "OpenTouryo の通信制御機能を実装する。CallController.Invoke / InvokeAsync にサービス論理名を渡して B層を呼び出し、インプロセス呼び出しと Web サービス呼び出しを定義ファイルだけで切り替える仕組みを扱う。TMProtocolDefinition.xml（protocol / url / url_ref / timeout / prop_ref / Url / Prop）と TMInProcessDefinition.xml（assemblyName / className）の書式、ProtocolNameService / InProcessNameService による名前解決を扱う。リモート呼び出し（protocol=2、Web サービス / WCF）は BinarySerialize のドロップにより net48 専用で、net10.0（core）ではインプロセス（protocol=1）しか動かない点も扱う。通信制御 / サービス論理名 / CallController / インプロセス呼び出し / Web サービス呼び出し / 分散呼び出し / TMProtocolDefinition / TMInProcessDefinition を伴う作業のときに使う。他の XML 定義ファイルは opentouryo-message / opentouryo-shared-property / opentouryo-screen-transition / opentouryo-transaction-control を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 通信制御機能

## このスキルの適用範囲

サービス論理名による B層の呼び出しと、それを支える2つの定義ファイル
（`TMProtocolDefinition.xml` / `TMInProcessDefinition.xml`）。

**この2ファイルで1つの機能。** 片方だけでは成立しない。

他の XML 定義ファイルは機能ごとに別スキルへ分かれている（`opentouryo-message` /
`opentouryo-shared-property` / `opentouryo-screen-transition` /
`opentouryo-transaction-control`）。

**この2ファイルも他の XML 定義ファイルと共通の作法に従う。** DTD を埋め込み、`id` は XML の
`ID` 型なので先頭に数字を使えず、パスは `appSettings` の `Fx` キー
（`FxXMLTMProtocolDefinition` / `FxXMLTMInProcessDefinition`）で指定する。
**ランタイムによらず XML のまま。**

## 何のための機能か

**「サービス論理名」を渡すだけで B層を呼べるようにする。** 呼び出し先が同一プロセス内なのか
Web サービス越しなのかを、**呼び出し側のコードから隠す**。

```csharp
// P層から
CallController cctrl = new CallController(this.UserInfo);
TestReturnValue rv = (TestReturnValue)cctrl.Invoke("testWebService", parameterValue);
```

`Invoke("testWebService", ...)` の解決の流れ。

```
① TMProtocolDefinition.xml で "testWebService" の protocol を引く
     protocol="1" → インプロセス
     protocol="2" → Web サービス

② protocol="1" なら
     TMInProcessDefinition.xml で assemblyName / className を引いて直接呼ぶ
   protocol="2" なら
     TMProtocolDefinition.xml で url / timeout / props を引いて通信する
```

**同じ論理名のまま、定義ファイルを直すだけでインプロセス⇄Web サービスを切り替えられる。**
これがこの機能の目的。

`Invoke` の非同期版として `InvokeAsync(serviceName, parameterValue)` もある。

### リモート呼び出し（`protocol="2"`）は net48 専用

**`net10.0`（core）では、インプロセス（`protocol="1"`）しか動かない。**
Web サービス / WCF などのリモート呼び出し（`protocol="2"` 系）は**net48 のみ**。

理由：リモート呼び出しは `.NET` オブジェクトのバイナリ シリアライズ（`BinarySerialize`）で
引数・戻り値を転送するが、**`BinarySerialize` は core でドロップされた**（`opentouryo-common-parts`）。
`CallController` は core でもビルドされるが、リモート系プロトコルは**未実装（`Invoke` が `null` を返す）**。

core で物理3層が必要なら、別の通信手段（REST / gRPC など）を独自に実装する。

**サンプル/ランタイム選択への含意：`Samples4NetCore\Legacy\WS_sample\WSClient_sample\`（.NET Core 版の
WS クライアント）は、この制約により実質インプロセス呼び出ししか動かず、実用的な物理3層にならない
（起点として勧めない）。3層リッチクライアントを実用するなら net48 側**（`Samples\WS_sample\WSClient_sample\`）
**を選ぶ**（新規立ち上げのサンプル選択は `opentouryo-project-setup-selection` ①表を参照）。

## TMInProcessDefinition.xml（インプロセス呼び出しの名前解決）

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

## TMProtocolDefinition.xml（プロトコルの名前解決）

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

- **`CallController.Invoke()` に呼び出し先の URL やクラス名を渡す** — 渡すのはサービス論理名。
  実体の解決は定義ファイルが行う
- **`TMProtocolDefinition` だけ書いて `TMInProcessDefinition` を書かない** — 2ファイルで
  1つの機能。`protocol="1"`（インプロセス）の解決には後者が要る
- **`id` の先頭に数字を使う** — XML の `ID` 型なので不正
- **`prop_ref` で参照する `Prop` に `value` 属性を書かない** — `FrameworkException` になる
- **呼び出し側のコードでインプロセスか Web サービスかを分岐する** — 隠すのがこの機能の目的。
  切り替えは定義ファイルで行う
- **`net10.0`（core）でリモート呼び出し（`protocol="2"`）を使う** — 未実装で `Invoke` が
  `null` を返す。core で使えるのはインプロセス（`protocol="1"`）だけ
