# ws-decouple — WS 依存の切り離し（俗称「2層化」）

`opentouryo-project-transform` の subcommand。**サンプルから WS（Web サービス）依存を外す。** 2層サンプル画面は残し、
3層画面と WS 参照を削る（「3層/2層」は呼び方の別で、判断軸は **WS 依存の有無**。core は通信制御を使ってもインプロセスのみ＝実質2層になり得る）。

一部サンプル（例：`WebForms_Sample`）は WS 依存があり、**他サンプルの B・D層/型**（`WSServer_sample` / `WSIFType_sample`。
(A) 構成では ProjectReference＝`opentouryo-project-setup` の `samples/webservices.md`）に依存する。WS が不要なら次を削る／直す。

## 削る

- 3層画面：`Aspx\sample\3Tier\`、`Aspx\start\menu.aspx` の3層リンク
- `WSIFType_sample` / `WSServer_sample` 参照（3層画面を消したうえで）
- 3層画面専用の周辺ソース：`AppCode\sample\3TierTableAdapter\ProductsTableAdapter.cs`、
  3層画面からのみ使う B層 `AppCode\sample\Business\GetMasterData.cs`

> **WS 参照は `WSIFType_sample` / `WSServer_sample` だけではない**（実測）。WebForms の csproj は
> **`MySql.Data.dll` / `Oracle.ManagedDataAccess.dll` も `WS_sample\Build\` を HintPath 参照**している。
> `WS_sample` ごと消して WS 依存を完全に断つなら、**この2つの HintPath をベンダ先
> （`OpenTouryoAssemblies\Build_net48\`）へ張り替える**（さもないと参照切れ。`opentouryo-project-setup-core` ⑤ /
> その `references/reference-rewrite.md` と同じ要領）。

> **`Web.config` の endpoint（`system.serviceModel`）は削らない。** このサンプルの endpoint は
> 3層固有（`WSServer_sample`）ではなく、**フレームワークの Transmission WCF 設定**
> （`IWCFHTTPSvcForFx` / `IWCFTCPSvcForFx`）と `IJSONService`。`WSServer_sample` は参照（(A)＝ProjectReference）で
> インプロセス呼び出しされ、専用 endpoint を持たない。消しても WS 依存の切り離しに不要なうえ、実行時構成を壊しかねない。

## 直す（見落としやすい罠）

**2層画面が WS 側（`WSIFType_sample`）の型を掴んでいることがある。** `sampleScreen_cc.aspx.cs` は
`using WSIFType_sample;` で `TestParameterValue` / `TestReturnValue` を **WS 側の参照から**解決している。
同名クラスがサンプル同梱ソース（`AppCode\sample\Common\`、`using MyType;`）にもあるので、
`using WSIFType_sample;` → `using MyType;` に差し替える。

## 確実な進め方

WS 参照（`WSIFType_sample` / `WSServer_sample`）を外してビルドし、**`CS0246` が出た箇所を上から潰す**。

- 同名クラスが同梱ソースにある → `using` を差し替える（上記の罠）
- 3層専用のコードだった → 削る

## 未収録：WebForms 以外のサンプル

現行手順は **`WebForms_Sample` 前提（裏取り済み）**。`MVC_Sample` も WS 依存を持つ（`MVC_Sample.csproj` が
`WSIFType_sample`/`WSServer_sample` を `..\..\..\WS_sample\Build\*.dll` へ HintPath 参照）が、
**参照形態が違う**（WebForms＝ProjectReference (A) / MVC＝DLL Reference (B)）ため、削り方・張り替え先が一部変わる。
＝**MVC は未収録**。来たら SKILL の「未収録の対象が来たら」に従い、**未収録と断ったうえで実ソースを裏取りしつつ段階ビルドでベストエフォート**する。
