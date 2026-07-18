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

**作りたいものに合うサンプルが起点になる。** パスの接頭辞は **net48＝`Samples\`／.NET 10.0＝`Samples4NetCore\`**
（Web 系は `Samples4NetCore\Backend\`、2CS/Bat/CLI/WS 系は `Samples4NetCore\Legacy\`）。下表は各系列の起点。

| 作りたいもの | サンプル（系列\起点） | ランタイム | WS/3層依存 |
| --- | --- | --- | --- |
| ASP.NET MVC | `WebApp_sample\MVC_Sample`（core は `Backend\MVC_Sample`） | net48 / .NET 10.0 | **net48:あり** / core:なし |
| Web Forms | `WebApp_sample\WebForms_Sample` | **net48 のみ** | **あり（transform 前提）** |
| Windows Forms（2層C/S） | `2CS_sample\2CSClientWin_sample` | net48 / .NET 10.0 | なし |
| WPF（2層C/S） | `2CS_sample\2CSClientWPF_sample` | net48 / .NET 10.0 | なし |
| 3層リッチクライアント（WinForms/WPF・WS 経由） | `WS_sample\WSClient_sample\WSClientWin_sample`（`WPF`/`Win2`/`WinCone` も同階層） | net48（core は ※実用性なし） | **あり（構成上必須）** |
| バッチ | `Bat_sample\SimpleBatch_sample`（再実行可 `RerunnableBatch_sample`〜`3`） | net48 / .NET 10.0 | なし |
| CLI（コンソール） | `CLI_sample\Simple_CLI`（認証付 `DAG_Login_CLI` / `LIR_Login_CLI`） | net48 / .NET 10.0 | なし |

**「WS/3層依存」列の凡例**：`なし`＝csproj で WS 参照無しを確認済み／`あり`＝WS DLL 参照あり
（取り出し直後に missing-ref か `CS0246`。要 (A)/(B)）。

**サンプル選択では上表の全系列を必ず提示してユーザに選ばせる。系列をまとめて間引かない**
（実測：4択にまとめて **3層リッチクライアント＝`WSClient_sample` と WPF が選択肢から欠落**した）。**選択 UI が
選択肢数を制限しても、収まらなければ全系列を番号付きリストで提示して番号で選ばせる**（固定4択に押し込めて捨てない）。
派生（`2CS_sample` の機能デモや `WSClient_sample` の他 variant 等）は**系列を選んだ後の枝**でよいが、
系列そのものは全部見せる。

**「WS/3層依存あり」のサンプルは取り出し直後 `CS0246`（または missing-ref）が残る**（`WS_sample` の
`WSIFType_sample` / `WSServer_sample` に依存。依存元ソースは `Samples\WS_sample` に実在）。：
- **`WebForms_Sample`**（net48）— WS を利用（(B) WS 切り離しも可）。
- **`MVC_Sample` の net48**（`Crud1Controller` が `TestParameterValue` 等の WS 型を使用。**core の MVC はなし**）。
- **`WS_sample\WSClient_sample` 一式**（core は `Samples4NetCore\Legacy\...`）— 3層リッチクライアント＝構成上 WS 必須。
  故に **(A) が本筋・(B) 非該当**。**※ core 版は `BinaryFormatter` 廃止で実質インプロセスのみ＝実用は net48 側**
  （`opentouryo-transmission` / §4.4）。

**`なし` の行（2CS Win/WPF・Bat）は (A)・(B) 共に非該当。** 到達点は「開ける状態」で as-is クリーンビルドは保証しない。

**専用の `samples/<サンプル>.md` が無いサンプルも、この表＋`samples/webservices.md` で起点として取り出せる。**

<!-- 執筆者メモ（Claude Code は読み込み時に除去）：`samples/<サンプル>.md` は検証したサンプルから順に整備する
     残件。現状あるのは webforms.md（サンプル）／daogentool.md・dpquerytool.md（開発支援ツール）。
     サンプル固有の癖が見つかったら samples/<name>.md を起こす。 -->


**WPF は P層フレームワークを持たない**（`opentouryo-layer-p-winforms-screen` 参照）。
`2CS_sample\2CSClientWPF_sample` を参考に、画面は素の WPF として実装する。

## ② 取得元をユーザに選ばせる

**どのバージョンの OpenTouryo を使うかをユーザに確認する。**

| 選択 | `<ref>` | 用途 |
| --- | --- | --- |
| 固定タグ | **どのタグかをユーザに確認**（例示は下記） | **安定運用**（`3_BuildLibsAtOtherRepos.bat` 相当） |
| develop | `develop` | 最新追従（`...InTimeOfDev.bat` 相当） |

**「固定タグ」を選ばれたら、具体的なタグ番号を必ずユーザに確認する。`03-20` は例示であり、
勝手に既定値として使わない**（作者フィードバック 2026-07-18：例示タグが強制選択されて選べなかった）。
利用可能なタグは OpenTouryo リポジトリの releases / tags（`https://github.com/OpenTouryoProject/OpenTouryo/tags`）
で確認できる。最新の安定タグが分からなければ、候補を提示するか latest を案内してユーザに決めてもらう。

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
サンプルに同梱されたソース**なので、それごと取り出す（別 DLL ではない）。

**開発支援ツールも一緒に取り出す。** `Frameworks\Tools\` 配下（`Samples\` ではない）の `DaoGen_Tool`
（墨壺＝D層自動生成）と `DPQuery_Tool`（動的クエリ試験）を取り出し対象に含める（DAO 自動生成・動的 SQL は標準ワークフロー）。
⑤ と同様に張り替えるが、**両ツールは `HintPath`＋`PackageReference` 混在で net48 でも restore が要る**
（`Microsoft.Data.SqlClient` 等。漏れは `CS0234`）。詳細は `samples/daogentool.md` / `samples/dpquerytool.md`。

### ⑤ 参照を張り替える

サンプルの `.csproj` は、フレームワークを **`Reference` + `HintPath`（DLL 参照）** で参照している。
`Reference Include="OpenTouryo.*"` の **`HintPath` だけ**をベンダ先へ書き換える。

```xml
<!-- net48（core は Build_netcore100\net10.0\ に読み替え） -->
<Reference Include="OpenTouryo.Framework">
  <HintPath>..\OpenTouryoAssemblies\Build_net48\OpenTouryo.Framework.dll</HintPath>
</Reference>
```

- **必要なアセンブリはサンプルの csproj に列挙済み**（`OpenTouryo.Public` / `.Framework` / `.Business` ほか）。
  その `Reference` をそのまま使い、`HintPath` だけ直す。
- **触らないのは NuGet 復元される 3rd-party だけ**（net48＝`packages.config`、core＝`PackageReference`）。
  相対パス（`..\` の数）はプロジェクトの配置に合わせる。

**間違えやすい edge case は `references/reference-rewrite.md`**（末尾フォルダ名 `Build\`→`Build_net48\` も変わる／
`MySql`・`Oracle` もベンダ張替＝NuGet 非復元／MAX_PATH フラット化）。

### 3層（WCF/WS）サンプルの扱い

一部サンプルは**他サンプルのビルド出力**（`WSServer_sample.dll` / `WSIFType_sample.dll`）に依存する
（依存元ソースは `Samples\WS_sample` に実在。無いのはビルド出力だけ）。as-is で通らないことがあり、解消は2通り：
- **(A) そのまま残す** — 依存元サンプルも取り出し⑤同様に張り替えてビルドし、**出力を参照先 `WS_sample\Build\` へ
  配置する**（`.sln` 直ビルドは `bin\Debug\` に出る＝実測。要配置）。**セットアップで完結**。
- **(B) WS 依存を切り離す** — WS 参照を外す（**後工程 `opentouryo-project-transform`**）。

**(A)/(B) の選択・層の削減・画面改変は、セットアップ中に判断を求めない**（開ける状態の後に利用者が決める）。
**WS/3層の共通手順は `samples/webservices.md`、サンプル固有は `samples/<サンプル>.md`**（Web Forms は `webforms.md`）。

## ⑥ リソース（resource）の移設と config パスの張り替え

**サンプルの config はリソースを絶対パス `C:\root\files\resource\...` で参照している。** 動かすには：

1. OpenTouryo の **`root/files/resource`**（`Log` / `Sql` / `Xml` / `X509` / `Test`）を導入リポジトリ**直下**へ
   コピーする（展開済み ZIP から。＝リポジトリ直下に `resource\` ができる）。
2. `app.config` / `appsettings.json` の**パス系キーを環境変数方式 `%OT_RESOURCE_ROOT%\...` に張り替える**
   （絶対 `C:\root\files\resource\...` から。**相対パスは不可**）。

**機構の詳細は `references/resource-config.md`**：なぜ相対パス不可か（`ResourceLoader` がフルパス前提）・
`%VAR%` 展開（`FxContainerization` とは別機構）・**パス系キー一覧**（`Fx*` / `SqlTextFilePath` /
`SpRp_RsaCerFilePath`）・綴りの罠（`Xml` / `Test`）・net48 Web の config 二段構成。Fx キー全般は `opentouryo-config`。

## ⑦ .gitignore・残りの構成と検証

- 接続文字列（`ConnectionString_SQL` ほか。DBMS 選択は `actionType` の先頭。
  `opentouryo-config` / `opentouryo-p-call-business`）
- **core は `GetConfigParameter.InitConfiguration()` が必須**（`opentouryo-config`）
- **net48（`packages.config`）は msbuild の前に `nuget restore <sln>` が必須**
  （`msbuild /t:restore` では復元されない）。`nuget.exe` は取得した ZIP の
  `root\programs\nuget.exe` を流用できる。core は `dotnet restore`（`dotnet build` に含まれる）。
- **セッション状態**（net48 Web）：サンプルの `Web.config` が **`sessionState mode="StateServer"`** だと
  **ASP.NET State Service の起動が前提**。使わないなら `mode="InProc"` に変える。ビルドは通るのに起動できない、で迷いやすい
- ビルドが通り、実行できることを確認する（net48＝msbuild／core＝`dotnet build`）。**ビルド成功＝動く、ではない**
  （初期化は `%OT_RESOURCE_ROOT%` を読むので実行して初めて ⑥ の成否が分かる）。WebForms の IIS Express 実行確認
  （HTTP で SSL 回避・環境変数の渡し方・`Ping`/`login` スモーク・500 の見方）は `references/run-verify.md`

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

- 進む → `opentouryo-project-transform`（例：WS 依存の切り離し・サンプル固有コードの整理・`CS0246` 解消）
- 後回し → 何もしない。利用者がソリューションを俯瞰してから別途依頼する

**セットアップの途中に構成変更の判断を割り込ませない。** 選ばせるのは「ソリューションが開ける状態」に達した後。

**セットアップ成果はコミットを促す。** 未コミットのままだと作業ツリーから失われうる（実測）。ビルド確認まで済んだ
節目でユーザにコミットを提案する（git 操作はしない方針は保つ）。

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
- **サンプル選択で系列を間引く** — 固定4択に押し込めて **3層リッチクライアント（`WSClient_sample`）や WPF を
  落とさない**（①。実測で欠落。UI 制限時は番号付きリストで全系列を出す）
