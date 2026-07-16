---
name: opentouryo-project-policy
description: "OpenTouryo を使うプロジェクト固有の方針（親クラス2 = 業務フレームワークの実装で決まる仕様）を確認する。MyUserInfo が持つ項目、メッセージの %1/%2 置換を行うか、User 分離レベルの振替先、接続文字列のキーと DBMS、UOC_ABEND での例外の振替、ACCESS / SQLTRACE ログの書式、追加された接頭辞などを、親クラス2 のソース（MyFcBaseLogic / MyUserInfo / MyBaseController / MyBaseDao など Touryo.Infrastructure.Business）から読み取る手順と、ソースが提供されていない場合に纏め者へ投げる質問の作り方を扱う。このプロジェクトではどうなっているか / 親クラス2 の挙動 / 業務フレームワークの実装 / プロジェクト方針 / 纏め者に確認 が分からず実装を進められないときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# プロジェクト方針（親クラス2 の挙動）の確認

## このスキルの適用範囲

**「このプロジェクトではどうなっているか」が分からないと先に進めないときに使う。**

OpenTouryo には**フレームワークが決めず、親クラス2（業務フレームワーク）の実装が決める**
仕様がある。既定のテンプレートは付いてくるが、**纏め者が書き換える前提**なので、
テンプレートの値をそのまま「このプロジェクトの仕様」として扱ってはならない。

**推測で書かない。** 確認するか、人に聞く。

## 何がプロジェクト依存か

| 事項 | 既定のテンプレート | 関連スキル |
| --- | --- | --- |
| `MyUserInfo` が持つ項目 | `UserName` / `IPAddress` の2つだけ | `opentouryo-auth` |
| メッセージの `%1`/`%2` 置換 | **Web Forms のみ**実装がある | `opentouryo-message` |
| `User` 分離レベルの振替先 | `ReadCommitted` | `opentouryo-layer-b` |
| 接続文字列のキー / 使う DBMS | `ConnectionString_SQL` ほか | `opentouryo-config` |
| `UOC_ABEND` での例外の振替 | 振替の IF 文は雛形のみ。一般例外はリスロー | `opentouryo-exception` |
| `ACCESS` / `SQLTRACE` ログの書式 | カンマ区切り | `opentouryo-logging` |
| 追加された接頭辞 | `PREFIX_OF_CHECK_BOX` のみ | `opentouryo-layer-p-webforms` |

**`OPERATION` ログの書式は例外。** フレームワークが出力しないので雛形が無く、
**決まりが無いこと自体が答え**（`opentouryo-logging` 参照）。

## 手順

```
① 親クラス2 のソースを探す
     見つかった → ② 読む（確認地図）
     見つからない → ③ 纏め者への質問にする
```

### ① ソースを探す

**バイナリ提供が原則だが、提供され方はプロジェクトによる。** まず探す。

```
MyFcBaseLogic.cs / MyUserInfo.cs / MyBaseController.cs をリポジトリ内で検索する
```

アセンブリは `Touryo.Infrastructure.Business`、名前空間は `Touryo.Infrastructure.Business.*`。
本家では `Frameworks/Infrastructure/Business/` に置かれているが、**配置はプロジェクトによる**
ので、パスではなくファイル名で探す。

`.dll` しか無ければソースは提供されていない。→ ③ へ。

### ② 読む（確認地図）

**ファイル名は本家の配置。** 見つけたファイルの中の「見どころ」を読む。

| 確認したいこと | ファイル | 見どころ |
| --- | --- | --- |
| `MyUserInfo` の項目 | `Util/MyUserInfo.cs` | プロパティの一覧 |
| `%1`/`%2` の置換 | `Presentation/MyBaseController.cs` | `UOC_ABEND(BusinessApplicationException, FxEventArgs)` の中の `Replace("%1", ...)` |
| `User` の振替先 | `Business/MyFcBaseLogic.cs` | `UOC_ConnectionOpen` の `if (iso == DbEnum.IsolationLevelEnum.User)` |
| 接続文字列 / DBMS | `Business/MyFcBaseLogic.cs` | `UOC_ConnectionOpen` の `GetConfigParameter.GetConnectionString("...")` |
| 例外の振替・リスロー | `Business/MyFcBaseLogic.cs` | `UOC_ABEND` の3つのオーバーロード |
| `ACCESS` ログの書式 | `Business/MyFcBaseLogic.cs` | `UOC_PreAction` / `UOC_AfterAction` / `UOC_ABEND` の `LogIF` 呼び出し |
| `SQLTRACE` ログの書式 | `Dao/MyBaseDao.cs` | `UOC_PreQuery` / `UOC_AfterQuery` |
| 追加された接頭辞 | `Util/MyLiteral.cs` | `PREFIX_OF_*` 定数 |
| 認証・ユーザ情報の復元 | `Presentation/MyBaseController.cs` | `GetUserInfo()` |
| メッセージの取得 | `Exceptions/MyBusinessApplicationExceptionMessage.cs` | `GetMessage()` |

P層は処理方式ごとにファイルが違う。**使っている方式のものを読む。**

| 処理方式 | ファイル |
| --- | --- |
| Web Forms | `Presentation/MyBaseController.cs` |
| ASP.NET MVC | `Presentation/MyBaseMVController.cs` |
| ASP.NET Core MVC | `Presentation/MyBaseMVControllerCore.cs` |
| Windows Forms | `RichClient/Presentation/MyBaseControllerWin.cs` |

B層も同様。リッチクライアント（2層C/S）は `RichClient/Business/MyFcBaseLogic2CS.cs`。

**`MyBaseLogic` / `MyBaseLogic2CS` は非推奨クラス。** `grep` で先にヒットしがちだが、
読むのは `MyFcBaseLogic` / `MyFcBaseLogic2CS`（`AGENTS.md` の非推奨一覧を参照）。

### ③ 纏め者への質問にする

**ソースが読めないなら、答えを持っているのは纏め者（親クラス2 を整備する側）だけ。**
勝手に決めず、**確認事項を質問の形にまとめて人へ渡す。**

**作業を止めて質問を出す。** 回答は人がプロンプトで指示する。

質問は**答えやすい形**にする。「どうなっていますか」ではなく、
**既定値を示して差分だけ聞く。**

```markdown
## 親クラス2 の実装について確認させてください

`Touryo.Infrastructure.Business` のソースが参照できないため、以下が判断できません。
（）内はフレームワークの既定テンプレートの値です。

1. `MyUserInfo` に追加している項目はありますか。
   （既定: `UserName` / `IPAddress` の2つのみ）
2. 業務例外メッセージの `%1` / `%2` の置換は行っていますか。
   （既定: Web Forms の `MyBaseController` のみ実装。他の処理方式には無い）
3. `IsolationLevelEnum.User` は、どの分離レベルへ振り替えていますか。
   （既定: `ReadCommitted`）
4. `UOC_ABEND` で例外を振り替えていますか。振り替えている場合、条件と振替先を教えてください。
   （既定: 雛形のみ。一般例外はそのままリスロー）
```

**聞くのは、その作業に必要な項目だけ。** 上は例で、全部聞く必要はない。

## やってはいけないこと

- **既定のテンプレートの値を「このプロジェクトの仕様」として書く** — 纏め者が変えている
  前提の箇所がある。確認するか聞く
- **既存コードでの使われ方から結論を出す** — 手掛かりに留める。
  **「使われていない」は「できない」の根拠にならない**（単に使っていないだけかもしれない）
- **親クラス2 のソースが読めたので修正する** — 読むためであって、修正してよいという意味ではない
  （`AGENTS.md` の「クラスの階層と修正可否」参照）
- **分からないまま実装を進める** — 止めて質問を出す
- **纏め者に確認せずに親クラス2 を書き換えて辻褄を合わせる** — 修正対象ではない
- **`MyBaseLogic` / `MyBaseLogic2CS` を読んで「既定の挙動」と判断する** — 非推奨クラス。
  `MyFcBaseLogic` / `MyFcBaseLogic2CS` を読む
