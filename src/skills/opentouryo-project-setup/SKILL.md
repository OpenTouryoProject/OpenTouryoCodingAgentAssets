---
name: opentouryo-project-setup
description: "OpenTouryo を使う新規プロジェクトをゼロから立ち上げる（セットアップ）。作りたいものに合うサンプルを選び、OpenTouryo を GitHub から ZIP 取得（固定タグ または develop をユーザに選ばせる）、基盤をローカルビルドして OpenTouryoAssemblies\\ へベンダ、対象サンプルを新規リポジトリへ取り出し、.csproj の OpenTouryo.* 参照の HintPath を張り替え、root/files/resource をリポジトリ直下へコピーして config のパスを張り替える、までを扱う。Download→Build→ベンダはセットアップ スクリプトを生成して実行する。net48 / .NET 10.0 の両対応。プロジェクト作成 / セットアップ / 新規立ち上げ / サンプルから始める / 参照設定 / DLL 参照 / OpenTouryoAssemblies / ビルド を伴う作業のときに使う。既存プロジェクトでコードを書くのは各層スキル、構成の詳細は opentouryo-config を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 新規プロジェクトのセットアップ

## このスキルの適用範囲

**ゼロから新規に OpenTouryo アプリを立ち上げる**とき。OpenTouryo のサンプルを起点に、
基盤 DLL を参照する標準構成のプロジェクトを作る。

- 既存プロジェクトでコードを書く → 各層スキル（`opentouryo-layer-*` / `opentouryo-p-*` ほか）
- 構成ファイル・設定キーの詳細 → `opentouryo-config`

**両ランタイム対応**（.NET Framework 4.8 / .NET 10.0）。エージェントが全工程を実行する。

## 全体の流れ（7ステップ）

```
① 作りたいもの → 取り出すサンプルを選ぶ
② 取得元（固定タグ / develop）をユーザに選ばせる
③ セットアップ スクリプトを生成して実行（ZIP取得 → 基盤ビルド → OpenTouryoAssemblies\ へベンダ）
④ 対象サンプルを新規リポジトリへ取り出す
⑤ .csproj の OpenTouryo.* 参照（HintPath）を OpenTouryoAssemblies\ へ張り替える
⑥ root/files/resource をリポジトリ直下へコピーし、config のパスを張り替える
⑦ 残りの構成（接続文字列等）を整えて、ビルド・実行で検証する
```

**基盤（OpenTouryo フレームワーク）はバイナリ提供が前提。** ビルドした DLL を参照する
（`opentouryo-common-parts` / `AGENTS.md` の「クラスの階層と修正可否」）。

## ① 取り出すサンプルを選ぶ

**作りたいものに合うサンプルが起点になる。** サンプルは OpenTouryo リポジトリの
`root/programs/CS/`（net48 は `Samples\`、.NET 10.0 は `Samples4NetCore\`）配下。

| 作りたいもの | サンプル | ランタイム |
| --- | --- | --- |
| ASP.NET MVC | `Samples\WebApp_sample\MVC_Sample` | net48 |
| ASP.NET Core MVC | `Samples4NetCore\Backend\MVC_Sample` | .NET 10.0 |
| Web Forms | `Samples\WebApp_sample\WebForms_Sample` | **net48 のみ** |
| Windows Forms（2層C/S） | `Samples\2CS_sample\2CSClientWin_sample` | net48 |
| Windows Forms（2層C/S） | `Samples4NetCore\Legacy\2CS_sample\2CSClientWin_sample` | .NET 10.0 |
| バッチ / コンソール | `Samples\Bat_sample` / `Samples4NetCore\Legacy\Bat_sample` | net48 / .NET 10.0 |
| CLI | `Samples4NetCore\Legacy\CLI_sample` | .NET 10.0 |

**WPF は P層フレームワークを持たない**（`opentouryo-layer-p-winforms-screen` 参照）。
`2CS_sample\2CSClientWPF_sample` を参考に、画面は素の WPF として実装する。

## ② 取得元をユーザに選ばせる

**どのバージョンの OpenTouryo を使うかをユーザに確認する。**

| 選択 | `<ref>` | 用途 |
| --- | --- | --- |
| 固定タグ | 例 `03-20` | **安定運用**（`3_BuildLibsAtOtherRepos.bat` 相当） |
| develop | `develop` | 最新追従（`...InTimeOfDev.bat` 相当） |

選んだ `<ref>` を③のスクリプト生成に渡す。

## ③ セットアップ スクリプトを生成して実行

**その場限りのコマンド羅列にせず、セットアップ スクリプトを1本生成して実行する**
（再現・レビュー可能にする。生成物はリポジトリに残して再セットアップに使える）。模範は
MultiPurposeAuthSite の `root/programs/3_BuildLibsAtOtherRepos.bat`（固定タグ）/
`3_BuildLibsAtOtherReposInTimeOfDev.bat`（develop）。スクリプトの中身：

1. **ZIP 取得**（`git clone` ではない）— PowerShell の `WebClient.DownloadFile()` で
   `https://github.com/OpenTouryoProject/OpenTouryo/archive/<ref>.zip` を取得し、
   `Temp\OpenTouryo-<ref>\` に展開する。

2. **基盤ビルド** — 展開先の `...\root\programs\CS\` で、**4つのバッチを順に実行する**：

   ```
   2_Build_NuGet_net48.bat
   3_Build_Business_net48.bat
   2_Build_NuGet_netcore100.bat
   3_Build_Business_netcore100.bat
   ```

   前提ツール：**VS Build Tools**（net48 は非 SDK csproj で msbuild が要る）と
   **.NET SDK**（core は `dotnet build`）。

3. **ベンダ** — 生成物を導入リポジトリへコピーする（`xcopy /Y /E`）。

   ```
   Frameworks\Infrastructure\Build_net48       → <repo>\OpenTouryoAssemblies\Build_net48\
   Frameworks\Infrastructure\Build_netcore100  → <repo>\OpenTouryoAssemblies\Build_netcore100\
   ```

**1回実行すれば DLL は再利用できる**（毎回ビルドしない）。

## ④⑤ サンプルの取り出しと参照の張り替え（このスキルの核心）

### ④ 取り出す

対象サンプルのフォルダを新規リポジトリへコピーする。**`LayerB.cs` / `LayerD.cs` は
サンプルに同梱されたソース**なので、それごと取り出す（B/D層は別 DLL ではない。開発の起点）。

### ⑤ 参照を張り替える

サンプルの `.csproj` は、フレームワークを **`Reference` + `HintPath`（DLL 参照）** で参照している。
`Reference Include="OpenTouryo.*"` の **`HintPath` だけ**をベンダ先へ書き換える。

```xml
<!-- net48 -->
<Reference Include="OpenTouryo.Framework">
  <HintPath>..\OpenTouryoAssemblies\Build_net48\OpenTouryo.Framework.dll</HintPath>
</Reference>

<!-- .NET 10.0 -->
<Reference Include="OpenTouryo.Framework">
  <HintPath>..\OpenTouryoAssemblies\Build_netcore100\net10.0\OpenTouryo.Framework.dll</HintPath>
</Reference>
```

- **必要なアセンブリはサンプルの csproj に列挙済み**（`OpenTouryo.Public` / `.Public.Security` /
  `.Framework` / `.Business` / `.Framework.RichClient` / `.Business.RichClient` /
  `.CustomControl` / `.DamManagedOdp` ほか）。その `Reference` をそのまま使い、`HintPath` だけ直す。
- 元の `Build_*` フォルダ名を維持してベンダするので、**DLL 名・net48/core の区別はそのまま**。
  張り替えは**パス接頭辞の変更だけ**で済む。
- **`OpenTouryo.*` 以外（3rd-party）は触らない。** net48 は `packages.config`、
  core は `PackageReference` で NuGet 復元される。
- 相対パス（`..\` の数）はプロジェクトの配置に合わせる。

### 3層（WCF/WS）サンプルの注意

一部サンプルは 3層構成で、他サンプルの DLL（`WSServer_sample.dll` 等）や WCF エンドポイントを
参照する。**2層で使うなら、3層部分（`_3Tier` 画面・`Web.config` の endpoint 定義・他サンプル
参照）を削る。**

## ⑥ リソース（resource）の移設と config パスの張り替え

**サンプルの config はリソースを絶対パス `C:\root\files\resource\...` で参照している。**
そのままでは動かないので、移設して張り替える。

1. OpenTouryo の **`root/files/resource`** を導入リポジトリ**直下**へコピーする
   （＝リポジトリ直下に `resource\` ができる。中身は `Log` / `Sql` / `Xml` / `X509` / `Test`）。
   展開済み ZIP から取り出す。

2. `app.config` / `appsettings.json` の**パス系キーをリポジトリ直下の `resource\` へ張り替える**
   （絶対 `C:\root\files\resource\...` → リポジトリ相対 `resource\...`）。

   | キー | 参照先 |
   | --- | --- |
   | `FxLog4NetConfFile` | `resource\Log\SampleLogConf.xml` |
   | `FxXMLSPDefinition` / `FxXMLMSGDefinition` / `FxXMLSCDefinition` / `FxXMLTCDefinition` / `FxXMLTMProtocolDefinition` / `FxXMLTMInProcessDefinition` | `resource\Xml\*.xml`（XML 定義） |
   | `SqlTextFilePath` | `resource\Sql`（SQL 定義フォルダ） |
   | `SpRp_RsaCerFilePath` | `resource\X509\*.cer`（OAuth2 用証明書） |

3. **注意：net48 は `resource\Xml`、core は `resource/XML` と大文字小文字が違う。**
   Windows では問題ないが Linux で core を動かすと効く。**既存 config の綴りに合わせる。**

## ⑦ 残りの構成と検証

- 接続文字列（`ConnectionString_SQL` ほか。DBMS 選択は `actionType` の先頭。
  `opentouryo-config` / `opentouryo-p-call-business`）
- **core は `GetConfigParameter.InitConfiguration()` が必須**（`opentouryo-config`）
- ビルドが通り、実行できることを確認する（net48＝msbuild／core＝`dotnet build`）

## やってはいけないこと

- **`OpenTouryo.*` を `ProjectReference` にする** — 基盤はバイナリ提供が前提。DLL 参照にする
- **3rd-party の `PackageReference` / `packages.config` まで張り替える** — NuGet 復元に任せる
- **基盤（`Frameworks/Infrastructure/*`）を導入リポジトリに取り込んで改造する** — 纏め者の領分
  （`opentouryo-project-policy`）。導入プロジェクトはビルド済み DLL を参照するだけ
- **config のパスを `C:\root\files\...` の絶対パスのまま残す** — 移設して相対パスに張り替える
- **Download→Build→ベンダをアドホックなコマンド羅列で済ませる** — スクリプト化して残す
- **net48 サンプルを .NET 10.0 で、または Web Forms を core で使おうとする** — ランタイム対象外
- **`LayerB.cs` / `LayerD.cs` を別 DLL 化しようとする** — サンプルは同梱ソースが前提
