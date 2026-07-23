# 親クラス2 カスタマイズ コードスニペット（コピー元）

出典：UserGuide 纏め者編 §3-§7、`Frameworks/Infrastructure/Business/**`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。
親クラス2 は override して共通処理を注入する。**アプリ側は触らない**（`opentouryo-project-policy`）。

## B層：MyFcBaseLogic の UOC 群

```csharp
public abstract class MyFcBaseLogic : BaseLogic
{
    // DB 初期化（DAM 生成・接続・分離レベル・Tx 開始）＝実装必須
    protected override void UOC_ConnectionOpen(BaseParameterValue pv, DbEnum.IsolationLevelEnum iso)
    {
        // actionType の先頭[0]で DBMS を選ぶ（#if でランタイム別。OLE/ODB/ODP=net48、NPS=core）
        BaseDam dam;
        switch (pv.ActionType.Split('%')[0])
        {
            case "SQL": dam = new DamSqlSvr(); break;
            case "ODP": dam = new DamManagedOdp(); break;   // 使わない DBMS は csproj 参照ごと外す
            default:    dam = new DamSqlSvr(); break;
        }
        dam.ConnectionOpen(GetConfigParameter.GetConnectionString("ConnectionString_SQL"));
        if (iso == DbEnum.IsolationLevelEnum.User)
            iso = DbEnum.IsolationLevelEnum.DefaultTransaction; // User の振替先（プロジェクト依存）
        dam.BeginTransaction(iso);
        this.SetDam(dam);
    }

    // 前後処理・Tx 後処理（アクセスログ・性能測定など）
    protected override void UOC_PreAction(BaseParameterValue pv) { }
    protected override void UOC_AfterAction(BaseParameterValue pv, BaseReturnValue rv) { }
    protected override void UOC_AfterTransaction(BaseParameterValue pv, BaseReturnValue rv) { }

    // 業務処理の自動振り分け（methodName → UOC_〈methodName〉 をレイトバインド）
    protected override void UOC_DoAction(BaseParameterValue pv, ref BaseReturnValue rv)
    {
        string methodName = "UOC_" + pv.MethodName;
        try { Latebind.InvokeMethod(this, methodName, new object[] { pv }); }
        catch (System.Reflection.TargetInvocationException ex)
        {
            this.OriginalStackTrace = ex.InnerException.StackTrace;
            throw ex.InnerException;
        }
        finally { rv = this.ReturnValue; }  // レイトバインドは戻り値を取りこぼすためメンバで戻す
    }

    // 例外処理（3オーバーロード）。業務例外=リスローしない／システム・一般=リスロー（一般は振替可）
    protected override void UOC_ABEND(BaseParameterValue pv, BaseReturnValue rv, BusinessApplicationException baEx) { }
    protected override void UOC_ABEND(BaseParameterValue pv, BaseReturnValue rv, BusinessSystemException bsEx) { }
    protected override void UOC_ABEND(BaseParameterValue pv, ref BaseReturnValue rv, Exception ex)
    {
        // 一般例外→業務例外に振替（ErrorFlag）or システム例外に振替（throw）or そのまま throw
        rv.ErrorFlag = true; rv.ErrorMessageID = "..."; rv.ErrorMessage = "..."; rv.ErrorInfo = "-";
    }
}
```

> ★ 2CS は別クラス `MyFcBaseLogic2CS : BaseLogic2CS`（同名 UOC を持つ）＋**別 sln ビルド**。DBMS 分岐等は
> deprecated 双子 `MyBaseLogic`/`MyBaseLogic2CS` にも重複＝DLL から消すなら4クラス全部直す（SKILL 本文）。

## D層：MyBaseDao の UOC

```csharp
public abstract class MyBaseDao : BaseDao
{
    protected override void UOC_PreQuery() { }                       // SQL 実行前
    protected override void UOC_AfterQuery(string sql) { }           // 正常時（SQLトレース等）
    protected override void UOC_AfterQuery(string sql, Exception ex) { } // 異常時（エラーログ・振替）
}
```

## P層：MyBaseController（Web Forms）の UOC

```csharp
public abstract class MyBaseController : BaseController
{
    protected override void UOC_CMNFormInit() { }             // 初回（認証・権限・閉塞・タイトル・ログ）
    protected override void UOC_CMNFormInit_PostBack() { }    // ポストバック
    protected override void UOC_PreAction(FxEventArgs e) { }
    protected override void UOC_AfterAction(FxEventArgs e) { }
    protected override void UOC_Screen_Transition(string url) // 画面遷移方式を統一
    {
        if (url == "") return;
        if (MyBaseController.TransitionMethod == FxLiteral.OFF) this.FxTransfer(url);
        else this.ScreenTransition(url);
    }
    // 例外3オーバーロード（業務=表示、システム/一般=共通エラー画面 TransferErrorScreen）
    protected override void UOC_ABEND(BusinessApplicationException baEx, FxEventArgs e) { }
    protected override void UOC_ABEND(BusinessSystemException bsEx, FxEventArgs e) { }
    protected override void UOC_ABEND(Exception ex, FxEventArgs e) { }
}
```

WinForms は `MyBaseControllerWin`（例外は `RcFxEventArgs` 付き3オーバーロード）、Web API は
`MyBaseAsyncApiController`（±Core）、非同期は `MyBaseAsyncFunc`（`UOC_Pre/After/ABEND/Finally`）。

## P層イベント対応コントロールの追加（addControlEvent）

```csharp
// 「ページ ロード処理」から呼ぶ。集約イベントハンドラを接頭辞に結線する
private void addControlEvent()
{
    // 最新版は GetCtrlAndSetClickEventHandler2（Dictionary<接頭辞, ハンドラ>）
    Dictionary<string, object> map = new Dictionary<string, object>();
    string prefix = GetConfigParameter.GetConfigValue(MyLiteral.PREFIX_OF_CHECK_BOX);
    if (!string.IsNullOrEmpty(prefix))
        map.Add(prefix, new System.EventHandler(this.Check_CheckedChanged));
    MyCmnFunction.GetCtrlAndSetClickEventHandler2(this, map, this.ControlHt);
}

// コントロール種別ごとの集約イベントハンドラ（既定にない種別を足すとき）
protected void Check_CheckedChanged(object sender, System.EventArgs e)
{
    FxEventArgs fx = new FxEventArgs(((Control)sender).ID, 0, 0, "",
        this.GetMethodName(((Control)sender).ID, FxLiteral.UOC_METHOD_FOOTER_CHECKED_CHANGED));
    this.CMN_Event_Handler(fx);   // 以降はフレームワークが処理
}
```

## 例外メッセージ定数クラス

```csharp
namespace Touryo.Infrastructure.Business.Exceptions
{
    public class MyBusinessApplicationExceptionMessage
    {
        public static readonly string[] SAMPLE_ERROR =
            new string[] { "MessageID_SampleError", "Message_SampleError" };
    }
}
```

## 引数/戻り値の親クラス2（B/D層を跨ぐ持ち回り）

```csharp
[Serializable()]  // ★ WS 転送のため外さない
public class MyParameterValue : BaseParameterValue
{
    private MyUserInfo _user;
    public MyParameterValue(string screenId, string controlId, string methodName, string actionType, MyUserInfo user)
        : base(screenId, controlId, methodName, actionType) { this._user = user; }
    public MyUserInfo User { get { return this._user; } }
}
[Serializable()]
public class MyReturnValue : BaseReturnValue { /* 共通の戻り値項目を足す */ }
```

> ビルド（`3_Build_Business_*`＋2CS は `BusinessRichClient_*.sln` を `/t:build`）・オーバーレイ運用は SKILL 本文。
