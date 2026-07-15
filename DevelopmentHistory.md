# 開発経緯

作業を再開するための記録。**アセットの内容ではなく、アセットを作る側の記録。**
配布されるのは `src/` 配下のみで、このファイルは配布されない。

最終更新: 2026-07-15

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
| `opentouryo-layer-p` | `-winforms` / `-webforms` / `-mvc`（**未着手**） | 処理方式ごとに規約が全く違う |

`opentouryo-layer-d/references/` は削除した。D層が316行で収まり、溢れなかったため。
「D層は溢れるだろう」という当初の推測が外れた。

### 2.6 HTML コメントの使い方

Claude Code は**ブロックレベルの HTML コメントを読み込み時に除去する**ため、
執筆者向けメモをトークンを消費せずに残せる。**他プロダクトでは除去されない**点に注意。

`<!-- TODO: ... -->` を執筆者への指示、`TODO` の素文字列を埋めるべき箇所として使い分けている。

---

## 3. 成果物の現状

```
opentouryo-layer-p           64L  スケルトンのまま（3分割待ち）
opentouryo-layer-b          261L  完了
opentouryo-layer-d          316L  完了
opentouryo-query-definition 270L  完了
opentouryo-exception        250L  完了
opentouryo-logging          156L  完了
opentouryo-config           169L  完了
opentouryo-auth             184L  完了
```

7本が相互リンクしている（B層 → D層 → クエリ定義、全層 → 例外、など）。
`AGENTS.md` は173行（実効78行）。

**P層以外は書き終えている。**

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
| 認証 | **.NETの認証（`SignInAsync`）とOpenTouryoのユーザ情報（`SetUserInformation`）の両方が必要** |

### 4.4 作者から得た情報（コードからは読めない）

**これらは実装を読んでも分からない。** 失うと再取得できない。

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

## 5. 未解決の TODO

### 5.1 スキル本体

- [ ] **P層の3分割**（`-winforms` / `-webforms` / `-mvc`）。`opentouryo-layer-p` は
      スケルトンのまま。方針は「(b) 一旦保留にして B/D/共通から埋める」で合意済み
- [ ] `opentouryo-auth`: `MyUserInfo` にプロジェクト固有で足している項目
- [ ] `opentouryo-auth`: **ログアウト時のユーザ情報の破棄**。
      `UserInfoHandle.DeleteUserInformation()` があるのに MVC_Sample の `Logout` が呼んでいない。
      セッションを別途破棄しているのか、サンプルの漏れなのか不明
- [ ] `opentouryo-auth`: 外部 IdP 連携の手順（プロジェクト方針次第）
- [ ] `opentouryo-logging`: `OPERATION` ログの書式（フレームワークが出さないため標準が不明）
- [ ] `opentouryo-logging`: イベントログ（`CustomEventLog`/`SecurityEventLog`）の使いどころ
- [ ] `opentouryo-config`: XML定義ファイルの中身の書き方（分量次第で専用スキルへ）

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
2. 上記に伴い `opentouryo-config` の「P層の設定キー」節を P層スキルへ移す
3. `AGENTS.md` の TODO を埋める（導入プロジェクト側で埋める欄との切り分けが必要）
