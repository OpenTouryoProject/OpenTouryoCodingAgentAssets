# 開発経緯

作業を再開するための記録。**アセットの内容ではなく、アセットを作る側の記録。**
配布されるのは `src/` 配下のみで、このファイルは配布されない。

最終更新: 2026-07-16

---

## 1. このリポジトリの目的

[OpenTouryo](https://github.com/OpenTouryoProject/OpenTouryo) を利用したアプリケーション開発を、
コーディングエージェント（Claude Code / GitHub Copilot / Codex など）に行わせるためのアセット集。

方針は3点。

1. **概要をインストラクションに書く**（`src/instructions/AGENTS.md`）
2. **具体的なコードの書き方をスキルとして実装する**（`src/skills/*/SKILL.md`）
3. **プロダクトに合わせてインストールできるようにする**（`install/install.ps1`）

---

## 2. 設計判断とその理由

### 2.1 インストラクションとスキルの分離

判断基準は **「毎回コンテキストに載せる価値があるか」** の一点。

| | インストラクション | スキル |
| --- | --- | --- |
| ロード | 全セッションの開始時に**常時** | エージェントが必要と判断したときのみ |
| 向く内容 | 概要、地図、毎回守らせたい規約 | 手順、特定領域の実装方法、コード例 |
| 分量の目安 | 200 行以内 | 500 行 / 5000 トークン以内 |

インストラクションが長いほど、そこに書いた指示の追従率が**全体的に**下がる。迷ったらスキルへ置く。

### 2.2 スキルは標準準拠。プロダクト差分はインストラクションのみ

調査の結果、**SKILL.md はオープン標準**だと判明した（2025年12月に Anthropic が公開、
2026年3月時点で32ツールが対応。Claude Code / Copilot / Cursor / Codex CLI / Gemini CLI など）。

→ **スキルは1回書けば全プロダクトで動く。** 分岐はインストラクション側にのみ存在する。

- 仕様: https://agentskills.io/specification
- 制約: `name` は小文字英数字とハイフン、64文字以内、**親ディレクトリ名と一致**。
  `description` は 1024文字以内

### 2.3 プロダクト別の配布先

| プロダクト | インストラクション | スキル |
| --- | --- | --- |
| `claude` | `CLAUDE.md`（`AGENTS.md` を `@` import） | `.claude/skills/` |
| `copilot` | `.github/copilot-instructions.md`（複製） | `.github/skills/` |
| `agents` | `AGENTS.md` | `.agents/skills/` |

**Claude Code は `AGENTS.md` を読まない**（公式ドキュメントに明記）。そのため `@AGENTS.md` を
import する `CLAUDE.md` を生成する。Windows では symlink に管理者権限が必要なので import 方式。

`AGENTS.md` はどのプロダクトでも対象リポジトリのルートへ配置する（これが原本）。

### 2.4 インストーラ

`install/install.ps1`（PowerShell 7）。動作確認済み。

- 生成マーカー `<!-- opentouryo-agent-assets:generated -->` を埋め込み、
  **利用者が自分で書いた既存ファイルは上書きしない**（`-Force` で上書き可）
- 再実行は冪等
- スキルは `src/skills/` を走査するので、**スキル追加時にインストーラの変更は不要**

### 2.5 スキル分割の基準

分量だけでなく **`description` の焦点**を重視する。エージェントは `name` と `description` だけを
見てスキルを読むかどうかを決めるため、**複数の関心事を混ぜると語彙が薄まり起動精度が落ちる。**

分割の経緯：

| 元 | 分割後 | 理由 |
| --- | --- | --- |
| `opentouryo-common` | `-logging` / `-config` / `-auth` | 認証だけで6,201行。3つ混ぜると500行を超える。descriptionの焦点 |
| `opentouryo-common`（当初案） | `opentouryo-exception` を独立 | 単独で250行。層をまたいで参照される中核 |
| `opentouryo-layer-d` | `opentouryo-query-definition` を独立 | `.sql` と `.xml` は「SQL定義ファイルの書き方」という同じ関心事。Dao実装とは別軸 |
| `opentouryo-config` | `opentouryo-xml-definition` を独立（後に解体） | 6種の XML 定義ファイルを「定義ファイルの書式」という関心事でまとめた。config はパスの設定だけを扱う |
| `opentouryo-xml-definition` | `-message` / `-shared-property` / `-screen-transition` / `-transaction-control` / `-transmission` の**5つへ解体** | **書式だけでなく「それを使う機能」を書いたら別物になった。** 6種は書式こそ似ているが、機能としては共有情報・メッセージ・画面遷移・トランザクション・通信でまったく別。**粒度が小さくなっても、適切なスキルを選択して実装できることを優先**（起動は description だけで判定されるため）。共通の書式制約（DTD 埋め込み・`id` の先頭に数字不可・`Fx` キーでパス指定）は**各スキルに複製**し、1スキルで自己完結させた |
| `opentouryo-layer-d` | `-dao-custom` / `-dao-common` / `-dao-generated` の3つを独立。**`layer-d` は使い分けの入口として残す** | Dao 3系統は書き方も命名体系もまったく別（個別Dao は `SetSqlByFile2`、共通Dao は `SQLFileName` プロパティ、自動生成Dao は `S1_Insert` / `PK_` 体系）。**ただし XML 定義と違い「3系統のどれを使うか」という判断そのものがコンテンツ**なので、親スキルを薄く残した（75行 / 実効1,207トークン）。系統が決まっているなら直行してよい旨を明記 |
| `opentouryo-layer-p` | `-mvc` / `-webforms` / `-winforms`（**完了**） | 実装モデルが根本的に違う（MVC は UOC を持たない）。WPF は P層フレームワークが無く対象外 |

`opentouryo-layer-d/references/` は削除した。D層が316行で収まり、溢れなかったため。
「D層は溢れるだろう」という当初の推測が外れた。

### 2.6 HTML コメントの使い方

Claude Code は**ブロックレベルの HTML コメントを読み込み時に除去する**ため、
執筆者向けメモをトークンを消費せずに残せる。**他プロダクトでは除去されない**点に注意。

`<!-- TODO: ... -->` を執筆者への指示、`TODO` の素文字列を埋めるべき箇所として使い分けている。

---

## 3. 成果物の現状

```
opentouryo-layer-p-mvc         実効tok~4474  完了
opentouryo-layer-p-webforms    実効tok~3987  完了
opentouryo-layer-p-winforms    実効tok~4153  完了
opentouryo-layer-b             実効tok~3804  完了
opentouryo-layer-d             実効tok~1207  完了（Dao 3系統の使い分け・入口）
opentouryo-dao-custom          実効tok~1990  完了
opentouryo-dao-common          実効tok~1739  完了
opentouryo-dao-generated       実効tok~2326  完了
opentouryo-query-definition    実効tok~2923  完了
opentouryo-message             実効tok~1489  完了
opentouryo-shared-property     実効tok~ 859  完了
opentouryo-screen-transition   実効tok~1529  完了
opentouryo-transaction-control 実効tok~1782  完了
opentouryo-transmission        実効tok~1699  完了
opentouryo-exception           実効tok~3972  完了
opentouryo-logging             実効tok~1731  完了
opentouryo-config              実効tok~2999  完了
opentouryo-auth                実効tok~4463  完了
```

**全18スキルの本文を書き終えた。** 全て標準準拠、目安（500行 / 5000トークン）内。
「実効tok」は HTML コメント除去後（Claude Code ではコメントが除去されるため）。

相互リンクしている（B層 → D層 → クエリ定義、全層 → 例外、P層3種 → auth、など）。
`AGENTS.md` は約215行（実効約100行）。目安200行を少し超えている。

**残るのは各スキル内の TODO（プロジェクト固有の値・未確認の論点）と AGENTS.md の TODO。**

---

## 4. 調査で判明した重要事項

**再導出のコストが高い。** 次のセッションで同じ調査を繰り返さないこと。

### 4.1 公式ドキュメント（2016年版）の扱い

`documents/1_User_Guide/ja-JP/1_User_Guide(Common).doc` は **2016/10/3 版で内容が古い**。
前提が VS2010-2015 / .NET 3.5sp1-4.6 / IE11 で、P層の記述はほぼ全て Web Forms 前提。

**版が古いのは事実だが、設計の記述そのものは信頼できる。** 実装と突き合わせて確認すること。

#### 「相違を発見した」と誤認した件（教訓）

当初「ドキュメントは『フレームワーク例外・一般例外はB層でリスローする』と書いているが、
実装はリスローしない」と判断し、この文書にも相違として記録していた。**これは誤りだった。**

- `BaseLogic` は確かにリスローしない（`// リスローしない（上記のUOC_ABENDで必要に応じてリスロー）`）
- しかし **`UOC_ABEND`（親クラス2 の既定テンプレート）が `ExceptionDispatchInfo.Capture(ex).Throw()`
  でリスローしている**
- 正味の挙動はドキュメント通り。**リスローする場所が `BaseLogic` ではなく `UOC_ABEND` なだけ**

`BaseLogic` だけを読んで「実装はこうなっている」と結論を出したのが原因。
**フレームワークの挙動は「親クラス1 → 親クラス2 のテンプレート」まで追わないと分からない。**
親クラス2 はカスタマイズ可能な層なので、既定テンプレートの実装が「既定の挙動」になる。

#### 実装を見ないと分からない点

`FrameworkException` は `BaseLogic` で個別に `catch` されず、`catch (Exception)` に落ちる。
型としては独立しているが、B層での挙動は一般例外と同じ。

### 4.2 非推奨クラスの罠

**`MyBaseLogic` は `[Obsolete]`。正しくは `MyFcBaseLogic`。**

`grep` で `UOC_ABEND` の実装を探すと `MyBaseLogic.cs` が**先にヒットする**ため、
そのまま読むと非推奨クラスを教えるスキルになる。実際に一度踏みかけた。

非推奨クラスの一覧は `AGENTS.md` の「非推奨クラス・メソッド」節にまとめてある
（`[Obsolete]` はビルド警告止まりで素通りするため）。

### 4.3 実装から判明した仕様（推測では当たらないもの）

| 項目 | 内容 |
| --- | --- |
| UOCメソッドのシグネチャ | `private void UOC_XXX(パラメータ値クラス)`。**引数1つ・戻り値void**。レイトバインドのため |
| 戻り値の返し方 | `this.ReturnValue = ...` を**業務処理より先に**設定。`finally` で回収されるので例外時も戻る |
| `messageID` | **小文字始まり**。C#の命名規則に反する |
| 自動生成Dao の `S` / `D` | **`S`=WHEREが主キー固定 / `D`=WHEREも動的**。静的/動的の意味ではない（`S1_Insert`だけ`.sql`なので誤読しやすい） |
| 楽観排他 | `[ts] = RAND()` + `WHERE [ts] = @ts` → **更新件数0チェックが判定そのもの** |
| `SetUserParameter` | **SQL文字列への置換**。ユーザ入力を渡すとSQLインジェクション（`SetParameter`とは別物） |
| `CmnDao` の SQL 指定 | `SQLFileName`/`SQLText`プロパティ。`SetSqlByFile2()`を直呼びすると**実行時に`BusinessSystemException`** |
| `DELCMA` | **前後**のカンマを削除（無くなるまで繰り返す）。末尾だけではない |
| `.sql`/`.xml` のコメント | **コメント内に `@P1` と書くとエラー**。作者自身が全角`＠`で回避している |
| `PARAM` タグ | DPQuery_Tool 用のテスト値定義。**実行時に削除される** |
| ロガー名 | **定数がなく文字列直書き**。タイポしてもコンパイル・実行時チェックを通らずログが消える |
| `GetConfigParameter` | **core系は`InitConfiguration()`必須**。呼ばないと`ArgumentException`。`GetAnyConfigValue`/`GetAnyConfigSection`は**core専用** |
| `UserInfoHandle` | **`GetUserInformation<T>()`はcore専用、`GetUserInformation()`はnet48専用**。同名でシグネチャが違う |
| 認証 | **.NETの認証とOpenTouryoのユーザ情報（`SetUserInformation`）の両方が必要**。片方だけだと認証は通るがユーザ情報が無い（または逆） |
| 認証の方式差 | **Web Forms と MVC（net48）は Forms 認証で、`web.config` の記述も同一**。断層は net48 と Core の間（Core は Cookie 認証、`web.config` が無い） |
| P層の実装モデル | **Web Forms / Windows Forms は UOC メソッド方式、MVC は UOC を持たない**（MVC 標準のフィルタに乗る）。親クラス1 の UOC 定義数は 15 / 12 / **0** |
| コントロール名の接頭辞 | **命名規約ではなく機能。** 設定（`FxPrefixOfButton` = `btn` 等14種）から接頭辞を読み、コントロールツリーを走査してイベントを自動結線する。規約から外れると**発火しない**（`.aspx` に `OnClick` を書かない） |
| 2層C/S のトランザクション | **`BaseLogic2CS` は `BaseLogic` と別物。** コネクションが `static` でグローバル、**正常系のコミットは手動**（`CommitAndClose()`）、**業務例外ではロールバックしない**（`★★業務例外時のロールバックは自動にしない。`）、`UOC_AfterTransaction` も呼ばれない。**設計意図は 4.4 を参照**（実装だけ見ても理由には到達できない） |
| 2層C/S の B層 | **書き方は Web/MVC と同じ。** 自動振り分け・`this.ReturnValue`・UOC のシグネチャ・直呼びガードまで一致。**違うのは継承元（`MyFcBaseLogic2CS`）とトランザクション制御の2点だけ** |
| 接頭辞の結線箇所 | **親クラス1 と親クラス2 の2箇所に分かれる。** `PREFIX_OF_CHECK_BOX` だけ `MyLiteral`（親クラス2 の層）にあり親クラス2 で結線。有効な接頭辞は Web Forms が14種、WinForms が**6種だけ**（`TextBox` / `GridView` 等は WinForms で結線されない）。`FxPrefixOfCommand` は未使用（Mobile Web の名残） |
| XML定義ファイル | **6種とも DTD 埋め込み・`id` の先頭に数字不可（XML の `ID` 型）・`Fx*` キーでパス指定**という共通枠組み。`MSGDefinition` の `%1`/`%2` は **`GetMessage` ではなく P層の親クラス2 が置換**（しかも `MyBaseController`＝Web Forms にしか実装が無い。実装コメントに `方式は、プロジェクト毎に検討のこと。`）。`SCDefinition` の `mode` 属性は **DTD と定数だけあって読む実装が無い**（機能していない） |
| セッション破棄のタイミング | **ログアウトではなく「ログイン画面に入るとき」に `FxSessionAbandon()` で消す**設計。`DeleteUserInformation()` は通常不要。**Core だけ `Session.Clear()`**（他は `Session.Abandon()`。`ISession` に `Abandon()` が無いため） |
| 親クラス2 の abstract 差 | **Web Forms の `MyBaseController` は `abstract`**（`UOC_FormInit` が実装必須）だが、**`MyBaseControllerWin` は具象**（空実装済みで override 任意） |
| net48 MVC の認可 | **`web.config` の `<authorization>` と `[Authorize]` の二段構え**。属性だけではない（Web Forms の `<location>` に相当するのが属性） |
| Core の必須構成 | `Startup` で `services._AddHttpContextAccessor()` / `app._UseHttpContextAccessor()` を呼ばないと `UserInfoHandle` が動かない（`MyHttpContext.Current.Session` に依存）。**忘れてもコンパイルは通る**。先頭の `_` は誤記ではない |

### 4.4 作者から得た情報（コードからは読めない）

**これらは実装を読んでも分からない。** 失うと再取得できない。

- **親クラス1・親クラス2 は、ユーザプログラム開発プロジェクトにはビルド後のバイナリ
  （アセンブリ）で提供される。** ソースが無いため修正できず、特別に強い指示がある場合を除き
  修正対象にならない。
  → **これは設計と実装だけを見ても分からない。** 親クラス2（`MyFcBaseLogic` / `MyBaseDao` /
  `MyBaseController`）は「テンプレート」「（オーバーライドして）自由に利用できる」と
  コメントされており、**カスタマイズ可能な層に見える**。実際カスタマイズ可能だが、
  それを行うのはこれらを整備する側であって、ユーザプログラム開発プロジェクトではない。
  → 各スキルには「親クラス2 に `UOC_ABEND` を実装する」等の記述がある。これは挙動を理解する
  ためのもの。矛盾に見えるため、`AGENTS.md` と各スキルの「実装場所」節に注記を入れてある
- **2層C/S（`BaseLogic2CS`）は「アプリごとのグローバルな1トランザクション」という設計。**
  アプリケーションが Desktop 上のインスタンスとして動作するため。Web が「1リクエスト =
  1トランザクション」なのに対し、2層C/S は「**1アプリケーション インスタンス =
  1トランザクション**」。1プロセス = 1利用者なので分ける必要がない。
  → **この1点から、実装の特徴がすべて導かれる**（コネクションが `static`、コミットが手動、
  業務例外で自動ロールバックしない）。個別の仕様に見えるが、1つの設計判断の帰結。
  → 当初「複数の B層呼び出しを1トランザクションにまとめられるため」と推測していたが、
  **因果が逆**だった。「まとめられる」のではなく「アプリ = 1トランザクションなので、
  そもそも分ける概念が無い」。実装を読むだけでは前者にしか到達できない
- **WPF は P層フレームワークを持たない。** B層・D層のみを利用し、画面は素の WPF として実装する。
  → `MyBaseControllerWin` が `Form` を継承しているため構造的にも使えず、サンプル
  （`2CSClientWPF_sample`）も `Window1 : Window` で、UOC が出てくるのは `Business/LayerB.cs`
  だけ。**それでも一度誤認した**（`grep "class \w* : MyBaseControllerWin"` の4件を
  「Win と WPF の両方」と読んだが、実際は2つのサンプルツリー × WinForms の2ファイル）。
  P層スキルは **`-mvc` / `-webforms` / `-winforms` の3つで、WPF は対象外**
- **対象ランタイムは .NET Framework 4.8 と .NET 10.0**（`Business_netcore100.csproj` で裏付け済み）
- **構成ファイル**: XML定義ファイルは共通。`app.config` は core 系で `appsettings.json` になる
- **静的クエリ=`.sql`、動的パラメタライズドクエリ=`.xml`**
- **`BaseConsolidateDao`**: テーブル単位の自動生成Daoの呼び出しを集約するレイヤ。
  **B層にDBスキーマを意識させない**のが目的。プロジェクト基準次第で利用。
  → リポジトリ全体に利用実例が無く、これが無いと歴史的残置と誤判断していた
- **`IsolationLevelEnum.User`**: `MyFcBaseLogic` で既定の分離レベルへ振り替える際に使用。
  `DefaultTransaction`（DBMSの既定）とは「誰の既定か」が違う
- **認証の主眼は「認証・ユーザ情報をどう保持するか」**。Web は .NET の認証セッション維持の
  仕組みと組み合わせて使う。
  **OAuth2/OIDC/SAML2 のクライアント・サーバ実装は、サブプロダクトの汎用認証サイト
  （MultiPurposeAuthSite）用に開発されたもので、標準的な認証手段ではない。**
  → これを聞くまで、認証をプロトコル実装として捉えて別スキル（`-oauth2-oidc`/`-saml2`）を
  作る計画だった。計画を取り下げた
- **Git 操作は手動**（検収は人が行うため）。`AGENTS.md` のポリシー節に記述済み。
  フックによる強制は**現時点では見送り**

---

### 4.5 実装漏れの可能性がある箇所（推測。スキルには書かない）

**確証が無いためスキルには書いていない。** スキルに推測を書くと、エージェントが仕様として
扱ってしまうため。ここに記録だけ残す。**確認が取れたら扱いを決めること。**

#### ASP.NET Core MVC のアクセスログ出力点が net48 より大幅に少ない

| | ログ出力点 |
| --- | --- |
| net48（`MyBaseMVController`） | **7つ**。`OnActionExecuting`(`----->`) / `OnActionExecuted`(`<-----`) / `View(IView, object)`(`----->>`) / `View(string, string, object)`(`----->>`) / `OnResultExecuting`(`----->`, Debug) / `OnResultExecuted`(`<-----`, Debug) / `OnException`(`<-----`, Error) |
| Core（`MyBaseMVControllerCore`） | **3つ**。`OnActionExecutionAsync` の前後（`----->` / `<-----`）と、`MyMVCCoreFilterAttribute.OnException` |

**Core では `View()` / `OnResultExecuting` / `OnResultExecuted` の出力点が存在しない。**
実害はビューのレンダリング区間がアクセスログに出ないこと（性能測定の粒度が粗くなる）。

**推測：移植で落ちた可能性が高い。** 根拠は以下。

1. **シグネチャが1対1で対応しない（これは事実）。** net48 が override しているのは
   `View(IView view, object model)` と `View(string viewName, string masterName, object model)`。
   これは `System.Web.Mvc` の「漏斗」で、全ての `View()` 呼び出しがここへ集まる。
   ASP.NET Core には **`masterName` も `IView` オーバーロードも無い**（マスタページの概念が無い）。
   Core で同じことをするなら漏斗が `View(string viewName, object model)` に変わり、
   移植ではなく書き直しになる。→ 対応先が無いメソッドは機械的な移植では落ちる。
2. **判断した形跡が無い。** 同じ Core 版で `OnActionExecuting` / `OnActionExecuted` は
   コメントアウトのうえ `// OnActionExecutionAsyncに移行` と理由まで明記されている。
   一方 `View()` / `OnResultExecuting` / `OnResultExecuted` は**跡形もない**。
   ヘッダのイベント順コメントには `-- View` / `- OnResultExecuting` / `- OnResultExecuted` が
   列挙されているのに、実装だけが無い。
3. **開発経緯が「積み上げ」vs「新規作成」。** net48 は 2015〜2017 に12件の更新履歴があり、
   `OnResultExecuting/Executed` の性能測定追加、View での ViewName 表示、ログフォーマットの
   全面見直しと**段階的にログ出力点が増えている**。Core は **2018/04/19 に新規作成**され、
   その積み上げを引き継いでいない。

**対抗仮説（弱い）：** 「Core は `IActionResult`（Json / File / Redirect）が普通なので、
`View()` だけ拾っても片手落ち」。筋は通るが、それなら全 Result を拾える `OnResultExecuting` を
実装するはず。`MyMVCCoreFilterAttribute` は `ActionFilterAttribute` を継承しており
**実装できる状態にありながら、していない**。代替手段を実装した痕跡が無い。

<!--
  スキル（opentouryo-layer-p-mvc）には「net48 は View() を override してアクセスログを出す。
  Core にはこのオーバーライドが無い」という**事実だけ**を書いてある。理由づけはしていない。
-->

---

## 5. 未解決の TODO

### 5.1 スキル本体

- [x] **P層の3分割**（`-mvc` / `-webforms` / `-winforms`）— **完了**。
      `opentouryo-layer-p` は削除。WPF は P層フレームワークを持たないため対象外
- [x] **`opentouryo-auth` の「P層フレームワークごとの差異」節を P層スキルへ分配** — **完了**。
      目安超過は解消（5,800 → 約4,100トークン）
- [x] **リッチクライアント（`-winforms`）の認証の扱い** — **調査完了**。
      `UserInfoHandle` もセッションも使わず `static` な `MyBaseControllerWin.UserInfo` で保持。
      .NET の認証機構も使わない
- [ ] **`opentouryo-layer-b` と 2CS 系（`MyFcBaseLogic2CS`）の差の整理。**
      layer-b は `BaseLogic` / `MyFcBaseLogic`（Web/MVC）前提で書いてある。
      注記は入れたが、UOC のシグネチャ・`this.ReturnValue`・自動振り分けの差は未確認
- [x] **2CS で「業務例外時のロールバックを自動にしない」設計意図** — **確認済み**（4.4 参照）。
      「アプリ = 1トランザクション」という設計の帰結だった
- [ ] **リッチクライアントで有効な接頭辞の全一覧と既定値**（`FxPrefixOfCommand` /
      `FxPrefixOfPictureBox` / `FxPrefixOfComboBox` ほか）を app.config から採取する
- [ ] `opentouryo-auth`: `MyUserInfo` にプロジェクト固有で足している項目
- [ ] `opentouryo-auth`: **ログアウト時のユーザ情報の破棄**。
      `UserInfoHandle.DeleteUserInformation()` があるのに MVC_Sample の `Logout` が呼んでいない。
      セッションを別途破棄しているのか、サンプルの漏れなのか不明
- [ ] `opentouryo-auth`: 外部 IdP 連携の手順（プロジェクト方針次第）
- [ ] `opentouryo-logging`: `OPERATION` ログの書式（フレームワークが出さないため標準が不明）
- [ ] `opentouryo-logging`: イベントログ（`CustomEventLog`/`SecurityEventLog`）の使いどころ
- [x] `opentouryo-config`: XML定義ファイルの中身の書き方 — **完了**。`opentouryo-xml-definition` として独立させた（6種で263行）

### 5.2 AGENTS.md（導入プロジェクトが埋める欄）

`src/instructions/AGENTS.md` の TODO。**これらは導入プロジェクト固有なので、
このリポジトリ側では埋めきれない可能性がある。**

- [ ] OpenTouryo 本体のバージョン、IDE
- [ ] アーキテクチャ表の各層の責務・基底クラス、層間の呼び出し規約
- [ ] ディレクトリ構成、命名規約
- [ ] 実装時の必須ルール（1件のみ記述済み：業務例外はリスローされない）
- [ ] ビルドと実行のコマンド
- [ ] プロジェクト ポリシーのその他の項目

### 5.3 調査範囲

- [ ] **非推奨クラス一覧の網羅範囲**。現在は C# の `Frameworks/Infrastructure` 配下のみ。
      VB 版と `Tools` 配下は未調査

### 5.4 作者に確認したいこと

**推測のままスキルに書けない事項。** 確認が取れたら、スキルに反映するか判断する。

- [ ] **Core MVC のアクセスログ出力点が net48 より少ないのは意図的か、移植漏れか**（4.5 参照）。
      移植漏れなら、スキルには何も足さず本体側の修正課題。意図的な簡素化なら、
      `opentouryo-layer-p-mvc` に「Core はログの粒度が粗い」と書く価値がある

---

## 6. 作業環境

### 6.1 参照元（すべて `.gitignore` 済み）

| ディレクトリ | 中身 | 取得元 |
| --- | --- | --- |
| `files/` | OpenTouryo 本体ソース一式（2,868ファイル） | https://github.com/OpenTouryoProject/OpenTouryo |
| `documents/` | 旧ドキュメント（`.doc` / `.xls` / `.xlsx`） | https://github.com/OpenTouryoProject/OpenTouryoDocuments |
| `reference/` | （現状は空） | — |

**アセットの記述は `files/` の実ソースを正とする。** `documents/` は 2016年版で古い（4.1参照）。

主要な参照先：

```
files/csharp/Frameworks/Infrastructure/Framework/     フレームワーク（親クラス1・触らない層）
files/csharp/Frameworks/Infrastructure/Business/      業務フレームワーク（親クラス2・纏め者がカスタマイズ）
files/csharp/Frameworks/Infrastructure/Public/        基盤部品（Db / Log / Util / Str …）
files/csharp/Samples4NetCore/Backend/MVC_Sample/      .NET 10.0 系の実例（最重要）
files/csharp/Samples/                                 net48 系の実例
files/else/resource/Sql/                              自動生成SQL・クエリ定義の実例
files/else/resource/Test/dpq/                         動的パラメタライズドクエリのタグ実例（318ファイル）
```

### 6.2 `.doc` の読み方

**この環境には Word / LibreOffice / pandoc が入っていない。** `.doc` は Word 97-2003 の
バイナリ形式なので、そのままでは読めない。

`olefile` を使い、`WordDocument` ストリームの FIB から CLX（ピーステーブル）を辿って
テキストを抽出するスクリプトで対応した（日本語も復元できた）。

```
pip install olefile   # 隔離した venv へ
```

FIB の `fcClx` は WordDocument ストリームの絶対オフセット `0x01A2`。
`PARAM` はピース単位で UTF-16LE か cp1252 か分岐する。

### 6.3 検証

スキルが Agent Skills 標準に準拠しているかは、`name` と親ディレクトリ名の一致、
`name` の書式、`description` の長さを確認する。公式の参照実装でも検証できる。

```
skills-ref validate ./src/skills/opentouryo-layer-d
```

インストーラの動作は、スクラッチ領域に実際にインストールして確認する
（3プロダクトへの配置、冪等性、既存ファイル保護、`-Force`、不明なスキル名のエラー）。

---

## 7. 次にやること

1. **P層の3分割**（`opentouryo-layer-p-winforms` / `-webforms` / `-mvc`）。
   `opentouryo-layer-p` は削除するか、共通部分を残すか要判断
2. 上記に伴い、以下を P層スキルへ移す
   - `opentouryo-auth` の「P層フレームワークごとの差異」節（**目安超過の解消**。5.1 参照）
   - `opentouryo-config` の「P層の設定キー」節
3. `AGENTS.md` の TODO を埋める（導入プロジェクト側で埋める欄との切り分けが必要）

**1 が他の課題のボトルネックになっている。** 目安超過の解消も、設定キーの整理も、
P層スキルが無いと置き場所が決まらない。
