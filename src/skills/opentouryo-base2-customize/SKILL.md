---
name: opentouryo-base2-customize
description: "OpenTouryo の親クラス2（纏め者がカスタマイズする基盤の Business 層＝Frameworks/Infrastructure/Business の My* クラス群）を、纏め者の立場でカスタマイズする。共通処理の差し込み点（UOC_ConnectionOpen による DBMS/接続選択、UOC_ABEND による例外→エラー画面、UOC_PreAction/AfterAction/AfterTransaction のライフサイクル、MyBaseController の addControlEvent や %1/%2 置換、MyLiteral の接頭辞、MyUserInfo、事前定義の例外メッセージ）を override で直し、3_Build_Business_* でビルドして OpenTouryo.Business(.RichClient).dll を作り、導入プロジェクトへ配布する。アプリ側でその挙動を読んで確認するのは opentouryo-project-policy、DLL のビルド・ベンダは opentouryo-project-setup-build、業務コードを書くのは各層スキル。親クラス2 / ベースクラス2 / 基盤カスタマイズ / 纏め者 / 共通処理の差し込み / My* を扱うときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 親クラス2（基盤 Business 層）のカスタマイズ

<!-- 執筆者メモ（Claude Code は読み込み時に除去）：纏め者向けスキル。読者はアプリ開発者ではない。
     first-cut は「どこを・どう直し・どうビルド/配布するか」の地図＋差し込み点＋境界に絞る。
     クラス個別の詳細は Frameworks/Infrastructure/Business のソースを読む（project-policy と対）。 -->

## このスキルの読者と適用範囲

**纏め者（フレームワークを整備する役）向け。** 親クラス2＝**基盤の Business 層**
（`Frameworks/Infrastructure/Business/` の `My*` クラス群）をプロジェクト方針に合わせて直す。

- アプリ側で「この挙動はどうなっているか」を**読んで確認**する → `opentouryo-project-policy`
- 直した DLL を**ビルド・ベンダ**する（アプリ側） → `opentouryo-project-setup-build`
- 業務コードを書く（アプリ開発者） → 各層スキル（`opentouryo-layer-*` ほか）

**アプリ開発者は親クラス2 を触らない。** ここは纏め者の領分。

## 親クラス2 とは（どこ・何・どうビルド）

- 実体は **`Frameworks/Infrastructure/Business/`**（`OpenTouryo.Business` プロジェクト）。
  リッチクライアント分は `RichClient/`（`OpenTouryo.Business.RichClient`）。
- 親クラス1（`Framework` / `Public` ＝バイナリ提供、**触らない**）の共通処理フックを **override** して、
  プロジェクト共通の挙動（接続・認証・例外・ログ・画面初期化）を注入するのが役割。
- ビルドは **`3_Build_Business_net48` / `3_Build_Business_netcore100`**（親クラス1 の `2_Build_NuGet_*` が先）。
  これを導入プロジェクトが参照する（`opentouryo-project-setup-build` のベンダ）。
- **★ `OpenTouryo.Business` と `OpenTouryo.Business.RichClient`（2CS）は別 sln＝ビルド経路が違う**（実測・net48 03-20）。
  `3_Build_Business_net48` がビルドするのは `Business_net48.sln`＝**`Business` + `CustomControl` だけ**。**2CS クラス
  （`MyBaseLogic2CS` / `MyFcBaseLogic2CS` ＝ `OpenTouryo.Business.RichClient`）は別の `BusinessRichClient_net48.sln`
  を明示ビルドしないと生成されない**（`opentouryo-project-setup-build` が回す `2_/3_Build_*` サブセットも
  `Nuget_RichClient_net48.sln` も作らない＝出来るのは `Framework.RichClient` まで。※本体のフル一式／`9_CICD.bat`
  なら出る）。**2CS を直してもこのサブセットだと無言で無視される**（エラーも出ない）。core も同構成で
  同じ穴（`BusinessRichClient_netcore100.sln` が別在）。→ 2CS を触るなら次項のビルドに一手足す。
- **カスタマイズは「修正ファイルだけ」をオーバーレイとしてバージョン管理する**（後述の「バージョン管理」）。
  `opentouryo-project-setup-build` が展開する丸ごとのツリーはビルドの副産物で、そこを直接いじって放置する場所ではない。

### 層別マップ

| 層 | 主なクラス | 役割 |
| --- | --- | --- |
| P層 | `Presentation/MyBaseController`（Web Forms・**abstract**）／`MyBaseMVController(Core)`（MVC）／`Presentation/MyBaseAsyncApiController(Core)`（**Web API**・`ActionFilterAttribute`）／`RichClient/Presentation/MyBaseControllerWin`（WinForms・具象） | 画面/API 共通処理・イベント結線・認証・例外→画面/ログ |
| B層 | `Business/MyBaseLogic`・`MyFcBaseLogic`／`RichClient/Business/MyBaseLogic2CS`・`MyFcBaseLogic2CS`（**★2CS は別 sln**）／`RichClient/Asynchronous/MyBaseAsyncFunc`（非同期親クラス2） | 業務ロジックのライフサイクル・接続・トランザクション |
| 引数/戻り値 | `Common/MyParameterValue`・`MyReturnValue`（＝**引数/戻り値の親クラス2**。`BaseParameterValue`/`BaseReturnValue` を継承） | B層メソッドで運ぶ引数/戻り値に共通項目を足す。**WS 対応で `[Serializable]`** |
| D層 | `Dao/MyBaseDao`（＋ `CmnDao`） | クエリ実行の共通処理 |
| 共通 | `Util/MyLiteral`・`MyUserInfo`・`MyCmnFunction`・`MySubsysInfo`・`MyAttribute`／`RichClient/Util/RcMyCmnFunction`／`Exceptions/MyBusiness*ExceptionMessage` | 接頭辞・ユーザ情報・共通関数・サブシステム情報・カスタム属性・例外メッセージ |

## 主な差し込み点（override / 拡張ポイント）

親クラス2 は親クラス1 の `UOC_*` 共通フックを **override** して実装する。代表例（`reference` の実装で確認）：

| フック / 拡張点 | クラス | 何をする所 |
| --- | --- | --- |
| `UOC_ConnectionOpen` | `MyFcBaseLogic`（＋2CS `MyFcBaseLogic2CS`）。**同ロジックが `[Obsolete]` の `MyBaseLogic`/`MyBaseLogic2CS` にも重複** | **DBMS / 接続の選択**（`parameterValue.ActionType.Split('%')[0]` で Dam を選び `ConnectionString_<code>` をロード）。`opentouryo-p-call-business`。※1 DBMS 固定に簡素化すると **`ActionType` の DB プレフィックス切替が無効化**（意図的なら可）。**★ 片方だけ直すと deprecated 双子の旧分岐が DLL に残る**（例：`ConnectionString_ODP` 残存）→ DLL から消すなら**4クラス全部**直す |
| `UOC_PreAction` / `UOC_AfterAction` / `UOC_AfterTransaction` | `MyBaseLogic` / `MyFcBaseLogic` | 業務ロジックの前後・トランザクション後の共通処理（認証チェック・ログ等） |
| `UOC_ABEND` | `MyBaseController` / `MyFcBaseLogic` | **例外→共通エラー画面**への振替 |
| `addControlEvent` | `MyBaseController` / `MyBaseControllerWin` | **コントロール・イベントの結線を追加**（対応コントロール／イベントを増やす）。`opentouryo-layer-p-webforms-event` / `-winforms-event` |
| `UOC_CMNFormInit` / `UOC_CMNFormInit_PostBack` / `UOC_Finally` | `MyBaseController` | 画面共通の初期化・後処理 |
| 接頭辞（`FxPrefixOf*` / `PREFIX_OF_CHECK_BOX`） | `MyLiteral` | イベント自動結線が見る**コントロール接頭辞**の定義 |
| `%1` / `%2` 置換 | `MyBaseController` | メッセージ埋め込み（実装は Web Forms 側にしかない点に注意）。`opentouryo-message` |
| 事前定義の例外メッセージ | `MyBusinessApplicationExceptionMessage` / `MyBusinessSystemExceptionMessage`（＋ `.resx`） | 纏め者が事前に用意する例外メッセージ（XML 採番とは別系統）。`opentouryo-exception` / `opentouryo-message` |
| ユーザ情報 | `MyUserInfo` | プロジェクトのユーザ情報の構造。`opentouryo-auth` |
| `AuthenticateAsync`/`OnAuthorizationAsync`・`OnActionExecuting/Executed`・例外フィルタ | `MyBaseAsyncApiController`（net48）/ **同名 Core 版** | **Web API の認証（`EnumHttpAuthHeader`＝Basic/Bearer）・権限/閉塞チェックの stub・`ACCESS` ログ・例外ログ**。`★必要であれば…` に業務共通の引継ぎ情報（Claim）を足す。`opentouryo-auth` |
| 引数/戻り値の共通項目 | `MyParameterValue` / `MyReturnValue` | 全 B層呼び出しで運ぶ共通引数（ユーザ情報等）・戻り値の器。**`[Serializable]` を外さない**（WS で転送） |
| 非同期処理の前後（`UOC_*`） | `MyBaseAsyncFunc`（RichClient 非同期） | WPF/WinForms の非同期処理の前後・スレッド数管理・画面ロック（`CanOutPutLog` でログ抑止可） |
| WinForms のイベント結線／エラー表示 | `RcMyCmnFunction` | `MyBaseControllerWin` が使う接頭辞→イベント結線と `ShowErrorMessageWin/WPF`。接頭辞対応を増やすならここも |
| サブシステム情報／カスタム属性 | `MySubsysInfo`（`SubsysInfo` 継承・`SubsysID` enum）／`MyAttribute`（`MyAttributeA/B/C`） | 案件のサブシステム区分・独自メタ属性を**継承／追加で拡張**（override ではない。テンプレートを自由に育てる） |

**具体はソースを読む。** 上表は入口で、実際の分岐・既定値は `Frameworks/Infrastructure/Business/` の各クラスにある。

### DBMS を足す/減らすときの"面"（チェックリスト）

`UOC_ConnectionOpen` の分岐を触るだけでは不完全。**4点を揃える**（どれか残すと半端に生き続ける）：
①ロジック分岐（上記**4クラス全部**）／②csproj の `<Reference>`+`HintPath`（例 `OpenTouryo.DamManagedOdp`。RichClient の
net48・netcore 両方）／③ベンダされる Dam DLL 自体（`Build_*` から外す）／④config の `ConnectionString_<code>` キー（サンプル側）。

## 変更 → 反映のループ

1. 対象 `My*` を **`base2-overlay/`（バージョン管理された修正差分。後述）** で編集する
   （override 実装 / 定数 / メッセージ）。
2. ビルド スクリプトが**オーバーレイを固定タグの展開ツリーへ上書き**してから
   **`3_Build_Business_net48` / `3_Build_Business_netcore100`** でビルドする
   （親クラス1 のビルド `2_Build_NuGet_*` が先に要る）。**この overlay 適用は `opentouryo-project-setup-build` の生成
   スクリプトが担う**（その `examples.md` の **`1b` ブロック**。「任意」表記だが overlay があれば必須＝見落とさない）。
   **2CS（`MyBaseLogic2CS` / `MyFcBaseLogic2CS`）を触ったら、`3_Build_Business_*` に加えて `BusinessRichClient_net48.sln`
   （core は `_netcore100`）も別途ビルドする**（さもないと 2CS の変更が無言で無視される。前述）。
   **★ この RichClient sln は非SDK＝`/t:restore` が壊れる（`/t:build` 単体）。かつ net48/netcore が `obj\` を共有し
   netcore の restore 残骸で net48 が落ちる→`Business\RichClient\obj`・`CustomControl\RichClient\obj` の残骸を消す**
   （実装・正本は `opentouryo-project-setup-build` の `examples.md` `2b`）。
3. 生成された `OpenTouryo.Business.dll`（2CS を直したなら `OpenTouryo.Business.RichClient.dll` も）を導入プロジェクトへ配布
   （`opentouryo-project-setup-build` のベンダ先 `OpenTouryoAssemblies\Build_*`）。
4. 依存アプリを再ビルドして反映。**破壊的変更（シグネチャ・挙動）は全依存アプリに波及**する。

## バージョン管理（オーバーレイ ＋ 固定タグ）

親クラス2 のソースは丸ごと（約13,800行）を抱え込まず、**直したファイルだけ**を、
元のパスを保った `base2-overlay/` に置いて Git 管理する（＝修正差分だけを残す）。**「差分」は
ファイル単位の丸ごと差し替え**（編集済みの `.cs` をそのまま置く）で、行差分＝パッチ（hunk）ではない
（適用は下記コピーで上書きするため）。

```
<repo>/
  base2-overlay/                                    ← コミットする（修正だけ・小さい）
    Frameworks/Infrastructure/Business/
      Business/MyFcBaseLogic.cs
      Util/MyLiteral.cs
      Exceptions/MyBusinessApplicationExceptionMessage.cs
  OpenTouryoAssemblies/Build_net48/...              ← ビルド済み DLL（コミット）
  Temp/                                             ← .gitignore で除外（使い捨て）
```

- **取得元は固定タグに固定する**（`develop` は土台が動きオーバーレイの当たりがズレる。
  `opentouryo-project-setup-selection` ②で固定タグを選ぶ）。
- ビルド スクリプトは `3_Build_Business_*` の**前に**オーバーレイを展開ツリーへ上書きする
  （`<extract>` は展開先。深いリポで MAX_PATH を避けるため短い作業ルート `C:\otr\...` のこともある。
  `opentouryo-project-setup-build`）：

  ```powershell
  # フォルダ相手の xcopy は F/D を訊いて非対話で止まりうる。Copy-Item が安全
  Copy-Item -Path base2-overlay\* -Destination <extract>\root\programs\CS\ -Recurse -Force
  # xcopy を使うなら /I を付ける： xcopy /Y /E /I base2-overlay\* <extract>\root\programs\CS\
  ```

  **元エンコードを保って書く**：基盤ソースは **UTF-8 BOM 付き**で日本語コメントを含む。オーバーレイをツールで
  生成・編集する際に BOM 無し／別エンコードで書くと**日本語コメントが壊れる**。BOM 付き UTF-8 のまま扱う。

- **★ 短ルートの展開ツリーをワークスペースに加え、そこの基盤ソースを直接いじる（コピーバックは廃止）。**
  短い作業ルート（`C:\otr\`）で展開・ビルドすると、直す元の `Frameworks/Infrastructure`（特に `Business`）は
  **`C:\otr\OpenTouryo-<ref>\root\programs\CS\Frameworks\Infrastructure` に在る**。以前は深いリポへコピーバックする
  手順だったが**実測で繰り返し抜けた**ので、コピーはやめ、**この短ルートをワークスペースに追加**して
  （VS Code なら「フォルダーをワークスペースに追加」）そこを作業場所にする。**編集した基盤ソースは差分を
  `base2-overlay/` へ取り込んでコミット**（＝バージョン管理の実体は overlay。展開ツリーは `.gitignore` / 使い捨て）。
  `opentouryo-project-setup-build` §1 と対。
  **★ 正典は1本**：展開ツリーは固定タグから再生成し、**overlay 適用が唯一の変更経路**。展開ツリーを直接いじってよいのは
  編集の"作業場"としてで、**直したら必ず `base2-overlay/` へ取り込む**（overlay に無い直接編集は再抽出で消える＝一次成果にしない）。
- こうすると DLL は **「固定タグ ＋ オーバーレイ」から再現可能**。リポジトリに残るのは修正差分だけ。
- **置き場はアプリ リポジトリ同居**（`base2-overlay/` をコミット。`Temp/` は除外のまま、DLL はコミット）。
  1リポジトリで完結する。**複数アプリで親クラス2 を共有する場合は、纏め者の専用リポジトリに
  オーバーレイを置き、各アプリはビルド済み DLL だけ受け取る**（重複を避ける）。
- タグを上げるときは、タグを差し替えてオーバーレイを再適用・再ビルドし、
  upstream 側の変更と衝突した箇所（当たらなくなった差分）を直す。

## 規約・境界

- **親クラス1（`Framework` / `Public`）は触らない。** 依存は一方向（Business→Framework→Public）。
  逆参照は循環参照になる（`AGENTS.md` のクラス階層）。
- **名前空間ルート（`Touryo`）は変えない**（`AGENTS.md`）。
- **override の約束を壊さない。** 親クラス1 が呼ぶ前提のフックなので、`base` 呼び出しの要否や
  戻り値の約束を勝手に変えない。
- ランタイム差（net48 / core）で分かれる箇所は両方を保つ（`#if NETCOREAPP` 等。`AGENTS.md`）。
  **※ upstream は同じ ODP 分岐でもガードが4クラスで不揃い**（`#if NETCOREAPP2_0` 等の旧ガードが混在。net10 は
  `NETCOREAPP2_0` 未定義で実質無効）＝直すとき既定の `#if` を鵜呑みにせず、対象ランタイムで実際に有効か確認する。

## やってはいけないこと

- **親クラス2 のソースを丸ごと取り込んで、アプリを親クラス2 ソースから直接ビルドする（`ProjectReference` 化）**
  — 親クラス2 は DLL に固めて参照する。バージョン管理するのは**修正差分（`base2-overlay/`）だけ**（上記）
- **複数アプリで親クラス2 をそれぞれ勝手に分岐させる** — 共有するなら纏め者の専用リポジトリに一元化する
- **親クラス1（`Framework` / `Public`）を直して辻褄合わせ** — バイナリ提供が前提。触らない
- **Temp の展開物（`project-setup` の副産物）を直接編集して放置する** — 修正は `base2-overlay/` に残す
  （展開ツリーへの適用はビルド スクリプトが行う）
- **破壊的変更を告知なく入れる** — 依存アプリの再ビルドが要る。影響範囲を見てから
- **差し込み点の選択肢を固定4択に畳んで落とす**（実測：`%1/%2`・Web API 認証等が脱落）— 上表を**全部**提示、
  UI が絞るなら番号付きリストで（AGENTS.md「選択肢は間引かない」の複製＝AGENTS.md 欠落時も効く）
