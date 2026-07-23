# P層 ASP.NET MVC コードスニペット（コピー元）

出典：`Samples/WebApp_sample/MVC_Sample/.../Controllers/Crud1Controller.cs`（実ソース）で裏取り／UserGuide。**on-demand 参照**（SKILL 予算外）。
MVC は **UOC メソッドを持たない**（標準のアクションメソッド）。net48＝`MyBaseMVController`、net10.0＝`MyBaseMVControllerCore`。

## コントローラとアクション（Core）

```csharp
public class Crud1Controller : MyBaseMVControllerCore   // net48 は : MyBaseMVController
{
    public ActionResult Index(CrudViewModel model)
    {
        return View(model);
    }

    [HttpPost]
    public async Task<IActionResult> SelectCount(CrudViewModel model) // net48 は Task<ActionResult>
    {
        // 引数クラスを生成
        TestParameterValue pv = new TestParameterValue(
            this.ControllerName,   // screenId 相当
            this.ActionName,       // controlId 相当
            "SelectCount",         // methodName（B層の UOC_SelectCount）
            "SQL",                 // actionType（先頭[0]=DBMS）
            this.UserInfo);

        // B層を非同期呼び出し（分離レベルは画面の選択値から）
        LayerB layerB = new LayerB();
        TestReturnValue rv = (TestReturnValue)await layerB.DoBusinessLogicAsync(
            pv, this.SelectIsolationLevel(model.DdlIso));

        // 戻り値判定
        if (rv.ErrorFlag)
        {
            model.Message = rv.ErrorMessageID + " / " + rv.ErrorMessage;
        }
        else
        {
            model.Result = rv.Obj?.ToString();
        }

        return View(model);
    }
}
```

## net48 と Core の差

| | net48 | net10.0 (Core) |
| --- | --- | --- |
| 基底 | `MyBaseMVController` | `MyBaseMVControllerCore` ＋ `[MyMVCCoreFilter()]` 属性 |
| 例外/ログ | 基底が `View()` 等を override | フィルタ（`MyMVCCoreFilterAttribute`）で処理 |
| 認証 | Forms 認証 | Cookie 認証（`Startup` で構成） |

## プロパティ

- `this.ControllerName` / `this.ActionName`：フィルタが設定するコントローラ/アクション名。
- `this.UserInfo`：ユーザ情報。
- `this.SelectIsolationLevel(...)`：分離レベル。

> 引数クラスの組み立て・`DoBusinessLogic(Async)`・`ErrorFlag` の共通手順は `opentouryo-p-call-business`。
> Core は `Startup` で `services._AddHttpContextAccessor()` / `app._UseHttpContextAccessor()` 必須（`opentouryo-config`）。
