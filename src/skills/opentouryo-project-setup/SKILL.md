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
⑦ .gitignore を置き、残りの構成（接続文字列等）を整えて、ビルド・実行で検証する
```

**基盤（OpenTouryo フレームワーク）はバイナリ提供が前提。** ビルドした DLL を参照する
（`opentouryo-common-parts` / `AGENTS.md` の「クラスの階層と修正可否」）。

## ① 取り出すサンプルを選ぶ

**作りたいものに合うサンプルが起点になる。** サンプルは OpenTouryo リポジトリの
`root/programs/CS/`（net48 は `Samples\`、.NET 10.0 は `Samples4NetCore\`）配下。

| 作りたいもの | サンプル | ランタイム | WS/3層依存 |
| --- | --- | --- | --- |
| ASP.NET MVC | `Samples\WebApp_sample\MVC_Sample` | net48 | 未確認 |
| ASP.NET Core MVC | `Samples4NetCore\Backend\MVC_Sample` | .NET 10.0 | 未確認 |
| Web Forms | `Samples\WebApp_sample\WebForms_Sample` | **net48 のみ** | **あり（transform 前提）** |
| Windows Forms（2層C/S） | `Samples\2CS_sample\2CSClientWin_sample` | net48 | 未確認 |
| Windows Forms（2層C/S） | `Samples4NetCore\Legacy\2CS_sample\2CSClientWin_sample` | .NET 10.0 | 未確認 |
| 3層リッチクライアント（WS/WCF 経由・WinForms/WPF） | `Samples\WS_sample\WSClient_sample\WSClientWin_sample`（WPF 等も同階層） | net48 | **あり（構成上必須）** |
| 3層リッチクライアント（同上・**実用性なし** ※） | `Samples4NetCore\Legacy\WS_sample\WSClient_sample\...` | .NET 10.0 | あり（構成上必須） |
| バッチ / コンソール | `Samples\Bat_sample` / `Samples4NetCore\Legacy\Bat_sample` | net48 / .NET 10.0 | 未確認 |
| CLI | `Samples4NetCore\Legacy\CLI_sample` | .NET 10.0 | 未確認 |

**「WS/3層依存あり」のサンプルは取り出し直後 `CS0246` が残る**（`WS_sample` の `WSIFType_sample` /
`WSServer_sample` ビルド出力に依存。依存元ソースは `Samples\WS_sample` に実在）。**確定該当（実ソース確認）**：
- **`WebForms_Sample`** — Web で WS をインプロセス利用（2層化 (B) も可）。
- **`WS_sample\WSClient_sample` 一式**（`WSClientWin_sample`/`WSClientWPF_sample` ほか。core は
  `Samples4NetCore\Legacy\...`）— 3層リッチクライアント＝構成上 WS 必須。**(A) が本筋・(B) 非該当**。
  **※ core 版は `BinaryFormatter` 廃止で実質インプロセスのみ＝実用的な3層にならず、実用は net48 側**
  （`opentouryo-transmission` / §4.4）。

他行（未確認）も同様の依存があり得る。**解消は (A) 3層維持／(B) 2層化**（下記「3層サンプルの扱い」。
共通機構は `samples/webservices.md`）。**到達点は「ソリューションが開ける状態」**で、as-is のクリーンビルドは保証しない。

**サンプル固有の癖は `samples/<サンプル>.md` に集約する**（取り出し前に確認する）。現状 `samples/webforms.md`
（Web Forms の WS/3層依存・config 二段構成）。他サンプルは実測次第で追加する。

**WPF は P層フレームワークを持たない**（`opentouryo-layer-p-winforms-screen` 参照）。
`2CS_sample\2CSClientWPF_sample` を参考に、画面は素の WPF として実装する。

## ② 取得元をユーザに選ばせる

**どのバージョンの OpenTouryo を使うかをユーザに確認する。**

| 選択 | `<ref>` | 用途 |
| --- | --- | --- |
| 固定タグ | 例 `03-20` | **安定運用**（`3_BuildLibsAtOtherRepos.bat` 相当） |
| develop | `develop` | 最新追従（`...InTimeOfDev.bat` 相当） |

選んだ `<ref>` を③（`opentouryo-project-setup-build`）に渡す。

## ③ 基盤 DLL をビルドしてベンダする → `opentouryo-project-setup-build`

**このステップは独立スキル `opentouryo-project-setup-build` が担う。** ②で選んだ `<ref>` と、①で
選んだサンプルの**標的ランタイム**（＋ `base2-overlay/` の有無）を渡して呼ぶ。3段構成：

1. **ZIP 取得**（`git clone` ではない）— `<ref>` の archive を `Temp\OpenTouryo-<ref>\` へ展開
2. **基盤ビルド** — `root\programs\CS\` で `2_/3_Build_*` を**標的ランタイムのバッチだけ**実行
3. **ベンダ** — 生成された `Build_net48\` / `Build_netcore100\` を `OpenTouryoAssemblies\` へコピー

正しいバッチ名、非対話実行の落とし穴（`pause`・ASCII・`.\`・括弧・MSYS／PowerShell ラッパ推奨）、
VS エディションによる msbuild 解決、ベンダ元パスの起点、`base2-overlay/` の上書きは、**すべて
`opentouryo-project-setup-build` に集約**している。**1回実行すれば DLL は再利用できる**（タグ更新時の
焼き直しにも同スキルを単独で使える）。

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
- **張り替えは接頭辞だけでは済まない**：net48 サンプルの元 HintPath は `…\Frameworks\Infrastructure\Build\`
  （サフィックス無し）だが、ベンダ先は `…\OpenTouryoAssemblies\Build_net48\`＝**末尾フォルダ名も変わる**。
- **張り替える対象は「ベンダ先 `Build_*\` に含まれる DLL すべて」**（`OpenTouryo.*` だけとは限らない）。
  例：net48 サンプルの `MySql.Data` / `Oracle.ManagedDataAccess` は **`packages.config` に無く**、
  HintPath が他サンプルのビルド出力（`..\..\..\WS_sample\Build\...`）を指すため **NuGet では復元されない**。
  これらは基盤のビルド出力 `Build_net48\` に同梱される（`OpenTouryo.DamMySQL` / `.DamManagedOdp` が依存）ので、
  `OpenTouryo.*` と同様にベンダ先へ張り替える。
- **触らないのは NuGet 復元される 3rd-party だけ**（net48＝`packages.config`、core＝`PackageReference`）。
- 相対パス（`..\` の数）はプロジェクトの配置に合わせる。
- **深いリポ パスは MAX_PATH(260) に当たる**（実測）。相対配置を保つと `nuget restore` がパッケージ内部の
  深いパスで超過し失敗する → **取り出したプロジェクトをリポ直下へフラット化**して相対 `HintPath` を張り替える
  （`long path` 有効化でも可。詳細は `samples/webservices.md`）。

### 3層（WCF/WS）サンプルの扱い

一部サンプルは 3層構成で、**他サンプルのビルド出力**（`WSServer_sample.dll` / `WSIFType_sample.dll` 等）に依存する
（依存元ソースは `Samples\WS_sample` に実在。無いのはビルド出力だけ）。単体では as-is で通らないことがあるが、
解消は2通り：
- **(A) 3層のまま通す** — 依存元サンプルも取り出し、⑤と同じ要領で張り替えてビルドし、**その出力を参照先
  （`WS_sample\Build\`）へ配置する**まで（`.sln` 直ビルドは `bin\Debug\` に出るので配置が要る＝実測）。**セットアップで完結**。
- **(B) 2層で使う** — WS 依存を切り離す（**後工程 `opentouryo-project-transform`**）。

**(A)/(B) の選択・層の削減・画面改変は、セットアップ中に判断を求めない**（開ける状態に達した後、利用者が
俯瞰して決める）。**WS/3層の共通手順は `samples/webservices.md`、サンプル固有は `samples/<サンプル>.md`**
（Web Forms は `samples/webforms.md`）。

## ⑥ リソース（resource）の移設と config パスの張り替え

**サンプルの config はリソースを絶対パス `C:\root\files\resource\...` で参照している。**
そのままでは動かないので、移設して張り替える。

**net48 Web Forms は config が二段構成**（パス系キーは `app.config`、接続文字列は `Web.config` 直下）。
初見で迷いやすいので `samples/webforms.md` を参照。core はキーが `appsettings.json` に集約される。

1. OpenTouryo の **`root/files/resource`** を導入リポジトリ**直下**へコピーする
   （＝リポジトリ直下に `resource\` ができる。中身は `Log` / `Sql` / `Xml` / `X509` / `Test`）。
   展開済み ZIP から取り出す。

2. `app.config` / `appsettings.json` の**パス系キーを環境変数方式で張り替える**
   （絶対 `C:\root\files\resource\...` → `%OT_RESOURCE_ROOT%\...`）。

   **相対パス（`resource\...`）は使わない。** フレームワークは設定値を**フルパス前提**で
   ファイル API（`File.Exists` 等）に渡すため、相対パスは**実行プロセスのカレント ディレクトリ基準**で
   解決される。IIS Express / w3wp のカレントはアプリ フォルダではないので、相対パスは原理的に解決できない
   （`ResourceLoader.Exists` → `System.ArgumentException: リソースファイル…は見つかりませんでした` で 500）。

   代わりに、`ResourceLoader` がパス解決の直前に展開する **`%環境変数%`** を使う
   （`StringVariableOperator.BuiltStringIntoEnvironmentVariable`）。マシン固有の絶対パスを config に
   残さずに済み、可搬になる。SQL 定義（`MyBaseDao.SetSqlByFile2` → `ResourceLoader`）も同じ経路で効く。

   | キー | 参照先 |
   | --- | --- |
   | `FxLog4NetConfFile` | `%OT_RESOURCE_ROOT%\Log\SampleLogConf.xml` |
   | `FxXMLSPDefinition` / `FxXMLMSGDefinition` / `FxXMLSCDefinition` / `FxXMLTCDefinition` / `FxXMLTMProtocolDefinition` / `FxXMLTMInProcessDefinition` | `%OT_RESOURCE_ROOT%\Xml\*.xml`（XML 定義） |
   | `SqlTextFilePath` | `%OT_RESOURCE_ROOT%\Sql`（SQL 定義フォルダ） |
   | `SpRp_RsaCerFilePath` | `%OT_RESOURCE_ROOT%\X509\*.cer`（OAuth2 用証明書） |

   **`OT_RESOURCE_ROOT` はリポジトリ直下の `resource\` を指す環境変数**（変数名は任意。この例に統一）。
   **セットアップ スクリプトで設定する**（ユーザ環境変数 `OT_RESOURCE_ROOT = <repo>\resource`）と、
   クローンし直しても再実行で張り直せる。設定後は IIS Express / プロセスの再起動で反映する。

3. **注意：config の綴りは実フォルダと一致していないことがある。** net48 サンプルの app.config は
   `resource\XML\...`（大文字）・`resource\test`（小文字）だが、実フォルダは `Xml` / `Test`。
   Windows は大文字小文字を区別しないので顕在化しないが、**Linux で core を動かすなら実フォルダの
   綴り（`Xml` / `Test` 等）に config を合わせて直す**（フォルダを config に合わせるのではない）。

## ⑦ .gitignore・残りの構成と検証

- 接続文字列（`ConnectionString_SQL` ほか。DBMS 選択は `actionType` の先頭。
  `opentouryo-config` / `opentouryo-p-call-business`）
- **core は `GetConfigParameter.InitConfiguration()` が必須**（`opentouryo-config`）
- **net48（`packages.config`）は msbuild の前に `nuget restore <sln>` が必須**
  （`msbuild /t:restore` では復元されない）。`nuget.exe` は取得した ZIP の
  `root\programs\nuget.exe` を流用できる。core は `dotnet restore`（`dotnet build` に含まれる）。
- **セッション状態**（net48 Web）：サンプルの `Web.config` が **`sessionState mode="StateServer"`** だと
  **ASP.NET State Service の起動が前提**。使わないなら `mode="InProc"` に変える。ビルドは通るのに起動できない、で迷いやすい
- ビルドが通り、実行できることを確認する（net48＝msbuild／core＝`dotnet build`）

### `.gitignore` を置く

リポジトリ直下に `.gitignore` を生成する。**まず作業ツリー `Temp/`（③の ZIP 展開・基盤ビルド）を除外する。**
`Temp/` には**基盤ソース（`Frameworks/Infrastructure` ＝親クラス2 を含む）丸ごと**が入るが、
アプリ リポジトリはビルド済み DLL を参照するだけなので**丸ごとは取り込まない**のが正しい。
親クラス2 をカスタマイズする場合でも、**バージョン管理するのは修正差分だけ**
（`base2-overlay/` は除外せずコミットする。`opentouryo-base2-customize`）。

```gitignore
# OpenTouryo セットアップの作業ツリー（ZIP 展開・基盤ビルド。基盤ソース＝親クラス2 を含む）
Temp/

# .NET ビルド生成物
bin/
obj/
packages/
.vs/
*.user
```

- **`OpenTouryoAssemblies/`（ベンダした DLL）と `base2-overlay/`（親クラス2 の修正差分）は除外しない**。
  リポジトリに含めて、再セットアップ無しでビルドでき、修正差分も追跡できるようにする。
- 既存の `.gitignore` があれば追記（重複行は避ける）。サンプル同梱の `.gitignore` があれば統合する。

## 完了後（任意）：構成変更へ進むか選ぶ

セットアップが済んだら、**続けて構成変更（`opentouryo-project-transform`）を行うかをユーザに選ばせる**。
早くフィードバックを得たいなら、セットアップ直後にその場で実行してよい（**任意**）。

- 進む → `opentouryo-project-transform`（例：3層サンプルの2層化・サンプル固有コードの整理・`CS0246` 解消）
- 後回し → 何もしない。利用者がソリューションを俯瞰してから別途依頼する

**セットアップの途中に構成変更の判断を割り込ませない。** 選ばせるのは「ソリューションが開ける状態」に達した後。

## やってはいけないこと

- **`OpenTouryo.*` を `ProjectReference` にする** — 基盤はバイナリ提供が前提。DLL 参照にする
- **3rd-party の `PackageReference` / `packages.config` まで張り替える** — NuGet 復元に任せる
- **基盤（`Frameworks/Infrastructure/*`）を導入リポジトリに取り込んで改造する** — 纏め者の領分
  （`opentouryo-project-policy`）。導入プロジェクトはビルド済み DLL を参照するだけ
- **作業ツリー `Temp/`（基盤ソース＝親クラス2 を含む）をコミットする** — `.gitignore` で除外する（⑦）。
  親クラス2 のカスタマイズは纏め者が別ソース ツリーで（`opentouryo-base2-customize`）
- **マシン固有の絶対パス（`C:\root\files\...` や `D:\git\MyApp\resource\...`）を config に直書きする**
  — 環境変数方式（`%OT_RESOURCE_ROOT%\...`）にする。可搬性が失われ、クローンごとに壊れる
- **resource のパスを相対（`resource\...`）にする** — カレント ディレクトリ基準で解決され、
  IIS Express / w3wp では届かず実行時 500。環境変数方式にする（⑥）
- **Download→Build→ベンダをアドホックなコマンド羅列で済ませる** — スクリプト化して残す
- **net48 サンプルを .NET 10.0 で、または Web Forms を core で使おうとする** — ランタイム対象外
- **`LayerB.cs` / `LayerD.cs` を別 DLL 化しようとする** — サンプルは同梱ソースが前提
