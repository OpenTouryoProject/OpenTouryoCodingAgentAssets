---
name: opentouryo-layer-p-winforms-screen
description: "OpenTouryo の P層を Windows Forms（リッチクライアント、2層クライアントサーバ）で新規作成する。画面コードクラス（Form の派生、MyBaseControllerWin の派生）の作り方、クラス階層（BaseControllerWin / MyBaseControllerWin）、ページ初期化・終了の UOC メソッド（UOC_FormInit / UOC_FormEnd）と UOC_CMN 系との分界、Web Forms との差（親クラス2 が具象・ポストバックや画面遷移が無い）、static な MyBaseControllerWin.UserInfo によるユーザ情報の保持とログイン画面を扱う。Windows Forms / WinForms / リッチクライアント / 2CS / 2層C/S / デスクトップ画面 / フォーム作成 を伴う作業のときに使う。コントロールのイベント実装は opentouryo-layer-p-winforms-event、B層呼び出しと手動トランザクションは opentouryo-p-call-business を使う。WPF は P層フレームワークを持たないため対象外。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層（Windows Forms / 2層クライアントサーバ）：画面の新規作成

> 📋 **コピー元スニペット**：`references/snippets.md`（Form 骨格・UOC_FormInit・6接頭辞・static UserInfo。実装時はここから写す）。

## このスキルの適用範囲

**画面コードクラス（`Form` の派生）を新規に作る。**

- コントロールのイベント実装 → `opentouryo-layer-p-winforms-event`
- B層の呼び出しと **2CS の手動トランザクション** → `opentouryo-p-call-business`
- Web Forms → `opentouryo-layer-p-webforms-screen`、MVC → `opentouryo-layer-p-mvc`
- 例外 → `opentouryo-exception`、D層 → `opentouryo-layer-d`

**このスキルは Web 系と前提が大きく違う。** Web 系のスキルの記述をそのまま持ち込まないこと。

## WPF は P層フレームワークを持たない

`MyBaseControllerWin` は `Form` を継承しているため、WPF の `Window` では使えない。
WPF は **B層・D層のみを利用**し、画面は素の WPF として実装する。

サンプル（`2CSClientWPF_sample`）も `Window1 : Window` で、UOC が出てくるのは
`Business/LayerB.cs`（B層）だけ。

## 実装場所

| 階層 | クラス | 修正 |
| --- | --- | --- |
| 画面コード親クラス1 | `BaseControllerWin`（`Touryo.Infrastructure.Framework.RichClient.Presentation`。`Form` を継承） | **不可**（バイナリ提供） |
| 画面コード親クラス2 | `MyBaseControllerWin`（`Touryo.Infrastructure.Business.RichClient.Presentation`） | **不可**（バイナリ提供） |
| 画面コードクラス | `MyBaseControllerWin` を継承した `Form` | **可**（ここに実装する） |

```csharp
public partial class Form1 : MyBaseControllerWin
```

## UOC メソッドの分界

**`CMN` が付くものは親クラス2 の共通処理。** Web Forms と同じ命名体系。

| UOC メソッド | 実装場所 | 内容 |
| --- | --- | --- |
| `UOC_CMNFormInit` / `UOC_CMNAfterFormInit` | 親クラス2 | 全画面共通の初期処理（前・後） |
| `UOC_CMNFormEnd` / `UOC_CMNAfterFormEnd` | 親クラス2 | 全画面共通の終了処理（前・後） |
| `UOC_PreAction` / `UOC_AfterAction` / `UOC_Finally` | 親クラス2 | イベント処理の前後 |
| `UOC_ABEND`（3種） | 親クラス2 | 例外処理 |
| **`UOC_FormInit`** | **画面コードクラス** | フォームの初期処理 |
| **`UOC_FormEnd`** | **画面コードクラス** | フォームの終了処理 |
| **`UOC_（コントロール名）_（イベント名）`** | **画面コードクラス** | 各コントロールのイベント処理（→ `opentouryo-layer-p-winforms-event`） |

### Web Forms との違い

| | Web Forms | Windows Forms |
| --- | --- | --- |
| 親クラス2 | `MyBaseController`（**`abstract`**） | `MyBaseControllerWin`（**具象クラス**） |
| `UOC_FormInit` | `abstract` のまま → **実装必須** | 親クラス2 が**空実装済み** → override は任意 |
| 終了処理 | 無い | **`UOC_FormEnd` / `UOC_CMNFormEnd` がある** |
| ポストバック | `UOC_FormInit_PostBack` がある | **無い**（ポストバックの概念が無い） |
| 画面遷移 | `UOC_Screen_Transition` がある | **無い** |

`UOC_FormInit` は実装必須ではないが、サンプルは override している。既存コードに合わせる。

## ユーザ情報は static

**Web 系とまったく違う。セッションも `UserInfoHandle` も使わない。**

```csharp
// MyBaseControllerWin.cs
protected static MyUserInfo UserInfo = new MyUserInfo("－", Environment.MachineName);
```

- **`static` フィールド**でプロセス内に保持する
- **`UserInfoHandle` は使わない**（リッチクライアント配下に使用箇所は0件）
- **.NET の認証機構（Forms 認証 / Cookie 認証）も使わない**。ログインはアプリ内で完結する
- `IPAddress` には `Environment.MachineName`（IP ではなくマシン名）を入れる

### ログイン画面

```csharp
public partial class Login : MyBaseControllerWin
{
    protected override void UOC_FormInit() { }

    protected void UOC_btnButton1_Click(RcFxEventArgs rcFxEventArgs)
    {
        // static フィールドに直接設定する
        MyBaseControllerWin.UserInfo.UserName  = this.textBox1.Text;
        MyBaseControllerWin.UserInfo.IPAddress = Environment.MachineName;

        Program.FlagEnd = false;
        this.Close();
    }
}
```

`opentouryo-auth`（`UserInfoHandle` + セッション）は **Web 系の話**。このスキルには適用しない。

## B層の呼び出しは別スキル

B層の呼び出しと、**2CS 特有の手動トランザクション制御**（`CommitAndClose` /
`RollbackAndClose`、業務例外で自動ロールバックしない）は `opentouryo-p-call-business` を参照。
イベントハンドラの書き方は `opentouryo-layer-p-winforms-event`。

## やってはいけないこと

- **WPF でこのスキルを使う** — WPF は P層フレームワークを持たない。B層・D層のみ利用する
- **`UserInfoHandle` を使う** — Web 系の仕組み。`MyBaseControllerWin.UserInfo`（static）を使う
- **親クラス1・親クラス2 を修正する** — バイナリ提供。画面コードクラスに実装する
- **`opentouryo-auth` のセッション／認証チケットの話を持ち込む** — リッチクライアントは
  static なユーザ情報で、.NET の認証機構を使わない
