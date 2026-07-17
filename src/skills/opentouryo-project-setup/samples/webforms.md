# サンプル固有メモ：Web Forms（`Samples\WebApp_sample\WebForms_Sample`・net48）

`opentouryo-project-setup` でこのサンプルを取り出すときの、**サンプル固有の癖**。
（サンプル別メモはこの `samples/` 配下に置く。内容が育ったら独立スキルへ昇格する。現状は WebForms のみ実測済み。）

## WS/3層依存 → 取り出し直後は `CS0246` が残る（解消は2通り）

`WebForms_Sample` は**3層構成**で、2層画面 `sampleScreen_cc.aspx.cs` が
**別サンプル `WS_sample` のビルド出力**（`WSIFType_sample` / `WSServer_sample`）の型に依存する。
参照 HintPath は `..\..\..\WS_sample\Build\...` を指す。**無いのはその「ビルド出力」だけで、
`WS_sample`（`WSIFType_sample` / `WSServer_sample`）のソースは同じ `WebApp_sample` 配下に実在する。**
取り出した直後は WS のビルド出力が無いので `CS0246`（型・名前空間が見つからない）が残る。用途で2通り：

**(A) 3層のまま通す（WS も取り出す）** ← 3層デモ（WCF/WS 越しの呼び出し）を動かしたいならこちら
（実ソースで確認済み。`WebForms_Sample.csproj` は `WSIFType_sample` / `WSServer_sample` を
`..\..\..\WS_sample\Build\*.dll` として参照し、`sampleScreen_cc.aspx.cs` は `using WSIFType_sample;`）
- 同じ `WebApp_sample` 配下の **`WS_sample\WSIFType_sample` と `WS_sample\WSServer_sample` を一緒に取り出す**。
  **`WSServer_sample` は `..\WSIFType_sample\WSIFType_sample.csproj` を ProjectReference する**ので、
  この相対配置（`WS_sample\` 直下に両フォルダ）を保って取り出す。
- 両プロジェクトの参照は **`OpenTouryo.Business` / `.Framework`（`WSServer` は `.Public` も）だけ**で、
  追加の 3rd-party サンプル依存は無い。**⑤と同じ要領で `OpenTouryo.*` の HintPath をベンダ先へ張り替えてビルド**する
  （元 HintPath は WebForms と同じ旧 `..\..\..\Frameworks\Infrastructure\Build\`）。
- **ビルド出力は `WS_sample\Build\` に落ちる**（`WSIFType_sample.dll` / `WSServer_sample.dll`。作者確認）。
  csproj の `OutputPath` は `bin\Release\` だが、実際の出力先 `WS_sample\Build\` は**外部のビルド スクリプト側**が決める
  （csproj の `AfterBuild` / `PostBuildEvent` は空）。**WebForms 側の参照 `..\..\..\WS_sample\Build\*.dll` は
  そのまま解決するので、HintPath の向け直しは不要**（WS を取り出してビルドすれば `CS0246` が消える）。
- WebForms が同じ `WS_sample\Build\` から参照する `MySql.Data.dll` / `Oracle.ManagedDataAccess.dll` は、
  ⑤のベンダ対象（`Build_net48\` 由来）と同じもの。WS ビルドで `Build\` に揃わなければ ⑤ の供給元から置く。
- `Web.config` の endpoint は**そのまま**（フレームワークの Transmission WCF 設定。`opentouryo-transmission` /
  transform 参照）。
- これは**セットアップの取り出し・参照張り替え（④⑤）の範囲**で完結する（transform は不要）。

**(B) 2層で使う（WS を切り離す）** ← WS/3層が不要ならこちら
- **後工程 `opentouryo-project-transform`** で WS 参照を外し、`using WSIFType_sample;` → `using MyType;`
  に差し替え、3層専用コードを削って `CS0246` を潰す（`Web.config` の endpoint は Transmission 設定なので**触らない**）。

**どちらを選ぶかは用途次第。** セットアップの到達点は「ソリューションが開ける状態」で、
(A)/(B) の選択と実施はソリューションを俯瞰してから決めてよい（as-is のクリーンビルドは保証しない）。

## config は二段構成（初見で `Web.config` を探して迷う）

net48 Web Forms は実効 config が `Web.config` だが、キーの所在が分かれる（⑥のパス張り替えで効く）：

| 種類 | 所在 |
| --- | --- |
| パス系キー（`Fx*` / `SqlTextFilePath` / `SpRp_RsaCerFilePath` 等） | **`app.config`**（`Web.config` の `<appSettings file="app.config"/>` で読み込まれる） |
| 接続文字列（`ConnectionString_*`） | **`Web.config` 直下**（`<connectionStrings>`） |

パス系キーの張り替えは `app.config` を開く（`Web.config` を眺めても見つからない）。
（.NET Core のサンプルはこの二段構成ではなく `appsettings.json` に集約される。）
