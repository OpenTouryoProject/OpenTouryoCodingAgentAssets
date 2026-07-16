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

## アーキテクチャ

OpenTouryo は **P層 / B層 / D層** の3層構造をとる。各層の責務は厳格に分離されており、
層をまたぐ呼び出しは規定の経路以外を通してはならない。

| 層 | 責務 | 主な基底クラス | スキル |
| --- | --- | --- | --- |
| P層（画面 / API） | TODO | 処理方式による（下表） | `opentouryo-layer-p-*` |
| B層（業務ロジック） | TODO | TODO | `opentouryo-layer-b` |
| D層（データアクセス） | TODO | TODO | `opentouryo-layer-d` |

**P層は処理方式ごとに実装モデルが違う。** 使っている方式のスキルを読むこと。

| 処理方式 | 画面コード親クラス1 / 2 | 実装モデル | スキル |
| --- | --- | --- | --- |
| ASP.NET MVC / ASP.NET Core MVC | `BaseMVController` / `MyBaseMVController`<br>`BaseMVControllerCore` / `MyBaseMVControllerCore` | アクションメソッド（**UOC メソッドは無い**） | `opentouryo-layer-p-mvc` |
| ASP.NET Web Forms | `BaseController` / `MyBaseController` | UOC メソッド | `opentouryo-layer-p-webforms` |
| Windows Forms | `BaseControllerWin` / `MyBaseControllerWin` | UOC メソッド | `opentouryo-layer-p-winforms` |

**WPF は P層フレームワークを持たない。** B層・D層のみを利用し、画面は素の WPF として実装する
（`Window` を継承する。`MyBaseControllerWin` は `Form` を継承しているため使えない）。
WPF で使えるのは `opentouryo-layer-b` / `opentouryo-layer-d` など P層以外のスキル。

<!-- TODO: 層間の呼び出し経路を1〜2文で。「P層はB層をXX経由で呼ぶ」「D層は必ずB層から呼ぶ」等。 -->

TODO: 層間の呼び出し規約

### クラスの階層と修正可否

各層は「親クラス1 → 親クラス2 → 業務コード（画面コード）クラス」の3階層で構成される。

| 階層 | 位置づけ | 例 | このプロジェクトでの修正 |
| --- | --- | --- | --- |
| 親クラス1 | フレームワーク本体 | `BaseLogic` / `BaseDao` / `BaseController` | **不可** |
| 親クラス2 | 業務フレームワーク（プロジェクト共通部品） | `MyFcBaseLogic` / `MyBaseDao` / `MyBaseController` | **不可** |
| 業務コードクラス | 業務個別の実装 | `LayerB` / `LayerD` / 各画面のコード | 可 |

**親クラス1・親クラス2 は、ユーザプログラム開発プロジェクトにはビルド後のバイナリ
（アセンブリ）で提供される。ソースが無いため修正できず、特別に強い指示がある場合を除き
修正対象にならない。**

親クラス2 はカスタマイズ可能な層として設計されているが、それを行うのは
これらを整備する側であって、ユーザプログラム開発プロジェクトではない。

スキルの中に親クラス2 への実装方法（`UOC_ABEND` での例外振替など）の記述があるのは、
**挙動を理解するため**であって、このプロジェクトで書き換えるためではない。
親クラス1・2 の中を変えたくなったら、業務コードクラス側で対処できないかを先に検討し、
それでも必要なら人に相談すること。

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
  実装するのは業務コードクラス（`LayerB` / `LayerD` / 各画面のコード）だけ。
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
| `opentouryo-layer-p-webforms` | Web Forms の画面を実装するとき |
| `opentouryo-layer-p-winforms` | Windows Forms の画面を実装するとき |
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

## 参考資料

- OpenTouryo 本体: https://github.com/OpenTouryoProject/OpenTouryo
- ドキュメント: https://github.com/OpenTouryoProject/OpenTouryoDocuments
- Wiki: https://opentouryo.osscons.jp/
