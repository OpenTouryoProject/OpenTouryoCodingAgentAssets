# P層 Web Forms（画面作成）コードスニペット（コピー元）

出典：UserGuide 開発者編 §4.1／纏め者編 §5.2、実ソースで裏取り。**on-demand 参照**（SKILL 予算外）。

## コンテンツページ（.aspx）＝マスタページを選択して作成

```aspx
<%@ Page Language="C#" MasterPageFile="~/Aspx/Common/TestScreen.master" AutoEventWireup="true"
    CodeFile="testScreen.aspx.cs" Inherits="Aspx_testFxLayerP_testScreen" Title="Untitled Page" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" Runat="Server">
    <!-- ここに画面のコントロールを置く（接頭辞規約に従う：btn/txt/ddl…） -->
</asp:Content>
```

## 画面コードクラス（コードビハインド）

```csharp
using System;
// ～
using ProjectName.Infrastructure.Business.Util;

public partial class Aspx_testFxLayerP_testScreen : MyBaseController // 「画面コード親クラス２」を継承
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
