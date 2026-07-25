# P層 Web Forms（イベント処理）コードスニペット（コピー元）

出典：UserGuide 共通編 §2.2.4／開発者編 §4.1.3-4／纏め者編 §5.2-5.3、実ソースで裏取り。**on-demand 参照**（SKILL 予算外）。

## イベントハンドラの命名と実装位置

コントロール名＝`[接頭辞]任意文字列`（`btn`/`txt`/`ddl`… は app.config で定義）。UOC メソッド名は実装位置で変わる。

| コントロールの位置 ＼ 実装位置 | 画面コードクラス／親クラス2・3 | その要素自身（マスタ/UC）上 |
| --- | --- | --- |
| コンテンツページ上 | `UOC_（コントロール名）_（イベント名）` | — |
| マスタページ上 | `UOC_（マスタページファイル名）_（コントロール名）_（イベント名）` | `UOC_（コントロール名）_（イベント名）` |
| Web ユーザコントロール上 | `UOC_（UCのID）_（コントロール名）_（イベント名）` | `UOC_（コントロール名）_（イベント名）` |

## 基本シグネチャ（戻り値 = string）

```csharp
// URL を返すと画面遷移、空文字を返すとポストバック
protected string UOC_btnCntnt_Click(FxEventArgs fxEventArgs)
{
    // TODO:
    return "";
}
```

マスタページ上ボタン（マスタ名 = TestScreen.master、画面コードクラスに実装）：

```csharp
protected string UOC_TestScreen_btnMasterIdvdl_Click(FxEventArgs fxEventArgs)
{
    return "";
}
```

> UOC メソッドは共通ハンドラからレイトバインドで呼ばれるため **`public` か `protected`**（`private` 不可）。

## GridView：UOC で扱うイベントと第2引数の型

**「…ing」系（キャンセル可能）だけ棟梁が UOC に渡す**（`FxEventArgs` ＋ **そのイベント固有の EventArgs**）。
対になる「編集開始／キャンセル／…ed」は **UOC でなく標準ハンドラ `(object sender, …EventArgs e)` のまま**。

| UOC で来るイベント | 第2引数の型 |
| --- | --- |
| `RowUpdating` | `GridViewUpdateEventArgs` |
| `RowDeleting` | `GridViewDeleteEventArgs` |
| `PageIndexChanging` | `GridViewPageEventArgs` |
| `Sorting` | `GridViewSortEventArgs` |
| `RowCommand` / `SelectedIndexChanged` | 第2引数なし（`FxEventArgs` のみ） |

対の標準ハンドラ（`(object sender, …)`・UOC でない）：`RowEditing`(`GridViewEditEventArgs`)／`RowCancelingEdit`(`GridViewCancelEditEventArgs`)／
`SelectedIndexChanging`(`GridViewSelectEventArgs`)／`RowUpdated`／`RowDeleted`。`RowEditing` で `EditIndex = e.NewEditIndex` → 再バインドで編集モードにする。

## コントロール種別と既定イベント名

| 種別（接頭辞） | イベント名 |
| --- | --- |
| ボタン `btn`／リンク `lbn`／イメージ `ibn`／イメージマップ `imp` | `Click` |
| テキスト `txt` | `TextChanged` |
| ドロップダウン `ddl`／リスト `lbx`／ラジオリスト `rbl`／チェックリスト `cbl` | `SelectedIndexChanged` |
| ラジオ `rbn`（＋チェックボックス `cbx`） | `CheckedChanged` |
| リピータ `rpt` | `ItemCommand` |
| グリッド `gvw` | `RowCommand`/`SelectedIndexChanged`/`RowUpdating`/`RowDeleting`/`PageIndexChanging`/`Sorting` |
| リストビュー `lvw` | `OnItemCommand`/`SelectedIndexChanged`/`ItemUpdating`/`ItemDeleting`/`PagePropertiesChanged`/`Sorting` |

## FxEventArgs のプロパティ

| プロパティ | 内容 |
| --- | --- |
| `ButtonID` | イベント発生元のコントロール名 |
| `InnerButtonID` | リピータ等の内部コントロール |
| `MethodName` | レイトバインドしたハンドラ（メソッド）名 |
| `X` / `Y` | イメージボタンのクリック座標 |
| `PostBackValue` | イメージマップのホットスポット値／**一覧表示系コントロールではアイテムの index**（`int.Parse`→`Items[index]`） |

> B層呼び出しは `opentouryo-p-call-business`、接頭辞の自動結線拡張は `opentouryo-base2-customize`（addControlEvent）。

## GridView 編集・削除・コマンドの実装

出典：`Aspx/testFxLayerP/table/testGridView.aspx(.cs)`（実サンプル）で裏取り。

```aspx
<%@ Page ... EnableEventValidation="false" %>  <%-- 動的コマンドボタンには必須 --%>
<asp:GridView ID="gvwGridView1" runat="server" AutoGenerateColumns="False" DataKeyNames="fileid">
  <Columns>
    <asp:CommandField ShowEditButton="True" />   <%-- 編集/更新/キャンセル --%>
    <asp:TemplateField><ItemTemplate>
      <asp:LinkButton ID="LinkButton1" runat="server" CommandName="Delete" Text="削除"
        OnClientClick="return confirm('削除してよろしいですか？');" />
    </ItemTemplate></asp:TemplateField>
  </Columns>
</asp:GridView>
```

```csharp
// 更新：編集行の各コントロールを FindControl で読み、キーは DataKeys で取る
protected string UOC_gvwGridView1_RowUpdating(FxEventArgs fxEventArgs, GridViewUpdateEventArgs e)
{
    GridViewRow gvRow = this.gvwGridView1.Rows[e.RowIndex];
    TextBox  txt = (TextBox)gvRow.FindControl("TextBox1");        // テンプレート列のコントロール
    CheckBox cbx = (CheckBox)gvRow.FindControl("cbxCheckBox3");
    int fileid = (int)this.gvwGridView1.DataKeys[e.RowIndex].Value;   // DataKeyNames で取得
    // … 値を反映（B層で UPDATE、または Session 保持の DataTable を書き換え）…
    this.gvwGridView1.EditIndex = -1;   // 編集モード解除
    this.BindGridData();                // 再バインド
    return "";
}

// 削除：キーは DataKeys（第2引数は GridViewDeleteEventArgs）
protected string UOC_gvwGridView1_RowDeleting(FxEventArgs fxEventArgs, GridViewDeleteEventArgs e)
{
    int fileid = (int)this.gvwGridView1.DataKeys[e.RowIndex].Value;
    // … B層で DELETE（→ opentouryo-p-call-business）…
    return string.Empty;
}

// コマンド：どのコマンドかは InnerButtonID（Select/Edit/Update/Cancel/Delete/Page/Sort/カスタム）
protected string UOC_gvwGridView1_RowCommand(FxEventArgs fxEventArgs)
{
    string cmd = fxEventArgs.InnerButtonID;
    return "";
}
```

> 編集開始/キャンセルは標準ハンドラ（UOC でない）：`gvwGridView1_RowEditing(object sender, GridViewEditEventArgs e)` で
> `this.gvwGridView1.EditIndex = e.NewEditIndex;` → 再バインドで編集モードにする。

## Repeater / ListView：行内コントロールは `PostBackValue` が「アイテムの index」

Repeater/ListView 内で `ItemCommand` に行かない AutoPostBack コントロールは**自前の UOC ハンドラ**に来る。
**どの行かは `fxEventArgs.PostBackValue`（＝アイテムの index）** で分かり、`Items[index].FindControl(...)` で行内コントロールを取る。

```csharp
protected string UOC_cbxCheckBox1_CheckedChanged(FxEventArgs fxEventArgs)   // Repeater 行内のチェックボックス
{
    int idx = int.Parse(fxEventArgs.PostBackValue);
    CheckBox cbx = (CheckBox)this.rptRepeater1.Items[idx].FindControl("cbxCheckBox1");
    return "";
}

protected string UOC_rptRepeater1_ItemCommand(FxEventArgs fxEventArgs) { return ""; }  // コマンド名は InnerButtonID
```

> ★ **ListView は編集系（`ItemUpdating`/`ItemDeleting`/`OnItemCommand`）が `(object sender, ListView…EventArgs e)` 署名**で
> 実装されることがあり（`FxEventArgs` でない）、`PagePropertiesChanged`/`Sorting` は `FxEventArgs` 版。**既存コードの署名に合わせる。**

## Repeater の .aspx（★ `CommandName="<%# Container.ItemIndex %>"` が PostBackValue の正体）

出典：`testRepeater.aspx`。`Register` はカスタムコントロール用。マスタは `testBlankScreen.master`、`EnableEventValidation="false"`。

```aspx
<%@ Register Assembly="OpenTouryo.CustomControl" Namespace="Touryo.Infrastructure.CustomControl" TagPrefix="cc1" %>
<asp:Repeater ID="rptRepeater1" runat="server">
  <HeaderTemplate><table border="1"><tr><th>…</th><th>Button</th></tr></HeaderTemplate>
  <ItemTemplate>
    <tr>
      <td><%# DataBinder.Eval(Container.DataItem, "fileid") %></td>
      <td><asp:TextBox ID="TextBox1" runat="server" Text='<%# DataBinder.Eval(Container.DataItem, "textbox") %>' /></td>
      <td><asp:CheckBox ID="cbxCheckBox1" runat="server" AutoPostBack="true"
            Checked='<%# DataBinder.Eval(Container.DataItem, "checkbox") %>' /></td>
      <%-- ★ コマンドボタンの CommandName に行 index を埋める → fxEventArgs.PostBackValue で取れる --%>
      <td><asp:Button ID="command1" runat="server" Text="コマンド" CommandName="<%# Container.ItemIndex %>" /></td>
    </tr>
  </ItemTemplate>
  <FooterTemplate></table></FooterTemplate>
</asp:Repeater>
```

## ListView の .aspx（LayoutTemplate の `itemPlaceholder` は必須）

出典：`testListView.aspx`。`OnItemEditing`/`OnItemCanceling` は**標準ハンドラをマークアップで結線**。`DataKeyNames` を付ける。

```aspx
<asp:ListView ID="lvwListView1" runat="server" DataKeyNames="fileid"
    OnItemEditing="lvwListView1_ItemEditing" OnItemCanceling="lvwListView1_ItemCanceling">
  <LayoutTemplate>
    <table runat="server">
      <tr runat="server" id="itemPlaceholderContainer">   <%-- ★ この2つのIDが必須 --%>
        <tr runat="server" id="itemPlaceholder"></tr>
      </tr>
    </table>
  </LayoutTemplate>
  <ItemTemplate>
    <tr>
      <td><asp:Label runat="server" Text='<%# Bind("filename") %>' /></td>
      <td><asp:LinkButton runat="server" CommandName="Edit"   Text="Edit" /></td>
      <td><asp:LinkButton runat="server" CommandName="Delete" Text="Delete" /></td>
      <%-- ソートは CommandName="Sort" ＋ CommandArgument に列名 --%>
      <th><asp:LinkButton runat="server" CommandName="Sort" CommandArgument="FileName" Text="File Name" /></th>
    </tr>
  </ItemTemplate>
  <EditItemTemplate>
    <tr>
      <td><asp:TextBox runat="server" Text='<%# Bind("filename") %>' /></td>
      <td><asp:LinkButton runat="server" CommandName="Update" Text="Update" />
          <asp:LinkButton runat="server" CommandName="Cancel" Text="Cancel" /></td>
    </tr>
  </EditItemTemplate>
</asp:ListView>
<asp:DataPager runat="server" PagedControlID="lvwListView1" PageSize="5">
  <Fields><asp:NumericPagerField /></Fields>
</asp:DataPager>
```
