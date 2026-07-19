---
name: opentouryo-richclient-async
description: "OpenTouryo のリッチクライアント（Windows Forms / WPF デスクトップ）から B層を非同期に呼び出す。MyBaseAsyncFunc（Touryo.Infrastructure.Business.RichClient.Asynchronous）を使い、af.Parameter に引数を渡し、af.AsyncFunc デリゲートで副スレッド側の処理（CallController.Invoke / DoBusinessLogic による B層呼び出し）を、af.SetResult デリゲートで主スレッド側の結果表示（UI 更新）を実装し、af.Start() / StartByThreadPool() で起動する。副スレッドは画面メンバに触れない・主スレッドは UI 更新できる、という分界、画面ロックとスレッド数管理、業務例外（ErrorFlag）と例外（retVal is Exception）の受け取りを扱う。非同期呼び出し / 非同期 / 別スレッド / UI をブロックしない / MyBaseAsyncFunc / AsyncFunc / SetResult / リッチクライアント / WinForms / WPF で B層を非同期に呼ぶ 作業のときに使う。同期呼び出しは opentouryo-p-call-business。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# リッチクライアントの非同期呼び出し

## このスキルの適用範囲

**デスクトップ（Windows Forms / WPF）で、UI を固めずに B層を呼ぶ。**
`MyBaseAsyncFunc` を使う。

- 同期呼び出し → `opentouryo-p-call-business`
- 画面・イベント → `opentouryo-layer-p-winforms-screen` / `-event`（WPF は素の `Window`）

**リッチクライアントの唯一の非同期手段。** 2層C/S（`BaseLogic2CS`）には `DoBusinessLogicAsync`
が無い（`opentouryo-p-call-business`）。長い処理で UI を固めたくないときはこれを使う。
**WPF はこれを使える**（WPF は P層フレームワークを持たないが、非同期呼び出しは別機構）。

## 副スレッドと主スレッドの分界（最重要）

```
af.AsyncFunc  … 副スレッドで走る。★画面メンバに触らない。B層を呼ぶのはここ
af.SetResult  … 主スレッドで走る。★UI を更新できる。結果表示はここ
```

**この2つを取り違えると、UI 更新が反映されない／クロススレッド例外になる。**

## 実装パターン

イベントハンドラ（Form / Window）に書く。**`this` は Form / Window。**

```csharp
protected void UOC_btnButton1_Click(RcFxEventArgs rcFxEventArgs)
{
    // ① 非同期処理オブジェクトを生成（this = Form / Window）
    MyBaseAsyncFunc af = new MyBaseAsyncFunc(this);

    // ② 引数を渡す。画面上のデータはここ（主スレッド）で退避する（オブジェクトはクローン）
    af.Parameter = new TestParameterValue(
        this.Name, rcFxEventArgs.ControlName, "SelectCount", actionType,
        MyBaseControllerWin.UserInfo);
    string logicalName = ((ComboBoxItem)this.ddlSvc.SelectedItem).Value;  // UI 値を退避

    // ③ 副スレッドで走る処理（★画面メンバに触らない）
    af.AsyncFunc = delegate(object param)
    {
        TestParameterValue pv = (TestParameterValue)param;

        // CallController はスレッドセーフでないので副スレッド内で生成する
        CallController callCtrl = new CallController(MyBaseControllerWin.UserInfo);
        TestReturnValue rv = (TestReturnValue)callCtrl.Invoke(logicalName, pv);
        return rv;   // 戻り値は SetResult へ渡る
    };

    // ④ 主スレッドで走る結果表示（★UI を更新できる）
    af.SetResult = delegate(object retVal)
    {
        if (retVal is Exception)
        {
            RcMyCmnFunction.ShowErrorMessageWin((Exception)retVal, "非同期処理で例外発生");
            return;
        }
        TestReturnValue rv = (TestReturnValue)retVal;
        if (rv.ErrorFlag)
        {
            this.labelMessage.Text = rv.ErrorMessage;   // 業務例外（opentouryo-exception）
        }
        else
        {
            this.labelMessage.Text = rv.Obj.ToString();
        }
    };

    // ⑤ 起動。別の非同期処理が実行中なら false
    if (!af.Start())
    {
        MessageBox.Show("別の非同期処理が実行中です。");
    }
}
```

`using Touryo.Infrastructure.Business.RichClient.Asynchronous;`（`MyBaseAsyncFunc`）。
B層呼び出しはローカルなら `DoBusinessLogic`、3層（Web サービス越し）なら
`CallController.Invoke`（`opentouryo-transmission`）。上の例は 3層（`CallController.Invoke`）。
**リモート呼び出しは net48 専用**（`net10.0` では未実装。`opentouryo-transmission` 参照）なので、
core のデスクトップでは非同期処理の中身をローカルの `DoBusinessLogic` にする。

## 結果と例外の受け取り

`SetResult` の引数 `retVal` に、`AsyncFunc` の戻り値か**発生した例外**が入る。

| `retVal` | 意味 |
| --- | --- |
| 戻り値クラス（`ErrorFlag = false`） | 正常 |
| 戻り値クラス（`ErrorFlag = true`） | 業務例外（`opentouryo-exception`） |
| `Exception` | システム例外・その他の例外 |

**`retVal is Exception` を必ず判定する。** 副スレッドで出た例外はここに渡ってくる。

## 起動と画面ロック

| メソッド | 内容 |
| --- | --- |
| `af.Start()` | 非同期実行を開始。**別の非同期処理が実行中なら `false`** |
| `af.StartByThreadPool()` | スレッドプールで実行するバリアント |

**画面ロックとスレッド数管理をフレームワークが行う。** 実行中は画面がロックされ、
`Start()` は多重起動を弾く。スレッド数は `app.config` に定義する。

進捗表示は `af.ExecChangeProgress(...)`、非同期メッセージボックスは
`af.ShowAsyncMessageBoxWin(...)` / `ShowAsyncMessageBoxWPF(...)`。

## 派生クラスに処理を書く方法

`AsyncFunc` を匿名デリゲートではなくクラスに書くこともできる
（`MyBaseAsyncFunc` を継承。メンバ変数を引数代わりに使える。VB は匿名関数が使えないのでこちら）。

```csharp
public class AsyncFunc : MyBaseAsyncFunc
{
    public AsyncFunc(object _this) : base(_this) { }
    public string LogicalName = "";
    public object Exec(object param) { /* 副スレッドの処理 */ }
}
// 呼び出し側
AsyncFunc af = new AsyncFunc(this);
af.AsyncFunc = new BaseAsyncFunc.AsyncFuncDelegate(af.Exec);
```

派生クラス内では `this.thisWinForm` / `this.thisWPF` でコントロールを参照できる。

## やってはいけないこと

- **`AsyncFunc`（副スレッド）で画面メンバに触る** — クロススレッドになる。UI 値は主スレッドで
  退避してから渡す（オブジェクトはクローンする）
- **UI 更新を `SetResult` 以外に書く** — 結果表示・フォーカス移動は `SetResult`（主スレッド）で
- **`CallController` を主スレッドで作って副スレッドで使い回す** — スレッドセーフでない。
  `AsyncFunc` 内で生成する
- **`SetResult` で `retVal is Exception` を判定しない** — 副スレッドの例外を取りこぼす
- **`Start()` の戻り値を無視する** — `false` は多重起動（別の非同期処理が実行中）
- **`UOC_Finally`（非同期側の最終処理）内で `Control.Invoke` / `Dispatcher.Invoke`（同期）を呼ぶ**
  — デッドロックの原因（クリティカルセクション内のため）
