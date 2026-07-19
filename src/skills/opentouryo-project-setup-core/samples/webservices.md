# 共有メモ：WS/3層依存サンプルの取り出しとビルド

`opentouryo-project-setup-core` で「WS/3層依存あり」のサンプル（`WebForms_Sample` / `WS_sample\WSClient_sample`
一式 ほか）を取り出すときに**共通で効く機構**。サンプル固有の癖は `<サンプル>.md`（同 `samples/` 配下）、
ここは WS まわりの共通部分をまとめる（サンプルが増えても共有できる）。

## なぜ `CS0246` が残るか

WS/3層依存サンプルは、別サンプル **`WS_sample` のビルド出力**（`WSIFType_sample.dll` / `WSServer_sample.dll`）を
HintPath 参照する。`WS_sample` は **`Samples\WS_sample`**（`WebApp_sample` の**兄弟**）にソースが実在するが、
参照先のビルド出力 `WS_sample\Build\` は **ZIP に含まれない生成物**。だから取り出し直後は `CS0246` が残る。

- `WSIFType_sample` … 共有 DTO（インターフェース型。`TestParameterValue` / `TestReturnValue` 等）
- `WSServer_sample` … WS サーバ（B/D層）。`..\WSIFType_sample` を ProjectReference
- `WSClient_sample` … WS クライアント群（3層リッチクライアント。WinForms/WPF・net48）

解消は用途で2通り。

## (A) そのまま残す（WS も取り出してビルド・配置）

1. **取り出す** — `Samples\WS_sample\WSIFType_sample` と `WSServer_sample` を、`WS_sample\` 直下の相対配置を
   保って取り出す（`WSServer` は `..\WSIFType_sample` を ProjectReference）。WS クライアントが起点なら
   `WSClient_sample` も。
2. **参照張り替え** — 両者の参照は `OpenTouryo.Business` / `.Framework`（`WSServer` は `.Public` も）だけ
   （追加の 3rd-party サンプル依存は無い）。⑤と同じ要領で `OpenTouryo.*` の HintPath をベンダ先へ
   （`…\Frameworks\Infrastructure\Build\` → `…\OpenTouryoAssemblies\Build_net48\`。**末尾フォルダ名も変わる**）。
3. **ビルド → `Build\` へ配置（★ここが要）** — `msbuild WSServer_sample.sln` の出力は各 **`bin\Debug\`**。
   `WS_sample\Build\` は**本体の外部ビルド スクリプトが作る場所**で、`.sln` 直ビルドでは生成されない
   （csproj の `AfterBuild` / `PostBuildEvent` は空）。参照側 HintPath は `WS_sample\Build\*.dll` のままでよいので、
   **ビルド後に `bin\Debug\WSIFType_sample.dll` / `WSServer_sample.dll` を `WS_sample\Build\` へコピー**する。
   併せて `MySql.Data.dll` / `Oracle.ManagedDataAccess.dll` をベンダ先（`Build_net48\`）から `WS_sample\Build\` へ置く。
   このコピーは**スクリプト化**する。
4. **endpoint は触らない** — `Web.config` / `app.config` の endpoint はフレームワークの Transmission WCF 設定
   （`opentouryo-transmission`）。3層固有ではないので消さない。

→ 取り出し・参照張り替え・配置＝**セットアップ（④⑤）の範囲で完結**（transform 不要）。
実機で通した参考スクリプトは `opentouryo-project-setup-build` の `examples.md`（`build-app.ps1`）。

## (B) WS 依存を切り離す

WS 依存が不要なら、後工程 **`opentouryo-project-transform`** で WS 参照を外し `CS0246` を潰す。
画面が WS 側の型を `using` しているケースの差し替え等は**サンプル固有**（`<サンプル>.md`（同 `samples/` 配下） / transform）。

## ランタイム注意：core のリモート WS は実用不可

.NET Core では **`BinaryFormatter` が廃止**され、リモート WS 呼び出し（`protocol="2"`）は実質動かない
（インプロセスのみ）。**3層リッチクライアント（`WSClient_sample`）を実用するなら net48 側**を使う。
core 版 `Samples4NetCore\Legacy\WS_sample\WSClient_sample\` は起点として勧めない（`opentouryo-transmission` / §4.4）。

## WSClient_sample（クライアント側）の取り出し＝以下で決め打つ（判断させない）

3層リッチクライアント `WS_sample\WSClient_sample\<WSClientWin/WPF/Win2/WinCone>_sample`（net48）は、
毎回の判断を避けて**次を固定手順**とする（実測：WSClientWin_sample・タグ 03-20 でクリーンビルド 0 error）。

1. **配置＝フラット化しない。元の階層 `WS_sample\WSClient_sample\<派生>\` を維持する**（下の MAX_PATH 節の
   フラット化は WSClient には適用しない）。理由：WSServer/WSIFType の DLL を `..\..\Build\`（＝`WS_sample\Build\`）で
   参照するため、フラット化するとこの相対参照が壊れる。MAX_PATH が問題なら**フラット化ではなく `long path` 有効化**で回避。
2. **⑤ 参照張り替えは2系統だけ**：
   - `OpenTouryo.*`（Business/Business.RichClient/Framework/Framework.RichClient/Public）＋ `Newtonsoft.Json` の
     HintPath を、元 `..\..\..\..\Frameworks\Infrastructure\Build\` → **`..\..\..\OpenTouryoAssemblies\Build_net48\`**
     に張り替える（3階層深い配置なので `..\..\..\`）。
   - `WSIFType_sample` / `WSServer_sample` の HintPath **`..\..\Build\` はそのまま維持**（張り替えない）。
3. **`.sln` は単一プロジェクトの `<派生>_sample.sln` を使い、`<派生>_sample_all.sln` は削除する**。`_all.sln` は
   `..\..\..\..\Frameworks\Infrastructure\ServiceInterface\WCFService` / `ASPNETWebService` の**ソース プロジェクトを参照**
   する（DLL 参照方針では存在しない＝そのままでは開けない・ビルドできない）。DLL 参照で完結する単一 `.sln` を残す。
4. **⑥⑦ config は2キーだけ `%OT_RESOURCE_ROOT%` 化**：`SqlTextFilePath`（→`%OT_RESOURCE_ROOT%\Sql`）と
   `SpRp_RsaCerFilePath`（→`%OT_RESOURCE_ROOT%\X509\SHA256RSA_Server.cer`）。**`FxXML*`（XML 定義）は張り替え不要**
   （csproj で `EmbeddedResource` 化され、ファイル名指定＝パス参照ではない）。詳細は `references/resource-config.md`。
5. **到達点は「開ける・ビルドが通る」まで**。実際に WS モード（`protocol="2"`）で動かすには WS ホスト
   （ASPNETWebService/IIS）の別途起動が要るが**セットアップ範囲外**（クライアントはインプロセス兼用）。
   検証は exe 生成＋起動生存まで（`references/run-verify.md` デスクトップ節）。

## MAX_PATH(260)

深いリポ パスでは、相対配置を保つと `nuget restore` がパッケージ内部の深いパス
（`packages\...\analyzers\...\pt-BR\...`）で超過し失敗する。**取り出したプロジェクト**（`WebForms_Sample` /
`WS_sample` 等）**をリポ直下へフラット化**し、各 `.csproj` の相対 `HintPath`（`OpenTouryo.*`・WS 参照・
`WS_sample\Build\` 参照）を新配置に合わせて張り替える（`long path` 有効化でも可）。
**※ WSClient_sample は例外＝フラット化しない**（上節1。`..\..\Build\` 参照を保つため `long path` 側で回避）。
