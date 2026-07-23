# P層→B層 呼び出し コードスニペット（コピー元）

出典：UserGuide 開発者編 §4.2／各機能編 §6（通信制御）／リッチクライアント編 §4（2CS）、実ソースで裏取り。
**on-demand 参照**（SKILL 予算外）。

## インプロセス呼び出し（同一プロセスで B層を直接）

```csharp
protected string UOC_〈イベントハンドラ名〉(FxEventArgs fxEventArgs)
{
    // 引数クラスを生成
    TestParameterValue pv = new TestParameterValue(
        this.ContentPageFileNoEx,  // 画面を表す文字列（screenId）
        fxEventArgs.ButtonID,      // イベント発生元のコントロールID（controlId）
        "〈methodName〉",          // 呼び出す B層メソッド名（UOC_〈methodName〉 が呼ばれる）
        "〈actionType〉",          // 条件分岐等に使う自由文字列（先頭[0]=DBMS）
        this.UserInfo);            // ユーザ情報（ベース2 で追加した項目）

    // 分離レベル
    DbEnum.IsolationLevelEnum iso = this.SelectIsolationLevel();

    // B層を生成して実行
    LayerB myBusiness = new LayerB();
    TestReturnValue rv = (TestReturnValue)myBusiness.DoBusinessLogic(
        (BaseParameterValue)pv, iso);

    // 戻り値判定
    if (rv.ErrorFlag == true)
    {
        // 業務続行可能なエラー（B層が業務例外をスロー）
        string id  = rv.ErrorMessageID;
        string msg = rv.ErrorMessage;
        string inf = rv.ErrorInfo;
    }
    else
    {
        // 正常系
        var result = rv.Obj;
    }

    return "";  // URL を返すと画面遷移、空文字ならポストバック
}
```

## 通信制御経由（インプロセス⇄Webサービスをコード無変更で切替）

サービス論理名で呼ぶ。実体解決は `TMProtocolDefinition.xml`／`TMInProcessDefinition.xml`（`opentouryo-transmission`）。
**リモート（protocol=2）は net48 専用**、net10.0 はインプロセスのみ。

```csharp
CallController cctrl = new CallController(this.UserInfo);
// 任意：プロキシ／WAS 認証情報（実行時はこちらが優先）
// cctrl.ProxyUrl = "http://proxy/";
// cctrl.NetworkCredentialToProxy = new NetworkCredential("id", "pw", "domain");

TestReturnValue rv = (TestReturnValue)cctrl.Invoke("〈サービス論理名〉", pv);
// 以降の ErrorFlag 判定は同上
```

## 2層C/S（リッチクライアント）＝手動トランザクション

C/S 2層では都度コミットせず手動制御する。B層は `MyFcBaseLogic2CS` を継承（`opentouryo-base2-customize`）。

```csharp
LayerB myBusiness = new LayerB();  // : MyFcBaseLogic2CS
TestReturnValue rv = (TestReturnValue)myBusiness.DoBusinessLogic(
    (BaseParameterValue)pv, DbEnum.IsolationLevelEnum.ReadCommitted);

// 終了処理（いずれか）
BaseLogic2CS.CommitAndClose();     // コミット＋切断
// BaseLogic2CS.RollbackAndClose(); // ロールバック＋切断
// BaseLogic2CS.ConnectionClose();  // NoTransaction 指定時（以降は自動コミット）は切断のみ
```

> ★ 業務例外はリスローされない（`ErrorFlag` で戻る）ので `catch` しない。詳細は `opentouryo-exception`。
> リッチクライアントで**非同期**に呼ぶなら `opentouryo-richclient-async`。
