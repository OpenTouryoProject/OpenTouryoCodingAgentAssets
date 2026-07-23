# 通信制御 コードスニペット（コピー元）

出典：UserGuide 各機能編 §6、`Framework/Transmission/*`・`CallController`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## サービス論理名で呼び出し（インプロセス⇄WebService をコード無変更で切替）

```csharp
CallController cctrl = new CallController(this.UserInfo);
// 任意オプション（実行時はこちらが優先）
// cctrl.ProxyUrl = "http://proxy/";
// cctrl.NetworkCredentialToProxy = new NetworkCredential("id","pw","domain");
// cctrl.NetworkCredentialToWAS   = new NetworkCredential("id","pw","domain");

TestReturnValue rv = (TestReturnValue)cctrl.Invoke("〈サービス論理名〉", pv);
// ErrorFlag 判定は opentouryo-p-call-business と同じ
```

> ★ リモート（protocol=2＝Web サービス）は **net48 専用**。net10.0 はインプロセス（protocol=1）のみ
> （`BinarySerialize` が core に無い）。

## 呼び出し先の名前解決（TMProtocolDefinition.xml）

`protocol`：`1`=インプロセス、`2`=ASP.NET Web Service。

```xml
<TMD>
  <Transmission id="testInProcess" protocol="1"/>
  <Transmission id="testWebSrv"    protocol="2" url="http://xxx/Service.asmx" timeout="60"/>
</TMD>
```

## 呼び出しモジュールの名前解決（TMInProcessDefinition.xml）

```xml
<TMD>
  <Transmission id="testInProcess" assemblyName="WSServer_sample"
    className="WSServer_sample.Business.LayerB" />
</TMD>
```

config パス（呼び出し先＝クライアント、呼び出しモジュール＝クライアント＋サーバに配置）：

```xml
<add key="FxXMLTMProtocolDefinition"  value="...\TMProtocolDefinition.xml"/>
<add key="FxXMLTMInProcessDefinition" value="...\TMInProcessDefinition.xml"/>
```

## サーバ側（サービスインターフェイス）

テンプレートは `Frameworks/Infrastructure/ServiceInterface/ASPNETWebService`（`FxController`）／WCF（`WCFTCPSvcForFx`）。
コンテキスト/引数の .NET オブジェクト化とサーバ側認証を実装する。3層 WS 構成の配置は `opentouryo-project-setup-core`（`samples/webservices.md`）。
