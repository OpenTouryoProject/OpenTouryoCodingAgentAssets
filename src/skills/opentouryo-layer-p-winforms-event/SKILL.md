---
name: opentouryo-layer-p-winforms-event
description: "OpenTouryo の P層（Windows Forms、リッチクライアント）でコントロールのイベント処理を実装する。コントロール名の接頭辞（FxPrefixOfButton 等、有効なのは6種だけ）によるイベントの自動結線、種別ごとに決まるハンドラのイベント名（ボタン・ピクチャボックス=Click / コンボボックス・リストボックス=SelectedIndexChanged / ラジオボタン・チェックボックス=CheckedChanged）、protected void ...(RcFxEventArgs) のシグネチャ（戻り値は void）、対応コントロールの拡張と未対応時のトレードオフを扱う。Windows Forms / WinForms / イベントハンドラ / 接頭辞 / 自動結線 / RcFxEventArgs / UOC_btnXXX_Click を伴う作業のときに使う。画面の新規作成は opentouryo-layer-p-winforms-screen、ハンドラ内での B層呼び出しと手動トランザクションは opentouryo-p-call-business を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層（Windows Forms）：イベント処理の実装

## このスキルの適用範囲

**コントロールのイベントハンドラ（UOC メソッド）を実装する。**

- 画面の新規作成 → `opentouryo-layer-p-winforms-screen`
- ハンドラの中身（B層の呼び出し・**2CS の手動トランザクション**）→ `opentouryo-p-call-business`
- 例外 → `opentouryo-exception`

## イベントは接頭辞で自動結線される

**Web Forms と同じ仕組み。** コントロール名の接頭辞（`FxPrefixOfButton` = `btn` など）を
設定から読み、コントロールツリーを走査してハンドラを結線し、UOC へレイトバインドする。

**接頭辞は命名規約ではなく機能。** 規約から外れた名前を付けるとイベントが発火しない。
設定は `app.config` の `appSettings`（`opentouryo-config` 参照）。

## 有効な接頭辞は6種だけ

**Web Forms（14種）より大幅に少ない。** 対応していないコントロールは自動結線されない。

**ハンドラ名のイベント名は、コントロール種別ごとに決まっている**（右列）。

| 設定キー | サンプルでの値 | コントロール | ハンドラのイベント名 |
| --- | --- | --- | --- |
| `FxPrefixOfButton` | `btn` | ボタン | `Click` |
| `FxPrefixOfComboBox` | `cbb` | コンボボックス | `SelectedIndexChanged` |
| `FxPrefixOfListBox` | `lbx` | リストボックス | `SelectedIndexChanged` |
| `FxPrefixOfRadioButton` | `rbn` | ラジオボタン | `CheckedChanged` |
| `FxPrefixOfPictureBox` | `pbx` | ピクチャボックス | `Click` |
| `FxPrefixOfCheckBox` | `cbx` | チェックボックス | `CheckedChanged` |

`FxPrefixOfComboBox` / `FxPrefixOfPictureBox` はリッチクライアント固有（Web Forms では未使用）。
逆に **`FxPrefixOfTextBox` / `FxPrefixOfGridView` などは結線されない**（Web Forms 専用）。

**値はプロジェクトごとに変えられる。** 上記はサンプルの値。既存コードと `app.config` を確認する。

**一覧は「フレームワーク既定」であって、このプロジェクトの全部とは限らない。**
対応コントロール・イベントは `MyBaseControllerWin`（親クラス2）の `addControlEvent` に実装を
足せば拡張できる（`CheckBox` 自体がその実例）。**拡張するのは纏め者**で、利用側は既存の対応を
使う。何に対応しているかは、提供されていれば `MyBaseControllerWin` の `addControlEvent` を
読んで確認する（`opentouryo-project-policy`）。

**対応していないコントロール・イベントは、.NET 標準のイベント処理（デザイナ結線、`+=`）でも
書ける。ただしその場合、フレームワークの例外処理（`UOC_ABEND`）とログ出力を通らない。**
土台に載せたいなら、親クラス2 での拡張（纏め者）を検討する。

<!--
  結線箇所は2つに分かれている（実装で確認済み）:
    BaseControllerWin（親クラス1）  … BUTTON / COMBO_BOX / LIST_BOX / RADIO_BUTTON / PICTURE_BOX
    MyBaseControllerWin（親クラス2）… CHECK_BOX（MyLiteral.PREFIX_OF_CHECK_BOX）
  親クラス2 で接頭辞を追加できる作りだが、バイナリ提供のため利用側では変更できない。
-->

## イベントハンドラのシグネチャ

**イベント名はコントロール種別で決まる**（上の接頭辞の表）。ボタン／ピクチャボックスは
`Click`、コンボボックス／リストボックスは `SelectedIndexChanged`、ラジオボタン／チェックボックスは
`CheckedChanged`。

```csharp
protected void UOC_btnButton1_Click(RcFxEventArgs rcFxEventArgs)
// コンボボックス cbbKind なら UOC_cbbKind_SelectedIndexChanged
```

| 要素 | Windows Forms | （参考）Web Forms |
| --- | --- | --- |
| 共通引数 | **`RcFxEventArgs`** | `FxEventArgs` |
| 戻り値 | **`void`** | `string`（遷移先 URL） |
| アクセス修飾子 | `protected` | `protected` |

**戻り値が `void`。** Web Forms は遷移先 URL を返すが、リッチクライアントに画面遷移が無いため。

レイトバインドで呼ばれるため、**シグネチャが違っても修飾子が `private` でも
コンパイルは通り、実行時に呼ばれないだけ。**

## ハンドラの中身は B層呼び出し

**イベントハンドラの本体は、引数クラスを組み立てて B層を呼ぶ。** 2CS はコミットが手動なので、
呼んだ後に `CommitAndClose()` を呼ぶ。手順は `opentouryo-p-call-business`。

```csharp
protected void UOC_btnButton1_Click(RcFxEventArgs rcFxEventArgs)
{
    // 引数クラスを組み立てて B層を呼ぶ（画面名は this.Name、
    // コントロール名は rcFxEventArgs.ControlName、ユーザ情報は static）
    // ★ 2CS はコミットが手動：LayerB.CommitAndClose()
    // 詳細は opentouryo-p-call-business
}
```

## やってはいけないこと

- **イベントハンドラの戻り値を `string` にする** — `void`。Web Forms とは違う
- **`FxEventArgs` を使う** — リッチクライアントは `RcFxEventArgs`
- **接頭辞の規約から外れたコントロール名を付ける** — 結線されずイベントが発火しない
- **イベント名を間違える** — 種別ごとに固定（コンボボックスは `_SelectedIndexChanged` 等）
- **イベントハンドラを `private` にする** — レイトバインドで呼ばれない。`protected` にする
- **未対応コントロールを標準結線して済ませる（気づかず例外処理・ログを失う）** — 失うものを
  承知の上でのみ。土台に載せたいなら親クラス2 での拡張（纏め者）
