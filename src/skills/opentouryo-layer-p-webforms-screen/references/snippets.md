# P層 Web Forms（画面作成）コードスニペット（コピー元）

出典：UserGuide 開発者編 §4.1／纏め者編 §5.2、実ソースで裏取り。**on-demand 参照**（SKILL 予算外）。

## コンテンツページ（.aspx）＝マスタページを選択して作成

> ★ 例の名前は **マスタ `CommonMaster.master` と コンテンツ `SupplierScreen.aspx` を別名**にしてある
> （実サンプルは `sampleScreen.master` と `sampleScreen.aspx` が拡張子抜き同名でイベント接頭辞を取り違えやすい。
> 自分で作るときも**マスタとコンテンツは別名**にする）。

```aspx
<%@ Page Language="C#" MasterPageFile="~/Aspx/Common/Master/CommonMaster.master" AutoEventWireup="true"
    CodeFile="SupplierScreen.aspx.cs" Inherits="Aspx_sample_SupplierScreen" Title="Untitled Page" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" Runat="Server">
    <!-- ここに画面のコントロールを置く（接頭辞規約に従う：btn/txt/ddl…） -->
</asp:Content>
```

## 画面コードクラス（コードビハインド）

```csharp
using System;
// ～
using ProjectName.Infrastructure.Business.Util;

public partial class Aspx_sample_SupplierScreen : MyBaseController // 「画面コード親クラス２」を継承
{
    /// <summary>ページロード（初回）＝実装必須</summary>
    protected override void UOC_FormInit()
    {
        // 初回ロード時の処理
        // TODO:
    }

    /// <summary>ページロード（ポストバック）＝実装必須</summary>
    protected override void UOC_FormInit_PostBack()
    {
        // ポストバック時の処理
        // TODO:
    }
}
```

## コントロール取得ユーティリティ

```csharp
Label label = (Label)this.GetMasterWebControl("Label1");   // マスタページ上
TextBox tb  = (TextBox)this.GetContentWebControl("TextBox1"); // コンテンツページ上
// this.GetFxWebControl(...) も利用可
```

## よく使うメンバ

- `this.ContentPageFileNoEx`：画面を表す文字列（引数クラスの screenId に渡す）。
- `this.RootMasterPageFileNoEx`：ルートマスタページ名。
- `this.UserInfo`：ユーザ情報（ベース2 で追加した項目）。

イベント処理（ボタン等の UOC メソッド）は `opentouryo-layer-p-webforms-event`、
B層呼び出しは `opentouryo-p-call-business`、子画面/ダイアログは `opentouryo-webforms-dialog`。

## マスタページの新規作成（子画面/ダイアログを使うなら必須）

出典：UserGuide 纏め者編 §5.2、`OTRVCAS` の `Aspx/Common/Master/sampleScreen.master(.cs)`（実物）で裏取り。

コードビハインド（`.master.cs`）は **`BaseMasterController` を継承**する：

```csharp
using Touryo.Infrastructure.Framework.Presentation;
// ★ マスタ名はコンテンツ .aspx と別名にする（同名だとイベント接頭辞を取り違える）
public partial class CommonMaster : BaseMasterController { }   // マスタベースページ
```

`.master` には **フレームワークが使う Fx 隠しフィールド一式**を置く（無いとダイアログ/子画面/不正操作防止が動かない）。
`<form runat="server">` 内・`<asp:ScriptManager runat="server">` とともに：

```aspx
<asp:HiddenField ID="ChildScreenType" runat="server" Value="0" />
<asp:HiddenField ID="ChildScreenUrl"  runat="server" Value="0" />
<asp:HiddenField ID="CloseFlag"       runat="server" Value="0" />
<asp:HiddenField ID="SubmitFlag"      runat="server" Value="0" />
<asp:HiddenField ID="ScreenGuid"      runat="server" Value="0" />
<asp:HiddenField ID="FxDialogStyle"       runat="server" Value="0" />
<asp:HiddenField ID="BusinessDialogStyle" runat="server" Value="0" />
<asp:HiddenField ID="NormalScreenStyle"   runat="server" Value="0" />
<asp:HiddenField ID="NormalScreenTarget"  runat="server" Value="0" />
<asp:HiddenField ID="DialogFrameUrl"  runat="server" Value="0" />
<asp:HiddenField ID="WindowGuid"      runat="server" Value="0" />
<asp:HiddenField ID="RequestTicketGuid" runat="server" Value="0" />
```

**★ 配布物の JS/CSS を取り込むのが前提**（無いとダイアログ・子画面・キーイベント抑止・不正操作防止が動かない）：
`<head>` で `Framework/Js/common.js`・`Framework/Js/ie_key_event.js`・`Css/style.css` をリンクし、
`<body onload="Fx_Document_OnLoad();" onunload="Fx_Document_OnClose();">` を結線する（纏め者編 §5.2）。
これらの js/css は配布サンプル（`WebForms_Sample` の `Framework/Js`・`Css`）から自プロジェクトへコピーする。

配布サンプルの `sampleScreen.master` があれば雛形にできるが、**マスタ名はコンテンツ `.aspx` と別名に読み替える**
（`sampleScreen` は配布物固有名＝残さない）。無ければ上の骨格＋隠しフィールドから作る。

## 新規 WebForms ファイルの csproj 登録（★ エージェント文脈で必須）

**VS デザイナが自動で行う登録を、エージェント/CLI では手で書く。** net48 は**非SDK csproj**なので、
`.aspx`/`.master` と各コードビハインドを明示登録しないとビルド対象にならない：

```xml
<!-- ページ本体（.aspx / .master）は Content。★ マスタとコンテンツは別名（CommonMaster ≠ SupplierScreen） -->
<Content Include="Aspx\sample\crud\SupplierScreen.aspx" />
<Content Include="Aspx\Common\Master\CommonMaster.master" />

<!-- コードビハインド（.aspx.cs / .master.cs）は Compile ＋ DependentUpon ＋ ASPXCodeBehind -->
<Compile Include="Aspx\sample\crud\SupplierScreen.aspx.cs">
  <DependentUpon>SupplierScreen.aspx</DependentUpon>
  <SubType>ASPXCodeBehind</SubType>
</Compile>
<!-- designer は DependentUpon のみ（SubType なし） -->
<Compile Include="Aspx\sample\crud\SupplierScreen.aspx.designer.cs">
  <DependentUpon>SupplierScreen.aspx</DependentUpon>
</Compile>
```

## designer.cs の手書き（VS デザイナ非在の文脈）

`.aspx.designer.cs` / `.master.designer.cs` は VS が自動生成する。エージェントは手書きする：

- **画面上の全サーバコントロールを `protected` フィールドで宣言**する（`partial class`。型は `global::System.Web.UI.WebControls.Button` 等）。
- **マスタ上のコントロールは designer 不要**（コンテンツ画面から直接触らず `GetMasterWebControl("ID")` 経由で取る）。
- ダイアログ用の Fx 隠しフィールドも designer に宣言が要る（マスタの designer 側）。
