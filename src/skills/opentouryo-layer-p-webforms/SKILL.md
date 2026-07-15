---
name: opentouryo-layer-p-webforms
description: "OpenTouryo の P層を ASP.NET Web Forms（.NET Framework 4.8）で実装する。画面コードクラス（MyBaseController の派生）、UOC メソッド（UOC_FormInit / UOC_FormInit_PostBack / UOC_btnXXX_Click）、FxEventArgs、コントロール名の接頭辞（FxPrefixOfButton 等）によるイベントの自動結線、マスタページ・Webユーザコントロール上のコントロールの命名規約、引数クラスを介した B層の呼び出し、Forms 認証を扱う。Web Forms / aspx / master / マスタページ / ポストバック / イベントハンドラ / コントロール を伴う作業のときに使う。MVC は opentouryo-layer-p-mvc、Windows Forms は opentouryo-layer-p-winforms を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層（ASP.NET Web Forms）

## このスキルの適用範囲

画面コードクラス（`.aspx.cs`）の実装。**.NET Framework 4.8 のみ**（Web Forms は Core に無い）。

- MVC → `opentouryo-layer-p-mvc`
- Windows Forms → `opentouryo-layer-p-winforms`
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
| **`UOC_（コントロール名）_（イベント名）`** | **画面コードクラス** | 各コントロールのイベント処理 |
| `UOC_YesNoDialog_Yes_Click` / `_No_Click` / `_X_Click` | 画面コードクラス | Yes/No ダイアログの応答（必要なら） |
| `UOC_ModalDialog_End` | 画面コードクラス | モーダルダイアログの終了（必要なら） |

`UOC_FormInit` / `UOC_FormInit_PostBack` は親クラス1 で `abstract`。**使わなくても空で実装する。**

## イベントは接頭辞で自動結線される

**これが Web Forms 版の中核。コントロール名の接頭辞は命名規約ではなく機能そのもの。**

```
設定ファイルから接頭辞を読む（FxPrefixOfButton = "btn" など）
  → 「接頭辞 → フレームワークのイベントハンドラ」の対応表を作る
  → コントロールツリーを走査し、ID が接頭辞で始まるコントロールにハンドラを結線
  → ハンドラが UOC_（コントロール名）_（イベント名）へレイトバインドする
```

**`.aspx` に `OnClick` を書かない。** フレームワークが結線する。

```xml
<%@ Register Assembly="OpenTouryo.CustomControl"
             Namespace="Touryo.Infrastructure.CustomControl" TagPrefix="cc1" %>

<!-- OnClick は書かない。ID の接頭辞 btn が結線を決める -->
<cc1:WebCustomButton ID="btnButton1" runat="server" Text="検索" />
```

### 接頭辞の一覧

**接頭辞は設定ファイル（`app.config` の `appSettings`）で定義する。**
未設定の種類は**結線されない**（`if (!string.IsNullOrEmpty(prefix))` で分岐している）。

| 設定キー | サンプルでの値 | コントロール |
| --- | --- | --- |
| `FxPrefixOfButton` | `btn` | ボタン |
| `FxPrefixOfLinkButton` | `lbn` | リンクボタン |
| `FxPrefixOfImageButton` | `ibn` | イメージボタン |
| `FxPrefixOfImageMap` | `imp` | イメージマップ |
| `FxPrefixOfTextBox` | `txt` | テキストボックス |
| `FxPrefixOfDropDownList` | `ddl` | ドロップダウンリスト |
| `FxPrefixOfListBox` | `lbx` | リストボックス |
| `FxPrefixOfRadioButton` | `rbn` | ラジオボタン |
| `FxPrefixOfRadioButtonList` | `rbl` | ラジオボタンリスト |
| `FxPrefixOfCheckBox` | `cbx` | チェックボックス |
| `FxPrefixOfCheckBoxList` | `cbl` | チェックボックスリスト |
| `FxPrefixOfRepeater` | `rpt` | リピータ |
| `FxPrefixOfGridView` | `gvw` | グリッドビュー |
| `FxPrefixOfListView` | `lvw` | リストビュー |

**値はプロジェクトごとに変えられる。** 上記はサンプルの値。既存コードと設定ファイルを確認する。

`FxPrefixOfComboBox` / `FxPrefixOfPictureBox` はリッチクライアント専用で、**Web Forms では
結線されない**（`opentouryo-layer-p-winforms` 参照）。`FxPrefixOfCommand` は定数が定義されて
いるだけで、実装では使われていない（ASP.NET Mobile Web の名残と見られる）。

<!--
  結線箇所は2つに分かれている（実装で確認済み）:
    BaseController（親クラス1）  … 上表のうち CheckBox 以外の13種
    MyBaseController（親クラス2）… CHECK_BOX（MyLiteral.PREFIX_OF_CHECK_BOX）
  親クラス2 で接頭辞を追加できる作りだが、バイナリ提供のため利用側では変更できない。
  PREFIX_OF_COMMAND は FxCmnFunction.cs:218,486 にコメントアウトで残っているのみ。
-->

## イベントハンドラの命名規約

**コントロールがどこに置かれているかで名前が変わる。**

| コントロールの位置 | ハンドラ名 |
| --- | --- |
| コンテンツページ上 | `UOC_（コントロール名）_（イベント名）` |
| マスタページ上 | `UOC_（マスタページのファイル名）_（コントロール名）_（イベント名）` |
| Webユーザコントロール上 | `UOC_（ユーザコントロールのID）_（コントロール名）_（イベント名）` |

```csharp
// コンテンツページ上の btnButton1
protected string UOC_btnButton1_Click(FxEventArgs fxEventArgs)

// sampleScreen.master 上の btnMButton1
protected string UOC_sampleScreen_btnMButton1_Click(FxEventArgs fxEventArgs)

// ID が sampleControl1 のユーザコントロール上の btnUCButton
protected string UOC_sampleControl1_btnUCButton_Click(FxEventArgs fxEventArgs)
```

同じユーザコントロールを2つ置いた場合、**ID が違えばハンドラも別**になる
（`UOC_sampleControl1_btnUCButton_Click` と `UOC_sampleControl2_btnUCButton_Click`）。

### シグネチャ

```csharp
protected string UOC_（コントロール名）_（イベント名）(FxEventArgs fxEventArgs)
```

| 要素 | 決まり |
| --- | --- |
| アクセス修飾子 | `protected`。**`private` にすると呼ばれない** |
| 戻り値 | `string`。**遷移先 URL**。遷移しないなら `string.Empty` を返す |
| 引数 | `FxEventArgs` |

GridView の `RowUpdating` / `RowDeleting` / `PageIndexChanging` / `Sorting` だけ、
オリジナルの `EventArgs` も取る。

```csharp
protected string UOC_gvwGridView_RowUpdating(FxEventArgs fxEventArgs, EventArgs e)
```

**レイトバインドで呼ばれるため、シグネチャが違っても、修飾子が `private` でも、
コンパイルは通り実行時に呼ばれないだけ。**

### FxEventArgs

| プロパティ | 内容 |
| --- | --- |
| `ButtonID` | イベントに関係付けられているコントロール名 |
| `InnerButtonID` | リピータ等の内部に配置されたコントロール |
| `MethodName` | レイトバインドに使ったメソッド名 |
| `X` / `Y` | イメージボタンの座標 |
| `PostBackValue` | イメージマップのホットスポット値、リピータ等のコマンド名 |

## B層の呼び出し

```csharp
protected string UOC_sampleScreen_btnMButton1_Click(FxEventArgs fxEventArgs)
{
    // 引数クラスを生成
    TestParameterValue testParameterValue = new TestParameterValue(
        this.ContentPageFileNoEx,   // 画面名（コンテンツページのファイル名・拡張子なし）
        fxEventArgs.ButtonID,       // コントロール名（押されたコントロール）
        "SelectCount",              // メソッド名 → B層の UOC_SelectCount に振り分けられる
        actionType,
        this.UserInfo);

    // B層を生成して実行
    LayerB myBusiness = new LayerB();
    TestReturnValue testReturnValue = (TestReturnValue)myBusiness.DoBusinessLogic(
        (BaseParameterValue)testParameterValue, iso);

    // 業務例外は戻り値で返る（opentouryo-exception 参照）
    if (testReturnValue.ErrorFlag)
    {
        // testReturnValue.ErrorMessageID / ErrorMessage / ErrorInfo を使う
    }

    return string.Empty;   // 遷移しない
}
```

**MVC と違い、B層のメソッド名は文字列で明示する。** MVC はアクション名が自動で使われるが、
Web Forms はイベントハンドラ名と B層のメソッド名が対応しないため、自分で指定する。

| 引数クラスの項目 | Web Forms | （参考）MVC |
| --- | --- | --- |
| 画面名 | `this.ContentPageFileNoEx` | `this.ControllerName` |
| コントロール名 | `fxEventArgs.ButtonID` | `"-"`（固定） |
| メソッド名 | **文字列リテラルで明示** | `this.ActionName`（自動） |

## 使えるプロパティ・メソッド

| メンバ | 内容 |
| --- | --- |
| `this.UserInfo` | `MyUserInfo`。親クラス2 が設定済み |
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

ログイン画面。**`IsNoSession = true` をコンストラクタで設定し、`UOC_FormInit` で
セッションを消す。**

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

- **`.aspx` に `OnClick` などのイベントを結線する** — フレームワークが接頭辞で自動結線する
- **接頭辞の規約から外れたコントロール名を付ける** — 命名規約ではなく機能。
  結線されずイベントが発火しない
- **イベントハンドラを `private` にする** — レイトバインドで呼ばれるため `protected` にする。
  コンパイルは通り、実行時に呼ばれないだけ
- **イベントハンドラの戻り値を `void` にする** — `string`（遷移先 URL）。遷移しないなら
  `string.Empty` を返す
- **コントロール名をページ・マスタページ・ユーザコントロールを跨いで重複させる** —
  ASP.NET としては問題ないが、P層フレームワークのイベント処理機能が許可しない
- **`UOC_FormInit` / `UOC_FormInit_PostBack` を実装しない** — 親クラス1 で `abstract`。
  使わなくても空で実装する
- **マスタページ上のコントロールのハンドラに接頭辞を付け忘れる** —
  `UOC_（マスタページのファイル名）_（コントロール名）_（イベント名）`
- **B層のメソッド名を渡し忘れる** — MVC と違い自動では決まらない。文字列で明示する
