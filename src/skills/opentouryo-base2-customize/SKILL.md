---
name: opentouryo-base2-customize
description: "OpenTouryo の親クラス2（纏め者がカスタマイズする基盤の Business 層＝Frameworks/Infrastructure/Business の My* クラス群）を、纏め者の立場でカスタマイズする。共通処理の差し込み点（UOC_ConnectionOpen による DBMS/接続選択、UOC_ABEND による例外→エラー画面、UOC_PreAction/AfterAction/AfterTransaction のライフサイクル、MyBaseController の addControlEvent や %1/%2 置換、MyLiteral の接頭辞、MyUserInfo、事前定義の例外メッセージ）を override で直し、3_Build_Business_* でビルドして OpenTouryo.Business(.RichClient).dll を作り、導入プロジェクトへ配布する。アプリ側でその挙動を読んで確認するのは opentouryo-project-policy、DLL の取得・ベンダは opentouryo-project-setup、業務コードを書くのは各層スキル。親クラス2 / ベースクラス2 / 基盤カスタマイズ / 纏め者 / 共通処理の差し込み / My* を扱うときに使う。"
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
- 直した DLL を**取得・ベンダ**する（アプリ側） → `opentouryo-project-setup`
- 業務コードを書く（アプリ開発者） → 各層スキル（`opentouryo-layer-*` ほか）

**アプリ開発者は親クラス2 を触らない。** ここは纏め者の領分。

## 親クラス2 とは（どこ・何・どうビルド）

- 実体は **`Frameworks/Infrastructure/Business/`**（`OpenTouryo.Business` プロジェクト）。
  リッチクライアント分は `RichClient/`（`OpenTouryo.Business.RichClient`）。
- 親クラス1（`Framework` / `Public` ＝バイナリ提供、**触らない**）の共通処理フックを **override** して、
  プロジェクト共通の挙動（接続・認証・例外・ログ・画面初期化）を注入するのが役割。
- ビルドは **`3_Build_Business_net48` / `3_Build_Business_netcore100`**
  （親クラス1 の `2_Build_NuGet_*` が先）。成果は `OpenTouryo.Business(.RichClient).dll`。
  これを導入プロジェクトが参照する（`opentouryo-project-setup` のベンダ）。
- **作業コピーは Temp の残留物ではなく、纏め者が保守する OpenTouryo のソース ツリー**（フォーク/クローン）。
  `project-setup` が Temp に展開するのはビルドの副産物で、そこを直接いじる場所ではない。

### 層別マップ

| 層 | 主なクラス | 役割 |
| --- | --- | --- |
| P層 | `Presentation/MyBaseController`（Web Forms・**abstract**）／`MyBaseMVController(Core)`（MVC）／`RichClient/Presentation/MyBaseControllerWin`（WinForms・具象） | 画面共通処理・イベント結線・例外→画面 |
| B層 | `Business/MyBaseLogic`・`MyFcBaseLogic`／`RichClient/Business/MyBaseLogic2CS`・`MyFcBaseLogic2CS` | 業務ロジックのライフサイクル・接続・トランザクション |
| D層 | `Dao/MyBaseDao`（＋ `CmnDao`） | クエリ実行の共通処理 |
| 共通 | `Util/MyLiteral`・`MyUserInfo`・`MyCmnFunction`／`Exceptions/MyBusiness*ExceptionMessage` | 接頭辞・ユーザ情報・共通関数・例外メッセージ |

## 主な差し込み点（override / 拡張ポイント）

親クラス2 は親クラス1 の `UOC_*` 共通フックを **override** して実装する。代表例（`reference` の実装で確認）：

| フック / 拡張点 | クラス | 何をする所 |
| --- | --- | --- |
| `UOC_ConnectionOpen` | `MyFcBaseLogic` | **DBMS / 接続の選択**（`actionType.Split('%')[0]` で Dam を選び `ConnectionString_<code>` をロード）。`opentouryo-p-call-business` |
| `UOC_PreAction` / `UOC_AfterAction` / `UOC_AfterTransaction` | `MyBaseLogic` / `MyFcBaseLogic` | 業務ロジックの前後・トランザクション後の共通処理（認証チェック・ログ等） |
| `UOC_ABEND` | `MyBaseController` / `MyFcBaseLogic` | **例外→共通エラー画面**への振替 |
| `addControlEvent` | `MyBaseController` / `MyBaseControllerWin` | **コントロール・イベントの結線を追加**（対応コントロール／イベントを増やす）。`opentouryo-layer-p-webforms-event` / `-winforms-event` |
| `UOC_CMNFormInit` / `UOC_CMNFormInit_PostBack` / `UOC_Finally` | `MyBaseController` | 画面共通の初期化・後処理 |
| 接頭辞（`FxPrefixOf*` / `PREFIX_OF_CHECK_BOX`） | `MyLiteral` | イベント自動結線が見る**コントロール接頭辞**の定義 |
| `%1` / `%2` 置換 | `MyBaseController` | メッセージ埋め込み（実装は Web Forms 側にしかない点に注意）。`opentouryo-message` |
| 事前定義の例外メッセージ | `MyBusinessApplicationExceptionMessage` / `MyBusinessSystemExceptionMessage`（＋ `.resx`） | 纏め者が事前に用意する例外メッセージ（XML 採番とは別系統）。`opentouryo-exception` / `opentouryo-message` |
| ユーザ情報 | `MyUserInfo` | プロジェクトのユーザ情報の構造。`opentouryo-auth` |

**具体はソースを読む。** 上表は入口で、実際の分岐・既定値は `Frameworks/Infrastructure/Business/` の各クラスにある。

## 変更 → 反映のループ

1. `Frameworks/Infrastructure/Business/` の対象 `My*` を直す（override 実装 / 定数 / メッセージ）。
2. **`3_Build_Business_net48` / `3_Build_Business_netcore100`** でビルド
   （親クラス1 のビルド `2_Build_NuGet_*` が先に要る）。
3. 生成された `OpenTouryo.Business(.RichClient).dll` を導入プロジェクトへ配布
   （`opentouryo-project-setup` のベンダ先 `OpenTouryoAssemblies\Build_*`）。
4. 依存アプリを再ビルドして反映。**破壊的変更（シグネチャ・挙動）は全依存アプリに波及**する。

## 規約・境界

- **親クラス1（`Framework` / `Public`）は触らない。** 依存は一方向（Business→Framework→Public）。
  逆参照は循環参照になる（`AGENTS.md` のクラス階層）。
- **名前空間ルート（`Touryo`）は変えない**（`AGENTS.md`）。
- **override の約束を壊さない。** 親クラス1 が呼ぶ前提のフックなので、`base` 呼び出しの要否や
  戻り値の約束を勝手に変えない。
- ランタイム差（net48 / core）で分かれる箇所は両方を保つ（`#if NETCOREAPP` 等。`AGENTS.md`）。

## やってはいけないこと

- **アプリ側リポジトリに親クラス2 のソースを取り込んで各アプリで個別改造する** — 親クラス2 は
  纏め者が一元管理し、DLL で配布する。アプリ側は参照するだけ（`opentouryo-project-setup`）
- **親クラス1（`Framework` / `Public`）を直して辻褄合わせ** — バイナリ提供が前提。触らない
- **Temp の展開物（`project-setup` の副産物）を直接編集する** — 作業コピーは保守用のソース ツリー
- **破壊的変更を告知なく入れる** — 依存アプリの再ビルドが要る。影響範囲を見てから
