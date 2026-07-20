# 共有メモ：WS/3層依存サンプルの取り出しとビルド

`opentouryo-project-setup-core` で「WS/3層依存あり」のサンプル（`WebForms_Sample` / `WS_sample\WSClient_sample`
一式 ほか）を取り出すときに**共通で効く機構**。サンプル固有の癖は `<サンプル>.md`（同 `samples/` 配下）、
ここは WS まわりの共通部分をまとめる（サンプルが増えても共有できる）。

## なぜ `CS0246` が残るか／どう解消するか

WS/3層依存サンプルは、別サンプル **`WS_sample` の `WSIFType_sample` / `WSServer_sample`** を参照する。ソースでは
`WS_sample\Build\*.dll` への **HintPath（DLL 参照）**だが、`WS_sample\Build\` は **ZIP に含まれない生成物**なので
取り出し直後は `CS0246`。**解消は DLL を供給するのではなく、この2つを ProjectReference に切り替える**（下の原則）。

- `WSIFType_sample` … 受け渡し型（DTO。`TestParameterValue` / `TestReturnValue` 等）
- `WSServer_sample` … **B・D層**（WS サーバ）。`..\WSIFType_sample` を ProjectReference
- `WSClient_sample` … クライアント群（**P層**＝3層リッチクライアント。WinForms/WPF・net48）

## ★ 参照方式の使い分け（この節の中心・決め打ち）

3層CS は2種類の参照を明確に使い分ける：

- **フレームワーク `OpenTouryo.*`（親クラス＝バイナリ提供）→ DLL 参照**（ベンダ先 `OpenTouryoAssemblies\Build_net48\`）。
- **サンプル自身の `WSServer_sample`（B・D層）と `WSIFType_sample`（受け渡し型）→ ProjectReference**。
  理由：これらは導入プロジェクトで **P・B・D 層を並行開発する対象**（型と業務ロジックを触りながら P 層＝クライアントを作る）。
  DLL 参照だと編集のたびにビルド＆コピーが要り並行開発にならない。ProjectReference なら**同一ソリューションで編集が即伝播**する。
- → **`WS_sample\Build\` への DLL コピー＆その HintPath 参照は廃止**（旧 (A) の copy-to-Build 手順は不要）。

## (A) WS も一式取り出して 1 ソリューションで並行開発する

1. **取り出す** — `Samples\WS_sample\WSIFType_sample` と `WSServer_sample` を `WS_sample\` 直下の相対配置を保って取り出す
   （`WSServer` は `..\WSIFType_sample` を ProjectReference＝元からそう）。クライアント/ホストが起点なら合わせて取り出す。
2. **サンプル間は ProjectReference にする**（DLL 参照からの切替）：
   - **クライアント → `WSServer_sample`・`WSIFType_sample`**：旧 `..\..\Build\*.dll` の `<Reference>`+HintPath を**削除**し、
     各 `.csproj`（`..\..\WSServer_sample\WSServer_sample.csproj` 等）への `<ProjectReference>` にする。
   - **WS ホスト（ASPNETWebService/WCFService）→ 同2つ**：旧 `...\Samples\WS_sample\Build\*.dll` を**削除**し ProjectReference に。
   - `WSServer_sample → WSIFType_sample` は既定で ProjectReference（触らない）。
3. **各プロジェクトの `OpenTouryo.*` は DLL 参照のままベンダ先へ張り替える**（`…\Frameworks\Infrastructure\Build\` →
   `…\OpenTouryoAssemblies\Build_net48\`。末尾フォルダ名も変わる。深さは配置に合わせる）。
4. **endpoint は触らない** — `Web.config`/`app.config` の endpoint はフレームワークの Transmission 設定（`opentouryo-transmission`）。

→ 取り出し・参照切替＝**セットアップ（④⑤）の範囲で完結**（transform 不要。`WS_sample\Build\` へのコピーは不要になった）。
参考スクリプトは `opentouryo-project-setup-build` の `examples.md`（`build-app.ps1`）。

## (B) WS 依存を切り離す

WS 依存が不要なら、後工程 **`opentouryo-project-transform`** で WS 参照を外し `CS0246` を潰す。
画面が WS 側の型を `using` しているケースの差し替え等は**サンプル固有**（`<サンプル>.md`（同 `samples/` 配下） / transform）。

## ランタイム注意：core のリモート WS は実用不可

.NET Core では **`BinaryFormatter` が廃止**され、リモート WS 呼び出し（`protocol="2"`）は実質動かない
（インプロセスのみ）。**3層リッチクライアント（`WSClient_sample`）を実用するなら net48 側**を使う。
core 版 `Samples4NetCore\Legacy\WS_sample\WSClient_sample\` は起点として勧めない（`opentouryo-transmission` / §4.4）。

## 3層CS（WSClient）＝まず csproj を見て「3層WSクライアントか単独 P層か」判定する

**`WSClient_sample\` 配下でも variant ごとに依存構造が違う。名前（Win/WPF/Win2/WinCone）で決め打ちせず、必ず対象
variant の csproj を見て分岐する**（実測：Win/WPF/WinCone は WS 依存あり、Win2 は WS 依存なし）：

- **判定基準**：csproj に `WSServer_sample`/`WSIFType_sample` への参照があるか、`.cs` に WS 型（`TestParameterValue` /
  `TestReturnValue`）や `using WSIFType_sample;` があるか。加えて `<派生>_sample_all.sln` が同梱されているか。
- **あり → 3層WSクライアント**：下記の **① クライアント ② `WSServer_sample`/`WSIFType_sample`（B・D層・型） ③ WS ホスト
  `WS_sample\ServiceInterface`（源＝`Frameworks\Infrastructure\ServiceInterface`）** の3点を一式引き込む（クライアント単体では通信相手が居ない）。
- **なし → 単独の P層 UI デモ**（例：`WSClientWin2_sample`＝UserControl 親子・フォーム間の戻り値受け渡し等）：**WS ホスト
  引き込みも ProjectReference 化も不要。源同梱の単一 `.sln` のまま `OpenTouryo.*` の DLL 参照だけ張り替えて完結**。
  config も app.config に絶対 resource パスが無ければ張替不要（Win2 は該当キー無し・ローカル Content の XML は出力コピー）。
  ※ただし `Business.RichClient` は参照するので ③ の RichClient 追加ビルドは要る（**WS 軸と RichClient 軸は別**）。
  **★ 配置は例外にしない**：WS 非依存でも Win2 も他 variant と同じく **`WS_sample\WSClient_sample\WSClientWin2_sample\`** に置く
  （源の階層維持＝リポ直下に出さない）。WS 非依存なのは「参照の張替」の話で、置き場所は WSClient 派生と一律。よって
  `OpenTouryo.*` の HintPath は他 variant と同じ **3階層 `..\..\..\OpenTouryoAssemblies\Build_net48\`**（トップ直下＝`..\` にしない）。

**★ WSClient 4 variant の実測表（タグ 03-20・4種すべて実ビルド済み。依存形は3種＝名前で決め打ち不可の決定版）**：

| variant | client の WS 参照 | config 絶対パスキー | 構成 | 特記 |
| --- | --- | --- | --- | --- |
| `WSClientWin_sample` | WSServer＋WSIFType | 2（`SqlTextFilePath`＋`SpRp_RsaCerFilePath`） | 5proj | — |
| `WSClientWPF_sample` | WSServer＋WSIFType | 1（`SqlTextFilePath`） | 5proj | — |
| `WSClientWinCone_sample` | **WSIFType のみ**（WSServer は client 非参照） | 1（`SpRp_RsaCerFilePath`） | 5proj | **ClickOnce＝署名で MSB3482→下記** |
| `WSClientWin2_sample` | なし（WS 非依存） | 0 | 単一 sln | 単独 P層 UI デモ |

以下は「3層WSクライアント」（上表の 5proj 側＝Win/WPF/WinCone）の手順。②の取り出しとサンプル間 ProjectReference 化は
上の (A) 節、①③は下記。**client が参照する WS プロジェクトは variant による**（Win/WPF＝WSServer＋WSIFType、
WinCone＝WSIFType のみ）＝csproj を見て張り替える。

### ① クライアント（WSClientWin/WPF/WinCone）
1. **配置**：`WS_sample\` をリポ直下に置き（他サンプル同様 `Samples\` 段は落とす）、**`WS_sample\` の内部階層
   （`WSClient_sample\<派生>\`・`WSIFType_sample`・`WSServer_sample`）は保つ**（内部をフラット化しない＝サンプル間
   `ProjectReference` の相対パスを保つため。MAX_PATH は `long path` で回避）。**結果、client はリポ直下から3階層**。
   ★ **`Samples\` 段を落とすと `_all.sln` のホスト参照がずれる**（源は `Samples\` 前提）→ 下の ③「引き込み位置」で調整。
2. **⑤ 参照は2種類**：`OpenTouryo.*`（Business/Business.RichClient/Framework/Framework.RichClient/Public）＋`Newtonsoft.Json`
   は **DLL 参照**で 元 `..\..\..\..\Frameworks\Infrastructure\Build\` → **`..\..\..\OpenTouryoAssemblies\Build_net48\`**（3階層）。
   **client が参照する WS プロジェクト（上表）を ProjectReference**（旧 `..\..\Build\*.dll` の DLL 参照を削除し `.csproj` へ。(A)2）。
3. **⑥⑦ config は app.config に絶対 resource パスが在るキーだけを** `%OT_RESOURCE_ROOT%` 化する（**「2キー決め打ち」は誤り
   ＝variant で全部違う**。実測4/4：Win=2〔`SqlTextFilePath`＋`SpRp_RsaCerFilePath`〕・WPF=1〔`SqlTextFilePath`〕・
   WinCone=1〔`SpRp_RsaCerFilePath`〕・Win2=0。app.config を見て在るものだけ張り替える）。張替先は
   `SqlTextFilePath`→`%OT_RESOURCE_ROOT%\Sql`・`SpRp_RsaCerFilePath`→`%OT_RESOURCE_ROOT%\X509\SHA256RSA_Server.cer`。
   **`FxXML*`（XML 定義）は `EmbeddedResource`＝張替不要**。

### ③ WS ホスト `WS_sample\ServiceInterface`（源＝`Frameworks\Infrastructure\ServiceInterface`）も引き込む（実動の必須要素・見落とし注意）
**これが無いとクライアントは通信相手が居ない。** 源は `Frameworks\Infrastructure\ServiceInterface` だが、**WS 一式を `WS_sample\`
配下に集約**するため **`WS_sample\ServiceInterface\` に置く**（`WSClient_sample`/`WSIFType_sample`/`WSServer_sample` と兄弟）。
これはフレームワーク*ライブラリ*の改造ではない（WS ホスト アプリを配置・起動するだけ＝「Frameworks を取り込んで改造しない」に当たらない）。
- **既定は `ASPNETWebService`**（クライアント app.config が `FxXMLTMProtocolDefinition=TMProtocolDefinition2.xml`＝Web API
  経路を選択。`WCFService` は代替＝`TMProtocolDefinition.xml`）。通常は ASPNETWebService を建てれば足りる。
- **引き込み位置**：`WS_sample\ServiceInterface\<host>\`（`<host>`＝`ASPNETWebService`/`WCFService`）。
- **★ `_all.sln` のホスト参照を新配置に張り替える**。源の `_all.sln` は client から `..\..\..\..\Frameworks\...\ServiceInterface\<host>\`
  を参照するので、**`..\..\ServiceInterface\<host>\<host>.csproj` に直す**（client＝`WS_sample\WSClient_sample\<派生>\` から
  `WS_sample\` へ up 2＝host と client は `WS_sample\` 内の兄弟）。
- **参照**：ホストの `OpenTouryo.*`（ASPNETWebService＝Framework/Public/Public.Security、WCFService＝Business/Framework/Public）は
  **DLL 参照**で `..\..\Build\` → ベンダ先 **`..\..\..\OpenTouryoAssemblies\Build_net48\`**（host は `WS_sample\ServiceInterface\<host>\`
  ＝リポ直下から3階層）。**`WSServer_sample`/`WSIFType_sample` は ProjectReference**：旧 `...\WS_sample\Build\*.dll` を削除し
  **`..\..\WSServer_sample\WSServer_sample.csproj`（同 `WSIFType_sample`）**（host は `WS_sample\` 内なので client と同じ `..\..\`）。
- **★ ホスト config も resource パスを張り替える**（実 WS 稼働に必要。build だけなら不要・run-verify で要る）：
  `ASPNETWebService`/`WCFService` の **`app.config`** に `C:\root\files\resource\...` が**6キー**（`FxXMLMSGDefinition` /
  `FxXMLTCDefinition` / `FxXMLTMInProcessDefinition` / `FxLog4NetConfFile` / `SqlTextFilePath` / `SpRp_RsaCerFilePath`）＝
  `%OT_RESOURCE_ROOT%\...` 化する。**ASPNETWebService は `Web.config` の `<appSettings file="app.config">` で app.config を
  実行時マージ**（`Web.config` だけ見ると絶対パスが無く見落とす）。綴りは ASPNETWebService=`Xml`／WCFService=`XML`（`resource-config.md` の綴り罠）。
- **復元**：`WCFService` は `PackageReference`＝`msbuild /t:Restore`。**`ASPNETWebService` は `packages.config`＝要注意**：
  `_all.sln` 一括 `nuget restore` はパッケージをソリューション ディレクトリ（client 側）に入れるが、`ASPNETWebService.csproj`
  の HintPath / `.targets` インポートは **csproj 相対 `packages\...`**（`Microsoft.Data.SqlClient.SNI.targets` 等）。
  → **`nuget restore <asp>\packages.config -PackagesDirectory <asp>\packages` で project 直下へ別途復元**する（実測。
  さもないと `.targets` 不明でビルド失敗）。
- **`.sln`＝3層一式の `_all.sln`。ただし源の `_all.sln` は全 variant で client＋WCFService＋ASPNETWebService の3プロジェクトのみ**
  （WSServer/WSIFType を含まず・client 側は `..\..\Build\*.dll` の DLL 参照）＝**ProjectReference 化には WSServer/WSIFType の
  2プロジェクト追加が必須**。さらに **`SolutionConfigurationPlatforms` が variant で違う**（実測：Win/WinCone＝8種
  〔Debug/Release × .NET/Any CPU/Mixed/x86〕、WPF＝4種〔Debug/Release × Any CPU/x86〕）。
  → **推奨手順：既に動く 5プロジェクトの `_all.sln`（repo 内の別 WS client）を雛形にコピーし、client の project 行
  （名前・パス・GUID）だけ差し替える**（共有4プロジェクト＝WCFService/ASPNETWebService/WSServer/WSIFType は GUID・パスを
  そのまま流用）。**最初の WS client で雛形が無いときだけ**、源の3プロジェクト `_all.sln` に WSServer/WSIFType を追加＋client の
  DLL 参照を ProjectReference 化する（追加行は既存インデント＝タブに合わせる）。※先の版で「`_all.sln` 削除・単一 sln」としたのは誤り。

### ★ ClickOnce variant（`WSClientWinCone_sample`）＝署名で `MSB3482` になる
WinCone は ClickOnce デプロイ版（"Cone"）で csproj に **`SignManifests=true`＋`ManifestCertificateThumbprint`＋`ManifestKeyFile`
（`.pfx`）＋`GenerateManifests=true`** を持つ。素の `msbuild /t:Build` は**マニフェスト署名**が走り、証明書がローカル ストアに
無いと **`MSB3482`（No certificates were found）でビルド失敗**（他4プロジェクトは署名前に成功）。
- **回避＝csproj の `<SignManifests>` を `false` にする**（到達点は「ビルド/オープン可能」＝ClickOnce publish は目的外）。
  **repo 内 csproj の変更のみ＝マシン全体の変更ではない**（`SETUP-CHANGES.md` 追記は不要）。
- **ClickOnce 固有ファイルも取り出す**：`<派生>_TemporaryKey.pfx`・`Properties\app.manifest`（`BaseApplicationManifest`）。
  漏れると別エラー（④ の Include 突き合わせで拾う）。

### 到達点
- **セットアップの到達点＝5プロジェクトが開けて 0 error でビルドできる**（クライアント〔P〕＋WSServer〔B・D〕＋WSIFType〔型〕
  ＋WS ホスト ASPNETWebService/WCFService。P・B・D を1ソリューションで並行開発できる状態）。
- **WS モード（`protocol="2"`）実動の確認は run-verify**：ASPNETWebService を IIS Express で起動 → クライアント exe から
  WS 越しに呼べること（`references/run-verify.md`）。ホスト未起動でもクライアントはインプロセス兼用で開ける。

## MAX_PATH(260)

深いリポ パスでは、相対配置を保つと `nuget restore` がパッケージ内部の深いパス
（`packages\...\analyzers\...\pt-BR\...`）で超過し失敗する。**取り出したプロジェクト**（`WebForms_Sample` 等）
**をリポ直下へフラット化**し、各 `.csproj` の相対 `HintPath`（`OpenTouryo.*` 等）を新配置に合わせて張り替える
（`long path` 有効化でも可）。
**※ WS 系（`WS_sample\` 一式）は例外＝フラット化しない**（上の①1。サンプル間 ProjectReference の相対パスを保つため
`long path` 側で回避）。
