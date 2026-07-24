---
name: opentouryo-layer-p-webforms-screen
description: "OpenTouryo の P層を ASP.NET Web Forms（net48）で新規作成する。画面コードクラス（.aspx.cs、MyBaseController の派生）の作り方、クラス階層（BaseController / MyBaseController）、ページロード処理の UOC メソッド（UOC_FormInit / UOC_FormInit_PostBack は実装必須）、UOC_CMN 系との分界、this.UserInfo / ContentPageFileNoEx / GetMasterWebControl などの使えるメンバ、Forms 認証とログイン画面（IsNoSession / FxSessionAbandon）・ログアウトを扱う。Web Forms / aspx / 画面作成 / コンテンツページ / マスタページ / ページロード / ログイン画面 を伴う作業のときに使う。コントロールのイベント実装は opentouryo-layer-p-webforms-event、B層呼び出しは opentouryo-p-call-business を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層（Web Forms）：画面の新規作成

> 📋 **コピー元スニペット**：`references/snippets.md`（.aspx＋コードビハインド骨格・UOC_FormInit・コントロール取得。実装時はここから写す）。

## このスキルの適用範囲

**画面コードクラス（`.aspx.cs`）を新規に作る。** **net48 のみ**（Web Forms は Core に無い）。

- コントロールのイベント実装 → `opentouryo-layer-p-webforms-event`
- B層の呼び出し → `opentouryo-p-call-business`
- MVC → `opentouryo-layer-p-mvc`、Windows Forms → `opentouryo-layer-p-winforms-screen`
- B層 → `opentouryo-layer-b`、例外 → `opentouryo-exception`、ユーザ情報 → `opentouryo-auth`

## 実装場所

| 階層 | クラス | 修正 |
| --- | --- | --- |
| 画面コード親クラス1 | `BaseController`（`Touryo.Infrastructure.Framework.Presentation`。`System.Web.UI.Page` を継承） | **不可**（バイナリ提供） |
| 画面コード親クラス2 | `MyBaseController`（`Touryo.Infrastructure.Business.Presentation`） | **不可**（バイナリ提供） |
| 画面コードクラス | `MyBaseController` を継承した `.aspx.cs` | **可**（ここに実装する） |

```csharp
public partial class sampleScreen : MyBaseController
```

## UOC メソッドの分界

**`CMN` が付くものは親クラス2 の共通処理。付かないものが画面コードクラスの担当。**

| UOC メソッド | 実装場所 | 内容 |
| --- | --- | --- |
| `UOC_CMNFormInit` / `UOC_CMNFormInit_PostBack` | 親クラス2 | 全画面共通の初期処理 |
| `UOC_PreAction` / `UOC_AfterAction` / `UOC_Finally` | 親クラス2 | イベント処理の前後 |
| `UOC_Screen_Transition` | 親クラス2 | 画面遷移の方法 |
| `UOC_ABEND`（3種） | 親クラス2 | 例外処理（`opentouryo-exception` 参照） |
| **`UOC_FormInit`** | **画面コードクラス** | 初回ロード時の初期処理。**実装必須** |
| **`UOC_FormInit_PostBack`** | **画面コードクラス** | ポストバック時の初期処理。**実装必須** |
| **`UOC_（コントロール名）_（イベント名）`** | **画面コードクラス** | 各コントロールのイベント処理（→ `opentouryo-layer-p-webforms-event`） |
| `UOC_YesNoDialog_Yes_Click` / `_No_Click` / `_X_Click` | 画面コードクラス | Yes/No ダイアログの応答（→ `opentouryo-webforms-dialog`） |
| `UOC_ModalDialog_End` | 画面コードクラス | モーダルダイアログの終了（→ `opentouryo-webforms-dialog`） |

## ページロード処理（実装必須）

`UOC_FormInit`（初回ロード）/ `UOC_FormInit_PostBack`（ポストバック）を `protected override void` で実装する。
親クラス1 で `abstract`＝**使わなくても空で実装する**。コードは `references/snippets.md`。

## 使えるプロパティ・メソッド

| メンバ | 内容 |
| --- | --- |
| `this.UserInfo` | `MyUserInfo`。親クラス2 が設定済み（`opentouryo-auth`） |
| `this.ContentPageFileNoEx` | コンテンツページのファイル名（拡張子なし） |
| `this.RootMasterPageFileNoEx` | ルートマスタページのファイル名（拡張子なし） |
| `this.GetMasterWebControl(ID)` | マスタページ上のコントロールを取得する |
| `this.FxSessionAbandon()` | セッションを消去する（タイムアウト検出用 Cookie も消す） |
| `this.IsNoSession` | この画面でセッション ID を返さない（コンストラクタで設定） |

## マスタページの新規作成（子画面/ダイアログを使うなら必須）

コンテンツページはマスタページに乗せる。**マスタを新規に作るなら**：コードビハインドは **`BaseMasterController` を継承**し、
`.master` に **フレームワークが使う Fx 隠しフィールド一式**（`ChildScreenType` / `ChildScreenUrl` / `CloseFlag` /
`SubmitFlag` / `ScreenGuid` / `FxDialogStyle` / `BusinessDialogStyle` / `NormalScreenStyle` / `NormalScreenTarget` /
`DialogFrameUrl` / `WindowGuid` / `RequestTicketGuid`）と `ScriptManager` を置く。**これが無いとダイアログ・子画面・
不正操作防止が動かない。** 全文（隠しフィールド・`<head>` の js/css・`onload/onunload`）は `references/snippets.md`。

**★ 配布物の `Framework/Js/common.js`・`ie_key_event.js`・`Css/style.css` をプロジェクトに取り込み**、`<head>` で
リンク・`<body onload/onunload>` で結線する（これが無いとダイアログ/子画面/キー抑止/不正操作防止が動かない）。
既存マスタ（配布サンプルの `sampleScreen.master`）があれば雛形にできるが、**マスタ名はコンテンツ `.aspx` と別名に
読み替える**（無ければ上の骨格＋隠しフィールドから作る。`sampleScreen` は配布物固有名＝自プロジェクトに残さない）。
**マスタページはネスト可**（サンプル `testNestMasterScreen`。ルートマスタに Fx 隠しフィールドがあればよい）。

## 新規ファイルの csproj 登録・designer.cs（★ エージェント文脈で必須）

**VS デザイナが自動でやることを、エージェント/CLI は手でやる。** net48 は**非SDK csproj**なので、新規 `.aspx`/`.master`
は `<Content Include>`、コードビハインド `.aspx.cs`/`.master.cs` は `<Compile>`＋`<DependentUpon>`＋`<SubType>ASPXCodeBehind`、
`.designer.cs` は `<Compile>`＋`<DependentUpon>`（`SubType` なし）で登録する。`.designer.cs` も**手書き**する
（全サーバコントロールを `protected` フィールド宣言。**マスタ上コントロールは designer 不要＝`GetMasterWebControl` 経由**）。
登録 XML と designer の書き方は `references/snippets.md`。

## 認証（Forms 認証）

`web.config` に設定を書く。詳細は `opentouryo-auth`。

```xml
<system.web>
  <authentication mode="Forms">
    <forms name="formauth" loginUrl="Aspx/Start/login.aspx" defaultUrl="Aspx/Start/menu.aspx"
           timeout="10" protection="All" path="/" ... />
  </authentication>
  <authorization>
    <deny users="?" />          <!-- 未認証ユーザをサイト全体で拒否 -->
  </authorization>
</system.web>
<!-- ★ login.aspx / menu.aspx はサンプル画面名の例。自プロジェクトのログイン/メニュー画面パスに読み替える -->


<!-- パス単位で例外を開ける -->
<location path="Aspx/OAuth2">
  <system.web>
    <authorization><allow users="*" /></authorization>
  </system.web>
</location>
```

### ログイン画面

**P層 FW は Session 必須**なので、ログイン画面ではタイムアウト例外が出やすい。対策は3択：
**(a) ログイン画面に P層 FW を使わない／(b) `IsNoSession = true`（当該画面で機能 OFF）／(c) `FxSessionAbandon()`**
（詳細は `opentouryo-auth`）。下は (b)+(c) の例。

**`IsNoSession = true` をコンストラクタで設定し、`UOC_FormInit` でセッションを消す。**

```csharp
public partial class login : MyBaseController
{
    public login()
    {
        this.IsNoSession = true;   // この画面ではセッションIDを返さない
    }

    protected override void UOC_FormInit()
    {
        this.FxSessionAbandon();   // セッション消去
    }

    protected override void UOC_FormInit_PostBack() { }

    protected string UOC_btnButton1_Click(FxEventArgs fxEventArgs)
    {
        if (!string.IsNullOrEmpty(this.txtUserID.Text))
        {
            // ① .NET 側：Forms 認証のチケットを生成
            FormsAuthentication.RedirectFromLoginPage(this.txtUserID.Text, false);

            // ② OpenTouryo 側：ユーザ情報を保持
            MyUserInfo ui = new MyUserInfo(this.txtUserID.Text, Request.UserHostAddress);
            UserInfoHandle.SetUserInformation(ui);
        }
        return string.Empty;   // 画面遷移はしない（基盤に任せる）
    }
}
```

`RedirectFromLoginPage` の第2引数は Cookie を永続化するかどうか。**セキュリティを考慮して
`false` を推奨。**

ログアウトは専用画面（サンプルでは `logout.aspx`。自プロジェクトの画面名に読み替える）の `UOC_FormInit` で
`FormsAuthentication.SignOut()`。

### 共通エラー画面は素の `Page`（`MyBaseController` を継承しない）

**共通エラー画面（`ErrorScreen.aspx.cs`）は `System.Web.UI.Page` を継承する**（実物で確認）。**`MyBaseController` を
継承してはいけない**——継承するとエラー処理中に再エラーが起き、`ArgumentException`「キー `SessionAbandonFlag` は
既に追加」でエラーループになる。エラー画面への遷移元 `TransferErrorScreen` は親クラス2（`opentouryo-base2-customize`）。
OAuth2 のコールバック画面が素の `Page` なのと同型（`opentouryo-oauth2-client`）。

## やってはいけないこと

- **`UOC_FormInit` / `UOC_FormInit_PostBack` を実装しない** — 親クラス1 で `abstract`。
  使わなくても空で実装する
- **親クラス1・親クラス2 を修正する** — バイナリ提供。画面コードクラスに実装する
- **`this.UserInfo` を自分で取得・生成する** — 親クラス2 が設定済み
- **ログイン画面で `IsNoSession` の設定やセッション消去を忘れる** — 前のセッションが残る
- **`RedirectFromLoginPage` の第2引数を `true` にする** — Cookie が永続化される。`false` を推奨
- **共通エラー画面を `MyBaseController` を継承して作る** — 素の `Page` にする。継承すると
  `SessionAbandonFlag` 重複でエラーループになる
