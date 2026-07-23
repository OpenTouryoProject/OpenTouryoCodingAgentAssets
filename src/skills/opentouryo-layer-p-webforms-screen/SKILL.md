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

<!-- パス単位で例外を開ける -->
<location path="Aspx/OAuth2">
  <system.web>
    <authorization><allow users="*" /></authorization>
  </system.web>
</location>
```

### ログイン画面

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

ログアウトは専用画面（`logout.aspx`）の `UOC_FormInit` で `FormsAuthentication.SignOut()`。

## やってはいけないこと

- **`UOC_FormInit` / `UOC_FormInit_PostBack` を実装しない** — 親クラス1 で `abstract`。
  使わなくても空で実装する
- **親クラス1・親クラス2 を修正する** — バイナリ提供。画面コードクラスに実装する
- **`this.UserInfo` を自分で取得・生成する** — 親クラス2 が設定済み
- **ログイン画面で `IsNoSession` の設定やセッション消去を忘れる** — 前のセッションが残る
- **`RedirectFromLoginPage` の第2引数を `true` にする** — Cookie が永続化される。`false` を推奨
