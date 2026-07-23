---
name: opentouryo-layer-p-webforms-event
description: "OpenTouryo の P層（ASP.NET Web Forms）でコントロールのイベント処理を実装する。コントロール名の接頭辞（FxPrefixOfButton = btn 等）によるイベントの自動結線、種別ごとに決まるハンドラのイベント名（ボタン=Click / テキストボックス=TextChanged / ドロップダウン=SelectedIndexChanged / チェックボックス=CheckedChanged など）、UOC メソッドの命名規約（コンテンツページ / マスタページ / Web ユーザコントロールで変わる）、protected string ...(FxEventArgs) のシグネチャ、GridView の EventArgs 追加引数、FxEventArgs のプロパティ、対応コントロールの拡張と未対応時のトレードオフを扱う。イベントハンドラ / ボタン / 接頭辞 / 自動結線 / UOC_btnXXX_Click / ポストバック / コントロール を伴う作業のときに使う。画面の新規作成は opentouryo-layer-p-webforms-screen、ハンドラ内での B層呼び出しは opentouryo-p-call-business を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層（Web Forms）：イベント処理の実装

> 📋 **コピー元スニペット**：`references/snippets.md`（UOC 命名表・シグネチャ・GridView 2引数・FxEventArgs プロパティ。実装時はここから写す）。

## このスキルの適用範囲

**コントロールのイベントハンドラ（UOC メソッド）を実装する。**

- 画面の新規作成 → `opentouryo-layer-p-webforms-screen`
- ハンドラの中身（B層の呼び出し）→ `opentouryo-p-call-business`
- 例外 → `opentouryo-exception`

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

## 接頭辞の一覧とイベント名

**接頭辞は設定ファイル（`app.config` の `appSettings`）で定義する。**
未設定の種類は**結線されない**（`if (!string.IsNullOrEmpty(prefix))` で分岐している）。

**ハンドラ名のイベント名は、コントロール種別ごとに決まっている**（右列）。
`_Click` はボタン系だけ。他は種別ごとに違うので、間違えると結線されない。

| 設定キー | サンプルでの値 | コントロール | ハンドラのイベント名 |
| --- | --- | --- | --- |
| `FxPrefixOfButton` | `btn` | ボタン | `Click` |
| `FxPrefixOfLinkButton` | `lbn` | リンクボタン | `Click` |
| `FxPrefixOfImageButton` | `ibn` | イメージボタン | `Click` |
| `FxPrefixOfImageMap` | `imp` | イメージマップ | `Click` |
| `FxPrefixOfTextBox` | `txt` | テキストボックス | `TextChanged` |
| `FxPrefixOfDropDownList` | `ddl` | ドロップダウンリスト | `SelectedIndexChanged` |
| `FxPrefixOfListBox` | `lbx` | リストボックス | `SelectedIndexChanged` |
| `FxPrefixOfRadioButton` | `rbn` | ラジオボタン | `CheckedChanged` |
| `FxPrefixOfRadioButtonList` | `rbl` | ラジオボタンリスト | `SelectedIndexChanged` |
| `FxPrefixOfCheckBox` | `cbx` | チェックボックス | `CheckedChanged` |
| `FxPrefixOfCheckBoxList` | `cbl` | チェックボックスリスト | `SelectedIndexChanged` |
| `FxPrefixOfRepeater` | `rpt` | リピータ | `ItemCommand` |
| `FxPrefixOfGridView` | `gvw` | グリッドビュー | `RowCommand` / `SelectedIndexChanged` / `RowUpdating` / `RowDeleting` / `PageIndexChanging` / `Sorting` |
| `FxPrefixOfListView` | `lvw` | リストビュー | `OnItemCommand` / `SelectedIndexChanged` / `ItemUpdating` / `ItemDeleting` / `PagePropertiesChanged` / `Sorting` |

例：`ddl` のドロップダウンリスト `ddlKind` なら `UOC_ddlKind_SelectedIndexChanged`。
`txt` のテキストボックスなら `UOC_txtName_TextChanged`。

**値はプロジェクトごとに変えられる。** 上記はサンプルの値。既存コードと設定ファイルを確認する。

**一覧は「フレームワーク既定」であって、このプロジェクトの全部とは限らない。**
対応コントロール・イベントは `MyBaseController`（親クラス2）の `addControlEvent` に実装を足せば
拡張できる（`CheckBox` 自体がその方法で親クラス2 に追加された実例）。**拡張するのは纏め者**で、
利用側は既存の対応を使う。このプロジェクトで何に対応しているかは、提供されていれば
`MyBaseController` の `addControlEvent` を読んで確認する（`opentouryo-project-policy`）。

**対応していないコントロール・イベントは、.NET 標準のイベント処理（`.aspx` の `OnClick`、
コードビハインドの `+=`）でも書ける。ただしその場合、フレームワークの例外処理
（`UOC_ABEND` による振替・共通エラー画面）とアクセスログ出力を通らない。**
土台に載せたいなら、親クラス2 での拡張（纏め者）を検討する。

`FxPrefixOfComboBox` / `FxPrefixOfPictureBox` はリッチクライアント専用で、**Web Forms では
結線されない**（`opentouryo-layer-p-winforms-event` 参照）。`FxPrefixOfCommand` は定数が定義
されているだけで、実装では使われていない（ASP.NET Mobile Web の名残と見られる）。

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

`（イベント名）` はコントロール種別で決まる（上の接頭辞の表）。

具体例（`UOC_btnButton1_Click`／`UOC_sampleScreen_btnMButton1_Click`／`UOC_sampleControl1_btnUCButton_Click`）は
`references/snippets.md`。

同じユーザコントロールを2つ置いた場合、**ID が違えばハンドラも別**になる
（`UOC_sampleControl1_btnUCButton_Click` と `UOC_sampleControl2_btnUCButton_Click`）。

## シグネチャ

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

## ハンドラの中身は B層呼び出し

**イベントハンドラの本体は、たいてい引数クラスを組み立てて B層を呼ぶ。**
手順は `opentouryo-p-call-business`。

```csharp
protected string UOC_btnButton1_Click(FxEventArgs fxEventArgs)
{
    // 引数クラスを組み立てて B層を呼ぶ（→ opentouryo-p-call-business）
    // 業務例外は戻り値の ErrorFlag で受ける（→ opentouryo-exception）
    return string.Empty;   // 遷移しないなら空文字列
}
```

## やってはいけないこと

- **対応済みのコントロールを `.aspx` の `OnClick` 等で結線する** — フレームワークが接頭辞で
  自動結線する。標準結線するとフレームワークの例外処理・ログを通らない（未対応の場合のみ、
  失うものを承知で使う）
- **接頭辞の規約から外れたコントロール名を付ける** — 命名規約ではなく機能。
  結線されずイベントが発火しない
- **イベント名を間違える** — 種別ごとに固定（ドロップダウンは `_SelectedIndexChanged` 等）。
  `_Click` は万能ではない
- **イベントハンドラを `private` にする** — レイトバインドで呼ばれるため `protected` にする。
  コンパイルは通り、実行時に呼ばれないだけ
- **イベントハンドラの戻り値を `void` にする** — `string`（遷移先 URL）。遷移しないなら
  `string.Empty` を返す
- **コントロール名をページ・マスタページ・ユーザコントロールを跨いで重複させる** —
  ASP.NET としては問題ないが、P層フレームワークのイベント処理機能が許可しない
- **マスタページ上のコントロールのハンドラに接頭辞（ファイル名）を付け忘れる** —
  `UOC_（マスタページのファイル名）_（コントロール名）_（イベント名）`
