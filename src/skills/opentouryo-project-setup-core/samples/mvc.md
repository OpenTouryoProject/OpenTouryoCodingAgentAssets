# サンプル固有メモ：ASP.NET MVC（`Samples\WebApp_sample\MVC_Sample`・net48 / `Samples4NetCore\Backend\MVC_Sample`・core）

`opentouryo-project-setup-core` でこのサンプルを取り出すときの、**サンプル固有の癖**。
（WS/3層まわりの共通機構は `webservices.md`、HintPath の edge case は `references/reference-rewrite.md`。）

## ★ MVC(net48) も WS 依存＝(A)/(B) の判断が要る（#10）

**MVC(net48) は WebForms と同じく 3層構成で WS 依存を持つ**（実測）：`MVC_Sample.csproj` が
`WSIFType_sample` / `WSServer_sample` を **`..\..\..\WS_sample\Build\*.dll`（DLL 参照）**で参照する。
`WS_sample\Build\` は ZIP に無い生成物なので、**取り出し直後は WS 側型で `CS0246` になり得る**。
＝**WebForms と同様に (A) そのまま残す（ProjectReference 化）／(B) 切り離す**の判断が要る（共通手順・sln 追加・GUID 一致・
全 proj 確認は `webservices.md`）。「MVC は WS 無関係」ではない。

- (A) の場合：`WSIFType_sample`/`WSServer_sample` を ProjectReference 化＋`MVC_Sample.sln` に2プロジェクト追加（#1/#2）。
- (B) の場合：後工程 `opentouryo-project-transform`。

## MySql/Oracle の HintPath は「Frameworks 側」＝WebForms と割れる

同じ csproj の `MySql.Data`/`Oracle.ManagedDataAccess` の**元 HintPath は MVC(net48) では
`..\..\..\..\Frameworks\Infrastructure\Build\`**（WebForms は `WS_sample\Build\`）。**機械的な一括置換で外す**ので、
各 HintPath の実際の「元」を見てベンダ先へ張り替える（`references/reference-rewrite.md`）。

## MVC core（`Samples4NetCore\Backend\MVC_Sample`）＝WS 依存なし・SDK 形式

- **WS 依存なし**（3層でない）。SDK 形式で 3rd-party は `PackageReference`（`log4net` / `Microsoft.Data.SqlClient` /
  `Newtonsoft.Json`）＝触らない。`OpenTouryo.*` の HintPath だけベンダ先 `Build_netcore100\<TFM>\` へ（MVC core は `net10.0\`）。
- config は `appsettings.json`（**キー集合・綴り・スラッシュ区切り・JSONC が net48 と割れる**＝`opentouryo-project-setup-config` /
  `references/resource-config.md`。core の ⑥ は見落とされやすい）。

## 上流の残骸：`Views\Home\{About,Contact}.cshtml`（#9・develop）

`MVC_Sample.csproj`(net48/develop) は `Views\Home\About.cshtml` / `Contact.cshtml` を `<Content Include>` するが
**実ファイルが ZIP に無い**（参照するアクション・リンクも無い＝陳腐化した残骸）。`Content` なのでビルドは通るが、
VS で「見つからないファイル」表示になる。**④ の Include 突き合わせで検出できる**。
**セットアップでは構成変更しないので上流のまま残す**（除去は `opentouryo-project-transform` の領分。上流＝OpenTouryo 本体の課題）。
