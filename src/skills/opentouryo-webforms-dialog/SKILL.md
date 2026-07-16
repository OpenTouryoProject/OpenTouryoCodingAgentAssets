---
name: opentouryo-webforms-dialog
description: "OpenTouryo の P層（ASP.NET Web Forms）で子画面表示機能を使う。OK メッセージダイアログ（ShowOKMessageDialog）、YES/NO 確認ダイアログ（ShowYesNoMessageDialog）とその後処理（UOC_YesNoDialog_Yes_Click / _No_Click / _X_Click）、業務モーダルダイアログ（ShowModalScreen / GetScriptToShowModalScreen / CloseModalScreen / CloseModalScreen_NoPostback）とその後処理（UOC_ModalDialog_End）、業務モードレス画面（ShowNormalScreen）、ダイアログ間の情報受け渡し（SetDataToModalInterface / GetDataFromModalInterface）を扱う。子画面 / ダイアログ / モーダル / モードレス / メッセージダイアログ / 確認ダイアログ / ポップアップ / サブ画面 を Web Forms で表示する作業のときに使う。画面の新規作成そのものは opentouryo-layer-p-webforms-screen を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層（Web Forms）：子画面表示機能

## このスキルの適用範囲

**Web Forms で、ダイアログや子画面を開く。** 親クラス1（`BaseController`）が用意する
子画面表示 API を、画面コードクラスのイベント処理から呼ぶ。

- 画面そのものの作成 → `opentouryo-layer-p-webforms-screen`
- イベントハンドラの書き方 → `opentouryo-layer-p-webforms-event`
- **Web Forms 専用。** MVC / Windows Forms には無い

## 4種類の子画面

| 種類 | 開くメソッド | 後処理（コールバック） |
| --- | --- | --- |
| OK メッセージダイアログ | `ShowOKMessageDialog` | **無い**（通知のみ） |
| YES/NO 確認ダイアログ | `ShowYesNoMessageDialog` | `UOC_YesNoDialog_Yes_Click` / `_No_Click` / `_X_Click` |
| 業務モーダルダイアログ | `ShowModalScreen` / `GetScriptToShowModalScreen` | `UOC_ModalDialog_End` |
| 業務モードレス画面 | `ShowNormalScreen` / `GetScriptToShowNormalScreen` | **無い** |

### ブラウザ実装（最新版）

**IE 以外のブラウザでは擬似ダイアログを使う。**

- OK / YES・NO ダイアログ → **Floating div**
- 業務モーダルダイアログ → **`window.open` メソッド**

（古いドキュメントには「モダンブラウザで業務モーダルが表示できない」とあるが、
これは `showModalDialog` を使っていた旧版の話。最新版は上記の方式に置き換わっている。）

**`CloseModalScreen_WithAllParent` はサポートされなくなった。** メソッドは残っているが使わない。

## OK メッセージダイアログ

**通知だけ。後処理は無い。** イベント処理から呼ぶ。

```csharp
this.ShowOKMessageDialog(
    "messageID",                        // メッセージID
    "メッセージ本文",                    // メッセージ
    FxEnum.IconType.Information,         // アイコン（下記）
    "ダイアログ表示テスト");             // ウィンドウ名
```

`dialogStyle` を足すオーバーロードもある（`"dialogWidth:450px;dialogHeight:250px;status:no;"`）。

`FxEnum.IconType` は **`Information` / `Exclamation` / `StopMark`** の3値
（情報 / 警告 / エラー。**旧ドキュメントの `INFORMATION` 等の綴りは古い**）。

## YES/NO 確認ダイアログ

**後処理を画面コードクラスに `override` で実装する。**

```csharp
this.ShowYesNoMessageDialog("messageID", "保存しますか？", "確認");
// dialogStyle を足すオーバーロードもある
```

```csharp
// [YES] が押されたとき
protected override void UOC_YesNoDialog_Yes_Click(FxEventArgs parentFxEventArgs)
{
    // parentFxEventArgs.ButtonID = ダイアログを開いた親画面のボタン名
    switch (parentFxEventArgs.ButtonID)
    {
        case "btnSave":
            // 保存処理
            break;
    }
}

protected override void UOC_YesNoDialog_No_Click(FxEventArgs parentFxEventArgs) { }
protected override void UOC_YesNoDialog_X_Click(FxEventArgs parentFxEventArgs) { }
```

**`parentFxEventArgs.ButtonID` で、どのボタンからダイアログを開いたかを判別する。**
1画面に確認ダイアログが複数ある場合、`switch` で振り分ける。

## 業務モーダルダイアログ

### サーバ側イベントから開く

```csharp
this.ShowModalScreen("Aspx/Sub/subScreen.aspx");
// dialogStyle を足すオーバーロードもある
```

### クライアント側イベントから開く

`GetScriptToShowModalScreen` は**起動用の JavaScript 文字列を返す。**
コントロールの `OnClientClick` などに設定する。

```csharp
this.btnOpen.OnClientClick = this.GetScriptToShowModalScreen("Aspx/Sub/subScreen.aspx");
```

### 閉じる（子画面側で呼ぶ）

| メソッド | 閉じた後の親画面 |
| --- | --- |
| `CloseModalScreen()` | ポストバックし、後処理（`UOC_ModalDialog_End`）を実行 |
| `CloseModalScreen_NoPostback()` | ポストバックせず、後処理を実行しない |
| ~~`CloseModalScreen_WithAllParent()`~~ | **サポート外**（使わない） |

### 後処理

```csharp
protected override void UOC_ModalDialog_End(
    FxEventArgs parentFxEventArgs,   // 親画面で押した（ダイアログを開いた）ボタン
    FxEventArgs childFxEventArgs)    // 子画面で押した（ダイアログを閉じた）ボタン
{
    switch (parentFxEventArgs.ButtonID) { /* ... */ }
}
```

## 業務モードレス画面

```csharp
this.ShowNormalScreen("Aspx/Sub/normalScreen.aspx");
```

**後処理は無い**（親子間の制御をしないため）。クライアント側から開く
`GetScriptToShowNormalScreen` もある。

## ダイアログ間の情報受け渡し

**親画面 ↔ モーダルダイアログのデータ受け渡し。**

```csharp
this.SetDataToModalInterface("orderId", orderId);          // 設定
object v = this.GetDataFromModalInterface("orderId");      // 取得
this.DeleteDataFromModalInterface("orderId");              // 削除（キー指定）
this.DeleteDataFromModalInterface();                       // 削除（全て）
```

保持先は**親画面別セッション領域**（画面ごとに内部で別インデックスになるので、キー名が
衝突しても競合しない）。**所定の画面からしかアクセスできない。**

**使い終わったら消す。** 消さない・大きなデータを入れると、サーバがメモリリークする。

## 後処理をマスタページ共通ハンドラに書けない

**YES/NO・モーダルの後処理（`UOC_YesNoDialog_*` / `UOC_ModalDialog_End`）は、
画面コード親クラス2 の「マスタページ上のコントロールの共通イベント処理」に実装できない。**
どのページのボタン履歴かを親クラス2 側で判別できないため。**画面コードクラスに実装する。**

## やってはいけないこと

- **`CloseModalScreen_WithAllParent()` を使う** — サポートされなくなった
- **`FxEnum.IconType.INFORMATION` と書く** — 正しくは `Information`（旧ドキュメントの綴りは古い）
- **YES/NO・モーダルの後処理をマスタページ共通ハンドラに実装する** — 判別できない。
  画面コードクラスに書く
- **`SetDataToModalInterface` のデータを消さずに大きなまま残す** — メモリリークする
- **OK ダイアログに後処理を期待する** — 通知のみ。後処理があるのは YES/NO とモーダル
- **モジュール名（ダイアログの `.aspx`）を変えて `web.config` の `FxOKMessageDialogPath` /
  `FxYesNoMessageDialogPath` を直し忘れる** — ダイアログが開かない
