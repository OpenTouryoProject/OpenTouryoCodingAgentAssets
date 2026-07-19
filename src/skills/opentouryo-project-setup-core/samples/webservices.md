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

## 3層CS（WSClient）＝クライアント＋WS ホストをセットで引き込む（決め打ち・判断させない）

3層リッチクライアント `WS_sample\WSClient_sample\<WSClientWin/WPF/Win2/WinCone>_sample`（net48）は、
**クライアント単体では通信相手が居らず 3層として動かない**。実動に要る3点を一式引き込む（実測：WSClientWin_sample・
タグ 03-20）：**① クライアント ② 業務ロジック `WSServer_sample`/`WSIFType_sample` ③ WS ホスト
`Frameworks\Infrastructure\ServiceInterface`**。②の取り出しとサンプル間 ProjectReference 化は上の (A) 節、①③は下記。

### ① クライアント（WSClientWin/WPF/…）
1. **配置＝フラット化しない。**元階層 `WS_sample\WSClient_sample\<派生>\` を維持（`WSServer_sample`/`WSIFType_sample` への
   **ProjectReference の相対パス**を保つため。MAX_PATH は `long path` で回避＝フラット化しない）。
2. **⑤ 参照は2種類**：`OpenTouryo.*`（Business/Business.RichClient/Framework/Framework.RichClient/Public）＋`Newtonsoft.Json`
   は **DLL 参照**で 元 `..\..\..\..\Frameworks\Infrastructure\Build\` → **`..\..\..\OpenTouryoAssemblies\Build_net48\`**（3階層）。
   **`WSServer_sample`/`WSIFType_sample` は ProjectReference**（旧 `..\..\Build\*.dll` の DLL 参照を削除し `.csproj` へ。(A)2）。
3. **⑥⑦ config は2キーだけ** `%OT_RESOURCE_ROOT%` 化：`SqlTextFilePath`→`%OT_RESOURCE_ROOT%\Sql`、
   `SpRp_RsaCerFilePath`→`%OT_RESOURCE_ROOT%\X509\SHA256RSA_Server.cer`。**`FxXML*`（XML 定義）は `EmbeddedResource`＝張替不要**。

### ③ WS ホスト `Frameworks\Infrastructure\ServiceInterface` も引き込む（実動の必須要素・見落とし注意）
**これが無いとクライアントは通信相手が居ない。**`ServiceInterface` 配下の**ホスト アプリ**を引き込んで建てる。これは
フレームワーク*ライブラリ*の改造ではない（配置・起動するだけ＝「Frameworks を取り込んで改造しない」禁止には当たらない）。
- **既定は `ASPNETWebService`**（クライアント app.config が `FxXMLTMProtocolDefinition=TMProtocolDefinition2.xml`＝Web API
  経路を選択。`WCFService` は代替＝`TMProtocolDefinition.xml`）。通常は ASPNETWebService を建てれば足りる。
- **引き込み位置**：`_all.sln` は client から `..\..\..\..\Frameworks\Infrastructure\ServiceInterface\` を参照するので、
  **`Frameworks\Infrastructure\ServiceInterface\` の相対位置を保って引き込む**（保てば `_all.sln` の参照はそのまま解決）。
- **参照**：ホストの `OpenTouryo.*`（ASPNETWebService＝Framework/Public/Public.Security、WCFService＝Business/Framework/Public）は
  **DLL 参照**で `..\..\Build\` → ベンダ先 `OpenTouryoAssemblies\Build_net48\`（深さは配置に合わせる）。
  **`WSServer_sample`/`WSIFType_sample` は ProjectReference**（旧 `...\Samples\WS_sample\Build\*.dll` を削除し `.csproj` へ。(A)2）。
- **復元**：`ASPNETWebService` は `packages.config`＝`nuget restore`、`WCFService` は `PackageReference`＝`msbuild /t:Restore`。
- **`.sln` は 3層一式の `<派生>_sample_all.sln` を使う**（client＋WCFService＋ASPNETWebService。**ProjectReference のため
  `WSIFType_sample`・`WSServer_sample` も同ソリューションに含める**＝無ければ追加）。※先の版で「`_all.sln` 削除・単一 sln」
  としたのは誤り。ServiceInterface を引き込めば `_all.sln` の参照は解決する。

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
