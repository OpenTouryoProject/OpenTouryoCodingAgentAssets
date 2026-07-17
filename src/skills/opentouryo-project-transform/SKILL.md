---
name: opentouryo-project-transform
description: "OpenTouryo プロジェクトをセットアップ後に用途へ合わせて変形（リストラクチャ）する後工程。取り出したサンプルから不要な層を削る（例：3層構成サンプルを2層で使う＝3層画面・WCF エンドポイント・他サンプル参照の除去）、サンプル固有コードの整理と、それに伴うビルドエラー（CS0246 等）の解消を扱う。ソリューションを開いて全体を俯瞰したうえで行う。取得・ビルド・参照張り替え・config でソリューションを開ける状態にするのは opentouryo-project-setup、既存構成の上で新規に業務コードを書くのは各層スキル（opentouryo-layer-* ほか）。2層化 / 3層を削る / 不要な層の削減 / サンプルの整理 / 変形 / リストラクチャ / CS0246 を伴う作業のときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# プロジェクトの変形（セットアップ後のリストラクチャ）

<!-- 執筆者メモ（Claude Code は読み込み時に除去）：
     現状は「3層→2層」ケースだけを収録した first-cut。将来の変形（認証方式の差し替え 等）は
     節を足して育てる。
     ※ net48↔core はランタイム別サンプル（Samples / Samples4NetCore）で対応する＝サンプル選択
       （opentouryo-project-setup）の領分なので、このスキルの対象外。
     セットアップから外した詳細手順（DevelopmentHistory §4.3 の3層行）が出所。 -->

## このスキルの適用範囲

セットアップで取り出したサンプルを、**用途に合わせて構成を削る／変える**とき。

**実行タイミングは選択式（任意）。** どちらでもよい:

- **セットアップ直後に続けて実行**（`opentouryo-project-setup` 完了後の任意ステップ。早くフィードバックを得たいとき）
- **後で別途依頼**（利用者がソリューションを俯瞰してから）

いずれも**利用者主導**で行う。セットアップの途中に割り込ませるのではなく、開ける状態に達した後に選ぶ。

- ゼロから開ける状態にする（取得・ビルド・参照張り替え・config）→ `opentouryo-project-setup`
- 既存構成の上で新規に業務コードを書く → 各層スキル（`opentouryo-layer-*` ほか）

**セットアップとは責務が別。** セットアップは「開ける状態」まで。ここは「開いた後、要らないものを削る」。

## 基本方針

- **まずビルドして現状を把握**してから削る。何が何に依存しているかはビルドエラーが教えてくれる。
- **段階的に**：一気に消さず、`削る → 再ビルド → CS0246（型・名前空間が見つからない）等を潰す` を繰り返す。
- **基盤（`Frameworks/Infrastructure/*` / `OpenTouryo.*` DLL）には触らない**（`opentouryo-project-policy`）。
  変形の対象は**サンプル由来の業務コード側だけ**。

## 3層構成サンプルを2層で使う（2層化）

一部サンプル（例：`WebForms_Sample`）は3層構成で、**ZIP に無い他サンプルのビルド出力**
（`WSServer_sample.dll` / `WSIFType_sample.dll`）や WCF エンドポイントに依存する。
2層で使うなら次を削る／直す。

### 削る

- 3層画面：`Aspx\sample\3Tier\`、`Aspx\start\menu.aspx` の3層リンク
- `WSIFType_sample` / `WSServer_sample` 参照（3層画面を消したうえで）
- 3層画面専用の周辺ソース：`AppCode\sample\3TierTableAdapter\ProductsTableAdapter.cs`、
  3層画面からのみ使う B層 `AppCode\sample\Business\GetMasterData.cs`

> **`Web.config` の endpoint（`system.serviceModel`）は削らない。** このサンプルの endpoint は
> 3層固有（`WSServer_sample`）ではなく、**フレームワークの Transmission WCF 設定**
> （`IWCFHTTPSvcForFx` / `IWCFTCPSvcForFx`）と `IJSONService`。`WSServer_sample` は DLL 参照で
> インプロセス呼び出しされ、専用 endpoint を持たない。消しても2層化に不要なうえ、実行時構成を壊しかねない。

### 直す（見落としやすい罠）

**2層画面が WS 側 DLL の型を掴んでいることがある。** `sampleScreen_cc.aspx.cs` は
`using WSIFType_sample;` で `TestParameterValue` / `TestReturnValue` を **WS の DLL から**解決している。
同名クラスがサンプル同梱ソース（`AppCode\sample\Common\`、`using MyType;`）にもあるので、
`using WSIFType_sample;` → `using MyType;` に差し替える。

### 確実な進め方

WS 参照（`WSIFType_sample` / `WSServer_sample`）を外してビルドし、**`CS0246` が出た箇所を上から潰す**。

- 同名クラスが同梱ソースにある → `using` を差し替える（上記の罠）
- 3層専用のコードだった → 削る

## やってはいけないこと

- **基盤（`OpenTouryo.*` / `Frameworks/Infrastructure/*`）を改造して辻褄を合わせる** — 纏め者の領分。
  変形はサンプル由来コード側で行う（`opentouryo-project-policy`）
- **セットアップ（取得・ビルド・参照・config）をここでやり直す** — それは `opentouryo-project-setup`
- **一括で大量に削ってからまとめてビルド** — 依存を見失う。段階的に削って都度ビルドする
