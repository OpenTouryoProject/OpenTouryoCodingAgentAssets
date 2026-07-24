# 子画面表示（Web Forms）コードスニペット（コピー元）

出典：UserGuide 各機能編 §2、実ソースで裏取り。**on-demand 参照**（SKILL 予算外）。

## OK メッセージダイアログ（後処理なし）

```csharp
// IconType は Information / Exclamation / StopMark（旧 doc の INFORMATION 等は古い綴り）
this.ShowOKMessageDialog("メッセージID", "本文", FxEnum.IconType.Information, "タイトル");
// オーバーロード：+ "dialogWidth:450px;dialogHeight:250px;status:no;"
```

## YES/NO 確認ダイアログ＋後処理

```csharp
this.ShowYesNoMessageDialog("メッセージID", "本文", "タイトル");

// 後処理は画面コードクラスに override（Yes/No/X）
protected override void UOC_YesNoDialog_Yes_Click(FxEventArgs parentFxEventArgs)
{
    switch (parentFxEventArgs.ButtonID)   // どのボタンから開いたか
    {
        case "btnXXXX": /* ... */ break;
        default: break;
    }
}
protected override void UOC_YesNoDialog_No_Click(FxEventArgs parentFxEventArgs) { }
protected override void UOC_YesNoDialog_X_Click(FxEventArgs parentFxEventArgs) { }
```

> ★ `buttonHistoryRecorder`=off だと `parentFxEventArgs.ButtonID` が常に `"dummy"`＝switch が効かない。

## 業務モーダルダイアログ

```csharp
this.ShowModalScreen("URL");                       // サーバ側イベントから
// クライアント側イベントから：
this.btn.OnClientClick = "return " + this.GetScriptToShowModalScreen("URL") + ";";

// 子画面を閉じる
this.CloseModalScreen();            // 親でポストバック＋後処理あり
this.CloseModalScreen_NoPostback(); // 後処理なし
// ※ CloseModalScreen_WithAllParent() はサポート終了（使わない）

// 後処理（親×子のボタンで分岐）
protected override void UOC_ModalDialog_End(FxEventArgs parentFxEventArgs, FxEventArgs childFxEventArgs)
{
    switch (parentFxEventArgs.ButtonID) { /* ... childFxEventArgs.ButtonID で更に分岐 ... */ }
}
```

## 業務モードレス画面／データ受け渡し（親画面別セッション）

```csharp
this.ShowNormalScreen("testScreen.aspx");   // 引数は開く子画面の URL（例。任意の画面パスでよい）

this.SetDataToModalInterface("key", value);
object v = this.GetDataFromModalInterface("key");
this.DeleteDataFromModalInterface("key");   // 引数なしで全削除
```

> 画面の新規作成は `opentouryo-layer-p-webforms-screen`。最新版は `window.open`／Floating div（旧 `showModalDialog` から置換）。
