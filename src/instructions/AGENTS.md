<!--
  このファイルは OpenTouryo を利用するアプリ開発リポジトリへ配布される
  「概要」インストラクションの原本（Single Source of Truth）です。

  ■ 位置づけ
    - 概要・規約・地図 → このファイル（常時コンテキストに載る）
    - 具体的なコードの書き方 → src/skills/ 配下のスキル（必要時のみロードされる）
    手順や特定領域だけの話はスキルへ。ここには毎回必要な事実だけを書く。

  ■ 制約
    - 目安 200 行以内。長いほど追従率が下がる。
    - このような HTML コメントは Claude Code では読み込み時に除去される。
      執筆者向けメモの置き場として使える（他プロダクトでは除去されない点に注意）。

  ■ TODO の埋め方
    「TODO:」を検索して各節を埋めてください。空欄のまま配布しないこと。
-->

# OpenTouryo アプリケーション開発

このリポジトリは **OpenTouryo**（.NET 用アプリケーションフレームワーク）を利用している。
以下の規約に従って実装すること。

## プロジェクト ポリシー

<!--
  導入プロジェクト固有の運用ルールを記述する欄。
  「どう実装するか」ではなく「どう振る舞うか」を書く。技術的な規約は各スキルへ。

  Git 操作の1件は、どのプロジェクトでも共通の前提として既定で入れてある。
  方針が異なる場合は、このプロジェクトの実態に合わせて書き換えること。
-->

### Git 操作は行わない

**成果物の検収は人が行う。** エージェントは作業結果をワーキング ツリーに残すところまでを担当し、
Git 操作は人が手動で行う。

したがって、指示がない限り以下を実行してはならない。

- `git add` / `git commit` — 検収前の変更を確定させない
- `git push` — レビューを経ていない変更をリモートへ送らない
- `git checkout` / `git switch` / `git branch` — 人が管理している作業状態を変えない
- `git reset` / `git restore` / `git stash` — 人の未保存の作業を失わせる可能性がある

作業が完了したら**何を変更したかを報告するに留める**。コミットの要否とタイミングは人が判断する。

<!--
  補足（執筆者向け）:
  インストラクションは「文脈」であって強制力を持たない。上記は遵守されやすい書き方に
  しているが、確実に阻止したい場合は仕組み側で塞ぐ必要がある。
    - Claude Code : PreToolUse フックで Bash(git commit:*) 等を deny する
    - 各プロダクト: 同等の機構があればそれを使う
  必要になったら install.ps1 に設定の配布を追加することを検討する。
-->

### その他のポリシー

<!-- TODO: レビュー体制、ブランチ運用、成果物の扱いなど、プロジェクト固有のルールを追記する。 -->

- TODO

## 対象バージョン

<!-- TODO: OpenTouryo 本体のバージョンと IDE を埋める。ランタイムは確定済み。 -->

- OpenTouryo: TODO
- ランタイム: .NET Framework 4.8（net48）/ .NET 10.0
- IDE: TODO

ランタイムによって書き方が変わる箇所がある。差異は各スキルに記述する。
判明している主な差異：構成ファイルは XML 定義ファイルが共通、`app.config` は core 系で
`appsettings.json` になる。

### DBMS による差異（スキルの SQL 例は特記なければ SQL Server）

対象 DBMS はプロジェクト依存（Oracle / DB2 / HiRDB / MySQL / PostgreSQL 等）。
**SQL 定義ファイル（`.sql` / `.xml`）は DBMS 別**で、パラメタの接頭辞（SQL Server `@P1` /
Oracle `:P1`）・`CAST`・関数の構文が違う。**型情報も DBMS 依存**
（`SqlDbType.Int` / `OracleDbType.Int32`）。一方、**コードの `SetParameter("P1", ...)` は
接頭辞なしで DBMS 中立**（接頭辞はフレームワークが付ける）。既存の SQL ファイルに合わせる。
詳細は `opentouryo-query-definition` / `opentouryo-dao-custom`。

## アーキテクチャ

OpenTouryo は **P層 / B層 / D層** の3層構造をとる。各層の責務は厳格に分離されており、
層をまたぐ呼び出しは規定の経路以外を通してはならない。

| 層 | 責務 | 基底クラス（親クラス1 / 2） | スキル |
| --- | --- | --- | --- |
| P層（画面 / API） | 画面の入出力とイベント処理。**業務ロジックを書かない** | 処理方式による（下表） | `opentouryo-layer-p-*` |
| B層（業務ロジック） | 業務処理。**トランザクション境界**でもある | `BaseLogic` / `MyFcBaseLogic` | `opentouryo-layer-b` |
| D層（データアクセス） | SQL の実行。**業務判断をしない** | `BaseDao` / `MyBaseDao` | `opentouryo-layer-d` |

**P層は処理方式ごとに実装モデルが違う。** 使っている方式のスキルを読むこと。

| 処理方式 | 画面コード親クラス1 / 2 | 実装モデル | スキル |
| --- | --- | --- | --- |
| ASP.NET MVC / ASP.NET Core MVC | `BaseMVController` / `MyBaseMVController`<br>`BaseMVControllerCore` / `MyBaseMVControllerCore` | アクションメソッド（**UOC メソッドは無い**） | `opentouryo-layer-p-mvc` |
| ASP.NET Web Forms | `BaseController` / `MyBaseController` | UOC メソッド | `opentouryo-layer-p-webforms-screen`（作成）<br>`opentouryo-layer-p-webforms-event`（イベント） |
| Windows Forms | `BaseControllerWin` / `MyBaseControllerWin` | UOC メソッド | `opentouryo-layer-p-winforms-screen`（作成）<br>`opentouryo-layer-p-winforms-event`（イベント） |

P層から B層を呼ぶ共通手順（引数クラス・`DoBusinessLogic`・`ErrorFlag`・2CS の手動トランザクション）は
`opentouryo-p-call-business`。

**WPF は P層フレームワークを持たない。** B層・D層のみを利用し、画面は素の WPF として実装する
（`Window` を継承する。`MyBaseControllerWin` は `Form` を継承しているため使えない）。
WPF で使えるのは `opentouryo-layer-b` / `opentouryo-layer-d` など P層以外のスキル。

### 層間の呼び出し規約

**経路は固定されている。層を直接 `new` して呼んではならない。**

```
P層  --CallController.Invoke(サービス論理名, パラメータ値)-->  B層
B層  --new LayerD(this.GetDam()) / new CmnDao(this.GetDam())-->  D層
```

- **P層 → B層は `CallController.Invoke()`。** B層のクラスを直接 `new` しない。
  渡すのは**サービス論理名**であって、URL やクラス名ではない。実体の解決は定義ファイルが行い、
  インプロセス呼び出しと Web サービス呼び出しを**コードを変えずに切り替えられる**
  （`opentouryo-transmission`）
- **B層 → D層は `this.GetDam()` を渡して Dao を生成する。** 接続とトランザクションは
  B層（親クラス2）が持っているため、D層が自前で接続を開くことはない
- **P層から D層を直接呼ばない。** トランザクション境界は B層にある
- 層をまたぐ引数・戻り値は **`BaseParameterValue` / `BaseReturnValue` の派生型**で受け渡す

### クラスの階層と修正可否

各層は「親クラス1 → 親クラス2 → 業務コード（画面コード）クラス」の3階層で構成される。

| 階層 | 例 | 名前空間（アセンブリ） | 提供 | 修正 |
| --- | --- | --- | --- |
| 親クラス1 | `BaseLogic` / `BaseDao` / `BaseController` | `Touryo.Infrastructure.Framework.*` | バイナリ提供 | 修正不可 |
| 親クラス2 | `MyFcBaseLogic` / `MyBaseDao` / `MyBaseController` | `Touryo.Infrastructure.Business.*` | 纏め者が開発・改修 | **このプロジェクトでは修正不可** |
| 業務コードクラス | 各画面 / B層 / D層 クラス | プロジェクトの名前空間 | ここに実装する。 | **可** |

汎用の基盤部品は `Touryo.Infrastructure.Public.*`（`Db` / `Log` / `Util` 等。バイナリ提供・修正不可）。

**依存は一方向：ユーザプログラム → `Business` → `Framework` → `Public`。** 間飛ばし
（`Business` → `Public`）はよいが、逆向き（`Framework` → `Business` 等）は循環参照になり禁止。

**親クラス1・親クラス2 は、ユーザプログラム開発プロジェクトには基本的にビルド後のバイナリ
（アセンブリ）で提供される。特別に強い指示がある場合を除き修正対象にならない。ソースが
参照できる形で提供されることもあるが、それは読むためであって修正してよいという意味ではない。**

親クラス2 はカスタマイズ可能な層として設計されているが、それを行うのは
これらを整備する側であって、ユーザプログラム開発プロジェクトではない。

スキルの中に親クラス2 への実装方法（`UOC_ABEND` での例外振替など）の記述があるのは、
**挙動を理解するため**であって、このプロジェクトで書き換えるためではない。
親クラス1・2 の中を変えたくなったら、業務コードクラス側で対処できないかを先に検討し、
それでも必要なら人に相談すること。

### 親クラス2 の挙動はプロジェクトごとに違う

**フレームワークが決めず、親クラス2 の実装が決める仕様がある**（メッセージの `%1`/`%2` 置換、
`MyUserInfo` が持つ項目、`User` 分離レベルの振替先など）。既定のテンプレートは付いてくるが、
**纏め者が書き換える前提**なので、テンプレートの値をこのプロジェクトの仕様と決めつけない。

**推測で書かない。** 確認方法（ソースを探して読む／読めなければ纏め者への質問にする）は
**`opentouryo-project-policy`** を参照。

## ディレクトリ構成

<!-- TODO: このリポジトリでの実際の配置。エージェントが「どこに何を書くか」を即断できる粒度で。 -->

```
TODO
```

## 命名規約

<!-- TODO: 検証可能な形で書く。「適切に命名する」ではなく「Dao クラスは <テーブル名>Dao とする」。 -->

- TODO

## 実装時の必須ルール

<!--
  TODO: 毎回守らせたい「常にXXする / 絶対にXXしない」だけをここに。手順はスキルへ。
  以下1件は検証済み。.NET の一般的な作法と逆で、知らないと必ず間違えるためここに置く。
-->

- **親クラス1・親クラス2 を修正しない。** バイナリで提供されておりソースが無い。
  実装するのは業務コードクラス（各画面 / B層 / D層 クラス）だけ。
  詳細は「アーキテクチャ」の「クラスの階層と修正可否」を参照。
- **業務例外（`BusinessApplicationException`）はリスローされない。** B層でスローすると
  フレームワークが捕捉し、正常系の戻り値（`ErrorFlag = true`）に変換する。呼び出し側で
  `catch` してはならない（飛んでこない）。詳細は `opentouryo-exception` を参照。
- TODO

## 非推奨クラス・メソッド

以下は `[Obsolete]` が付いている。**新規に書くコードで使ってはならない。**
`[Obsolete]` はビルド警告にしかならず、そのままビルドが通ってしまうため、ここで明示する。

<!--
  更新方法（Infrastructure 配下を対象に採取する）:
    grep -rn -A2 "\[Obsolete" --include=*.cs root/programs/CS/Frameworks/Infrastructure
  private メンバは呼び出せないため一覧から除外している
  （例: EmbeddedResourceLoader.GetEntryAssembly()）。

  網羅範囲の調査結果（2026-07-16）:
  - この一覧は CS / VB のどちらでも通用する（言語非依存）。VB を採取し直す必要はない。
    - root/programs/VB には Framework（親クラス1）が無い。CS のアセンブリを流用する
      （VB/1_GetLibrariesFromCS.bat）。よって親クラス1 の非推奨は CS の調査で網羅済み。
    - VB の Business（親クラス2）は CS のミラー。MyBaseLogic / MyBaseLogic2CS に
      同じく <Obsolete("... please use MyFcBaseLogic ...")> が付いている（実物で確認）。
    - VB での属性構文は <Obsolete(...)>。ビルド警告止まりなのは C# と同じ。
  - root/programs/CS/Frameworks/Tools 配下に [Obsolete] は無い。
-->

### クラス

| 非推奨 | 代替 | 用途 |
| --- | --- | --- |
| `MyBaseLogic` | `MyFcBaseLogic` | B層 業務コード親クラス2 |
| `MyBaseLogic2CS` | `MyFcBaseLogic2CS` | 同上（リッチクライアント用） |
| `DamOraClient` | `DamManagedOdp` | Oracle 用 Dam |
| `GetPasswordHashV1` | `GetPasswordHashV2` | パスワード ハッシュ |

### メソッド

`PubCmnFunction` のユーティリティ系メソッドは別クラスへ移動している。**メソッド名は同じ**なので、
クラス名だけ差し替える。

| 非推奨 | 代替 |
| --- | --- |
| `PubCmnFunction.GetPropsFromPropString()`<br>`PubCmnFunction.GetCommandArgs()`<br>`PubCmnFunction.BuiltStringIntoEnvironmentVariable()` | `StringVariableOperator` の同名メソッド |
| `PubCmnFunction.GetCurrentMethodName()`<br>`PubCmnFunction.GetCurrentPropertyName()`<br>`PubCmnFunction.GetCurrentCodeInfo()` | `StackFrameOperator` の同名メソッド |
| `PubCmnFunction.CopyArray()`<br>`PubCmnFunction.CombineArray()`<br>`PubCmnFunction.ShortenByteArray()`<br>`PubCmnFunction.GetLongFromByte()` | `ArrayOperator` の同名メソッド |
| `BaseController.CMN_Event_Handler(FxEventArgs)`<br>`BaseController.CMN_Event_Handler(FxEventArgs, EventArgs)` | 他のオーバーロード |

## ビルドと実行

<!-- TODO: 具体的なコマンド。「テストする」ではなく「`XXX` を実行する」。 -->

- ビルド: TODO
- テスト: TODO
- 実行: TODO

## スキル

具体的な実装手順は以下のスキルに記述されている。該当する作業に着手する前に読むこと。

| スキル | 使いどころ |
| --- | --- |
| `opentouryo-layer-p-mvc` | ASP.NET MVC / ASP.NET Core MVC のコントローラを実装するとき |
| `opentouryo-layer-p-webforms-screen` | Web Forms の画面を新規作成するとき |
| `opentouryo-layer-p-webforms-event` | Web Forms のコントロールのイベントを実装するとき |
| `opentouryo-webforms-dialog` | Web Forms で子画面（ダイアログ・モーダル/モードレス）を表示するとき |
| `opentouryo-layer-p-winforms-screen` | Windows Forms の画面を新規作成するとき |
| `opentouryo-layer-p-winforms-event` | Windows Forms のコントロールのイベントを実装するとき |
| `opentouryo-p-call-business` | P層から B層を呼ぶとき（引数クラス・`DoBusinessLogic`・`ErrorFlag`） |
| `opentouryo-richclient-async` | リッチクライアント（WinForms / WPF）で B層を非同期に呼ぶとき |
| `opentouryo-layer-b` | 業務ロジックを実装するとき |
| `opentouryo-layer-d` | D層の全体像と Dao 3系統の使い分け |
| `opentouryo-dao-custom` | 個別Dao（業務固有のデータアクセス）を実装するとき |
| `opentouryo-dao-common` | 共通Dao（`CmnDao`）で単発の SQL を実行するとき |
| `opentouryo-dao-generated` | 自動生成Dao（テーブル単位の CRUD・楽観排他）を使うとき |
| `opentouryo-query-definition` | SQL 定義ファイル（`.sql` / `.xml`）を書くとき |
| `opentouryo-message` | メッセージを定義・取得するとき（`MSGDefinition.xml`） |
| `opentouryo-shared-property` | 共有情報を定義・取得するとき（`SPDefinition.xml`） |
| `opentouryo-transaction-control` | トランザクション パターンを定義するとき（`TCDefinition.xml`） |
| `opentouryo-screen-transition` | 画面遷移制御を定義するとき（`SCDefinition.xml`。Web Forms 専用） |
| `opentouryo-transmission` | 通信制御（サービス論理名で B層を呼ぶ）を扱うとき |
| `opentouryo-exception` | 例外を扱うとき。層を問わず参照する |
| `opentouryo-logging` | ログを出力するとき |
| `opentouryo-config` | 設定値を読むとき、構成ファイルを書くとき |
| `opentouryo-auth` | 認証・ユーザ情報を扱うとき |
| `opentouryo-oauth2-client` | 外部 IdP と連携するとき（OAuth2 / OIDC のクライアント＝RP） |
| `opentouryo-project-policy` | 「このプロジェクトではどうなっているか」（親クラス2 の実装で決まる仕様）が分からないとき |

## 参考資料

- OpenTouryo 本体: https://github.com/OpenTouryoProject/OpenTouryo
- ドキュメント: https://github.com/OpenTouryoProject/OpenTouryoDocuments
- Wiki: https://opentouryo.osscons.jp/
