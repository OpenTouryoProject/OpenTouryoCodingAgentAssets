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

## GridView の RowUpdating/RowDeleting/PageIndexChanging/Sorting だけ第2引数

```csharp
protected string UOC_gvwGridView_RowUpdating(FxEventArgs fxEventArgs, EventArgs e)
{
    return "";
}
```

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
| `PostBackValue` | イメージマップのホットスポット値・リピータ等のコマンド名 |

> B層呼び出しは `opentouryo-p-call-business`、接頭辞の自動結線拡張は `opentouryo-base2-customize`（addControlEvent）。
