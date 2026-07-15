---
name: opentouryo-layer-p-winforms
description: "OpenTouryo の P層を Windows Forms（リッチクライアント、2層クライアントサーバ）で実装する。画面コードクラス（MyBaseControllerWin の派生）、UOC メソッド（UOC_FormInit / UOC_FormEnd / UOC_btnXXX_Click）、RcFxEventArgs、コントロール名の接頭辞によるイベントの自動結線、static な MyBaseControllerWin.UserInfo によるユーザ情報の保持、B層（MyFcBaseLogic2CS）の呼び出しと手動トランザクション制御（CommitAndClose / RollbackAndClose）を扱う。Windows Forms / WinForms / リッチクライアント / 2CS / 2層C/S / デスクトップ画面 を伴う作業のときに使う。WPF は P層フレームワークを持たないため対象外（B層・D層のみ利用する）。Web Forms は opentouryo-layer-p-webforms、MVC は opentouryo-layer-p-mvc を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# P層（Windows Forms / 2層クライアントサーバ）

## このスキルの適用範囲

画面コードクラス（`Form` の派生）の実装と、**2層C/S 特有のトランザクション制御**。

- **WPF は対象外。** P層フレームワークを持たない（後述）
- Web Forms → `opentouryo-layer-p-webforms`、MVC → `opentouryo-layer-p-mvc`
- 例外 → `opentouryo-exception`、D層 → `opentouryo-layer-d`（Dao 3系統の使い分け）

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
| **`UOC_（コントロール名）_（イベント名）`** | **画面コードクラス** | 各コントロールのイベント処理 |

### Web Forms との違い

| | Web Forms | Windows Forms |
| --- | --- | --- |
| 親クラス2 | `MyBaseController`（**`abstract`**） | `MyBaseControllerWin`（**具象クラス**） |
| `UOC_FormInit` | `abstract` のまま → **実装必須** | 親クラス2 が**空実装済み** → override は任意 |
| 終了処理 | 無い | **`UOC_FormEnd` / `UOC_CMNFormEnd` がある** |
| ポストバック | `UOC_FormInit_PostBack` がある | **無い**（ポストバックの概念が無い） |
| 画面遷移 | `UOC_Screen_Transition` がある | **無い** |

`UOC_FormInit` は実装必須ではないが、サンプルは override している。既存コードに合わせる。

## イベントは接頭辞で自動結線される

**Web Forms と同じ仕組み。** コントロール名の接頭辞（`FxPrefixOfButton` = `btn` など）を
設定から読み、コントロールツリーを走査してハンドラを結線し、UOC へレイトバインドする。

**接頭辞は命名規約ではなく機能。** 規約から外れた名前を付けるとイベントが発火しない。
設定は `app.config` の `appSettings`（`opentouryo-config` 参照）。

### 有効な接頭辞は6種だけ

**Web Forms（14種）より大幅に少ない。** 対応していないコントロールは自動結線されない。

| 設定キー | サンプルでの値 | コントロール |
| --- | --- | --- |
| `FxPrefixOfButton` | `btn` | ボタン |
| `FxPrefixOfComboBox` | `cbb` | コンボボックス |
| `FxPrefixOfListBox` | `lbx` | リストボックス |
| `FxPrefixOfRadioButton` | `rbn` | ラジオボタン |
| `FxPrefixOfPictureBox` | `pbx` | ピクチャボックス |
| `FxPrefixOfCheckBox` | `cbx` | チェックボックス |

`FxPrefixOfComboBox` / `FxPrefixOfPictureBox` はリッチクライアント固有（Web Forms では未使用）。
逆に **`FxPrefixOfTextBox` / `FxPrefixOfGridView` などは結線されない**（Web Forms 専用）。

**値はプロジェクトごとに変えられる。** 上記はサンプルの値。既存コードと `app.config` を確認する。

<!--
  結線箇所は2つに分かれている（実装で確認済み）:
    BaseControllerWin（親クラス1）  … BUTTON / COMBO_BOX / LIST_BOX / RADIO_BUTTON / PICTURE_BOX
    MyBaseControllerWin（親クラス2）… CHECK_BOX（MyLiteral.PREFIX_OF_CHECK_BOX）
  親クラス2 で接頭辞を追加できる作りだが、バイナリ提供のため利用側では変更できない。
-->

## イベントハンドラのシグネチャ

```csharp
protected void UOC_btnButton1_Click(RcFxEventArgs rcFxEventArgs)
```

| 要素 | Windows Forms | （参考）Web Forms |
| --- | --- | --- |
| 共通引数 | **`RcFxEventArgs`** | `FxEventArgs` |
| 戻り値 | **`void`** | `string`（遷移先 URL） |
| アクセス修飾子 | `protected` | `protected` |

**戻り値が `void`。** Web Forms は遷移先 URL を返すが、リッチクライアントに画面遷移が無いため。

レイトバインドで呼ばれるため、**シグネチャが違っても修飾子が `private` でも
コンパイルは通り、実行時に呼ばれないだけ。**

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

## トランザクション制御が Web 系と違う

**ここが最大の違い。B層が `BaseLogic2CS` 系（2層C/S用）で、トランザクション方式が別物。**

### なぜ違うのか

**アプリケーションが Desktop 上のインスタンスとして動作するため、アプリごとの
グローバルな1トランザクションを使う設計。**

| | Web / MVC | 2層C/S |
| --- | --- | --- |
| 動作単位 | 1リクエスト | **1アプリケーション インスタンス** |
| トランザクションの単位 | **リクエストごと** | **アプリ全体で1つ** |
| なぜ | 複数の利用者・リクエストが同居するので分離が要る | 1プロセス = 1利用者。分ける必要がない |

この前提から、以下がすべて導かれる。**個別の仕様ではなく、1つの設計判断の帰結。**

- コネクションが `static`（グローバル）→ アプリ全体で1つだから
- コミットが手動 → いつ確定するかはアプリの操作単位が決めることだから
- 業務例外で自動ロールバックしない → **勝手に巻き戻すと、それまでの処理まで消えるから**

| | Web / MVC（`BaseLogic`） | **Windows Forms（`BaseLogic2CS`）** |
| --- | --- | --- |
| コネクション | 呼び出しごとに開いて閉じる | **グローバル（`static`）で使い回す** |
| 正常系のコミット | **フレームワークが自動** | **しない。手動で `CommitAndClose()`** |
| 業務例外のロールバック | **する** | **しない**（★ 後述） |
| システム例外のロールバック | する | する |
| その他の例外のロールバック | する | する |
| `UOC_AfterTransaction` | 呼ばれる | **呼ばれない** |

### コミットは手動

`BaseLogic2CS.DoBusinessLogic()` は**コミットしない**（実装でコメントアウトされている）。
B層を呼んだ後に**明示的に呼ぶ**。

```csharp
protected void UOC_btnButton1_Click(RcFxEventArgs rcFxEventArgs)
{
    TestParameterValue testParameterValue = new TestParameterValue(
        this.Name,                       // 画面名（Form の Name）
        rcFxEventArgs.ControlName,       // コントロール名
        "SelectCount",                   // メソッド名 → B層の UOC_SelectCount に振り分けられる
        actionType,
        MyBaseControllerWin.UserInfo);   // ユーザ情報（static）

    DbEnum.IsolationLevelEnum iso = this.SelectIsolationLevel();

    // Ｂ層呼出し＋都度コミット
    LayerB layerB = new LayerB();
    TestReturnValue testReturnValue = (TestReturnValue)layerB.DoBusinessLogic(testParameterValue, iso);
    LayerB.CommitAndClose();   // ★ 明示的にコミットする

    if (testReturnValue.ErrorFlag)
    {
        // 業務例外（opentouryo-exception 参照）
    }
}
```

`BaseLogic2CS` の `static` メソッド。

| メソッド | 内容 |
| --- | --- |
| `CommitAndClose()` | コミットしてコネクションを閉じる |
| `RollbackAndClose()` | ロールバックしてコネクションを閉じる |
| `ConnectionClose()` | コネクションを閉じる |

**コネクションがグローバルなので、複数の B層呼び出しを1トランザクションにまとめられる。**
その代わり、閉じ忘れるとコネクションが残り続ける。

`NoTransaction` を指定した場合だけ、`finally` で都度コネクションが閉じられる。

### 業務例外でロールバックされない

**`opentouryo-exception` は「どの型の例外でもフレームワークが自動的にロールバックする」と
書いているが、それは `BaseLogic`（Web / MVC）の話。**

`BaseLogic2CS` の実装にはこうある。

```csharp
catch (BusinessApplicationException baEx)// 業務例外
{
    // ★★業務例外時のロールバックは自動にしない。
    ...
}
```

**アプリ全体で1トランザクションなので、フレームワークが勝手にロールバックできない。**
業務例外は「利用者がやり直せるエラー」なので、そこで巻き戻すと、それまでに積み上げた
処理まで消えてしまう。

**業務例外を検知したら、続行するのかロールバックするのかを自分で判断する。**

```csharp
if (testReturnValue.ErrorFlag)
{
    // 業務例外。入力し直させて続行するなら、ロールバックしない
    // 取り消すなら明示的に呼ぶ
    LayerB.RollbackAndClose();
}
```

システム例外・その他の例外で自動ロールバックするのは、**業務を続行できないため**
（`opentouryo-exception` の型の選択基準を参照）。ここは判断の余地がない。

## B層の呼び出し

| 引数クラスの項目 | Windows Forms | （参考）Web Forms | （参考）MVC |
| --- | --- | --- | --- |
| 画面名 | `this.Name`（Form の Name） | `this.ContentPageFileNoEx` | `this.ControllerName` |
| コントロール名 | `rcFxEventArgs.ControlName` | `fxEventArgs.ButtonID` | `"-"`（固定） |
| メソッド名 | **文字列リテラルで明示** | 文字列リテラルで明示 | `this.ActionName`（自動） |
| ユーザ情報 | `MyBaseControllerWin.UserInfo`（**static**） | `this.UserInfo` | `this.UserInfo` |

B層のクラスは `MyFcBaseLogic2CS` を継承する（`MyFcBaseLogic` ではない）。
**`MyBaseLogic2CS` は非推奨。**

### B層の書き方そのものは Web / MVC と同じ

**違うのはトランザクション制御だけ。** 業務コードクラスの書き方は `opentouryo-layer-b` が
そのまま通用する。

| | Web / MVC | 2層C/S | |
| --- | --- | --- | --- |
| 継承元 | `MyFcBaseLogic` | `MyFcBaseLogic2CS` | **違う** |
| 自動振り分け | `Latebind.InvokeMethod(this, "UOC_" + MethodName, ...)` | 同じ | 同じ |
| UOC のシグネチャ | `private void UOC_XXX(パラメータ値クラス)` | 同じ | 同じ |
| 戻り値 | `this.ReturnValue` に事前設定 | 同じ | 同じ |
| 直呼びガード | `WasCalledFromDoBusinessLogic` | 同じ | 同じ |
| トランザクション | フレームワークが自動 | **手動**（前述） | **違う** |

したがって `opentouryo-layer-b` を読むときは、**継承元とトランザクションの2点だけ
読み替える**。それ以外はそのまま当てはまる。

## やってはいけないこと

- **WPF でこのスキルを使う** — WPF は P層フレームワークを持たない。B層・D層のみ利用する
- **`UserInfoHandle` を使う** — Web 系の仕組み。`MyBaseControllerWin.UserInfo`（static）を使う
- **B層を呼んだ後 `CommitAndClose()` を呼び忘れる** — **自動コミットされない**。
  Web / MVC の感覚で書くと更新が確定しない
- **業務例外時に自動ロールバックされると考える** — `BaseLogic2CS` は業務例外でロールバックしない。
  自分で `RollbackAndClose()` を判断する
- **イベントハンドラの戻り値を `string` にする** — `void`。Web Forms とは違う
- **`FxEventArgs` を使う** — リッチクライアントは `RcFxEventArgs`
- **接頭辞の規約から外れたコントロール名を付ける** — 結線されずイベントが発火しない
- **イベントハンドラを `private` にする** — レイトバインドで呼ばれない。`protected` にする
- **`MyBaseLogic2CS` を継承する** — 非推奨。`MyFcBaseLogic2CS` を使う
