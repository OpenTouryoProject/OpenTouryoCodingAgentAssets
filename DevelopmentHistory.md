# 開発経緯

作業を再開するための記録。**アセットの内容ではなく、アセットを作る側の記録。**
配布されるのは `src/` 配下のみで、このファイルは配布されない。

最終更新: 2026-07-24（全36スキル。ログ分析 `opentouryo-log-analysis`・バッチ更新 `opentouryo-batch-update` を新設。§3 インベントリを全スキル再計測して更新〔WS/ProjectReference・
OT_Tools・命名規則・TFM 改修を反映〕。それ以前：利用ガイド doc 0〜8・設定一覧まで確認し整合性補正、
新規スキル追加、ランタイム差（net48 / net10.0）の反映、③基盤ビルドを project-setup-build へ・
変形の後工程 project-transform を分離）

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

`install/install.ps1`。**Windows PowerShell 5.1 / PowerShell 7 の両対応**。動作確認済み。

- 生成マーカー `<!-- opentouryo-agent-assets:generated -->` を埋め込み、
  **利用者が自分で書いた既存ファイルは上書きしない**（`-Force` で上書き可）
- 再実行は冪等
- スキルは `src/skills/` を走査するので、**スキル追加時にインストーラの変更は不要**
- **5.1 対応の要点**：①`#Requires -Version 5.1` ②生成物の書き込みは
  `utf8NoBOM`（PS6+専用）を使わず `[IO.File]::WriteAllText` で BOM 無し UTF-8 出力
  ③スクリプト自身を **UTF-8 with BOM で保存**（5.1 は BOM 無し .ps1 を ANSI=cp932 と
  誤読し、日本語コメントでヒアストリング解析が壊れるため）

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
| `-webforms` / `-winforms` | それぞれ `-screen`（作成）/ `-event`（イベント）に再分割 ＋ 横断 `opentouryo-p-call-business` を新設（**作者の提案**） | ①**サイズ圧**：両者とも 4,400／4,600トークンで上限に迫り加筆余地が無かった。②**タスクの分離**：Developers編4章が「作成→イベント→B層呼出し」の順で説明する別作業で、起動を description で分けたい。③**B層呼出しの集約**：webforms/winforms/mvc で重複していた「引数クラスの組み立て → `DoBusinessLogic` → `ErrorFlag`」と、winforms に埋もれていた**2CS の手動トランザクション**を1本に集約（重複排除）。引数クラスの方式差は表で吸収。MVC は UOC が無く上限にも遠いので**分割せず現状維持**（B層呼出しの共通手順だけ横断スキルへリンク）。分割後は各P層スキルが 1,800〜2,900トークンに収まった |
| （新規） | `opentouryo-project-policy` | **分割ではなく、穴を埋めるために追加**（作者の提案）。「親クラス2 の実装で決まる仕様は確認せよ」と各スキルに書いたが、**何を・どこを見て・見られなければ誰に何を聞くのかがどこにも無かった**。確認手順は `message` 固有ではなく親クラス2 依存の事項すべてに効く一般則なので、各スキルへ複製せず1本にまとめ、`AGENTS.md` と各スキルからここを指した |
| `opentouryo-auth` | `opentouryo-oauth2-client` を独立 | auth が 4,463トークンで加筆余地が無かったのが発端だが、**本質は「外部 IdP と連携したい」が独立したタスクで、語彙（OAuth2 / 認可コード / id_token / state / nonce）も別に立つ**こと。auth は「ユーザ情報の保持」に専念させた。**最後にやることは通常のログインと同じ**（.NET 側の認証 + `MyUserInfo`）なので、両スキルは相互リンクしている |

`opentouryo-layer-d/references/` は削除した。D層が316行で収まり、溢れなかったため。
「D層は溢れるだろう」という当初の推測が外れた。

### 2.6 HTML コメントの使い方

Claude Code は**ブロックレベルの HTML コメントを読み込み時に除去する**ため、
執筆者向けメモをトークンを消費せずに残せる。**他プロダクトでは除去されない**点に注意。

`<!-- TODO: ... -->` を執筆者への指示、`TODO` の素文字列を埋めるべき箇所として使い分けている。

### 2.7 GUI ツールの CLI 化：基準は「エージェントが直接できるか」（作者判断）

**判断基準：そのツールが、エージェントが直接できない処理を含むか。**
含まないなら CLI 化しない。含むなら CLI 化する価値がある（2026-07・作者判断）。

| ツール | CLI 化 | 理由 |
| --- | --- | --- |
| `DPQuery_Tool`（動的クエリ分析ツール） | **しない** | エージェントは `.sql` / `.xml` を**直接書けて Dao 経由で実行・テストできる**。ツールの価値は「人が GUI で試験実行する」ことで、エージェントの作業フローとは前提が違う |
| **D層自動生成ツール（墨壺）** | **する予定**（本体 Issue [#508](https://github.com/OpenTouryoProject/OpenTouryo/issues/508) 起票済み・2026-07-17） | **ランタイムから実行できない処理**（DB スキーマの読み取り → Dao / DTO / SQL のコード生成）を含む。エージェントが直接できないので、CLI 化すれば呼べるようになる |
| データ・メンテナンス画面自動生成（ASP.NET） | **未検討・スコープ外** | doc0（Index）で存在を確認した既知の GUI ツール。墨壺同様「エージェントが直接できない生成処理」を含むので将来 CLI 化の候補ではあるが、画面生成は現状スコープ外。スキル化もしていない |

**教訓：人間向け GUI ツールを機械的にエージェント向けへ移植しない。**
エージェントが**元の成果物（コード）を直接扱えるなら**ツールは不要（`DPQuery_Tool`）。
逆に**ツールが手作業では再現しにくい処理を持つなら** CLI 化の価値がある（自動生成ツール）。

`DPQuery_Tool` はツール化ではなく `opentouryo-query-definition` の充実で対応した。
D層自動生成ツールの CLI ができたら、`opentouryo-dao-generated` から呼び出し方を案内できる
（現状スキルは「生成物の使い方」を扱い、生成そのものはツール前提。§5 / §7 参照）。

**この基準の実例：プロジェクトセットアップ（`opentouryo-project-setup`）。**
新規立ち上げ（OpenTouryo を GitHub から ZIP 取得 → 基盤ビルド → サンプルを取り出し → 参照
張り替え → リソース移設 → config 張り替え）は、**すべてエージェントが直接できる**
（ダウンロード・ビルドバッチ実行・csproj/config 編集）。GUI に頼らず手順スキルとして実装した。
Download→Build→ベンダは、その場のコマンド羅列にせず**セットアップ スクリプトを生成して実行**する
（作者の指示。再現・レビュー可能にする。模範は MultiPurposeAuthSite の
`3_BuildLibsAtOtherRepos.bat` / `...InTimeOfDev.bat`）。
ビルドは4バッチ（`2_Build_NuGet_net48` → `3_Build_Business_net48` →
`2_Build_NuGet_netcore100` → `3_Build_Business_netcore100`。`9_CICD.bat` は使わない）。
基盤 DLL は導入リポジトリ内 `OpenTouryoAssemblies\Build_net48\` / `Build_netcore100\` にベンダし、
`Reference Include="OpenTouryo.*"` の `HintPath` だけを張り替える（3rd-party は NuGet 復元に任せる）。

---

## 3. 成果物の現状

```
opentouryo-layer-p-mvc            実効302L tok~3687  完了
opentouryo-layer-p-webforms-screen 実効146L tok~1891  完了（画面の新規作成）
opentouryo-layer-p-webforms-event  実効177L tok~2935  完了（イベント実装）
opentouryo-webforms-dialog         実効166L tok~2193  完了（子画面表示・ダイアログ）
opentouryo-layer-p-winforms-screen 実効117L tok~1812  完了（画面の新規作成）
opentouryo-layer-p-winforms-event  実効106L tok~1878  完了（イベント実装）
opentouryo-p-call-business        実効191L tok~2784  完了（P層→B層呼出し・横断）
opentouryo-richclient-async       実効148L tok~2110  完了（リッチクライアントの非同期呼び出し）
opentouryo-common-parts           実効129L tok~2351  完了（用途→共通部品のインデックス）
opentouryo-project-setup          実効 99L tok~2617  完了（**ファサード**。全体の流れ＝4スキル＋選択式 db の呼び出し順／既存への追加・再実行〔冪等性・**2CS/RichClient は同ランタイムでも③追加ビルド要＝例外**〕／**配置・命名の固定規則**〔net48=元名・core は net48版が在れば `_Core`・net48 のみ/net10.0 のみは無印・WS 系は `WS_sample\` 階層維持・開発支援ツールは `OT_Tools\` 配下〕／完了後（→transform）・コミット促し／全工程共通の禁止事項〔例外：WS ホスト ServiceInterface は引き込む〕）
opentouryo-project-setup-selection 実効105L tok~2856  完了（①②。起点サンプル選択〔全系列を必ず提示・**派生も提示**・名前で決め打ちしない〕＋取得元 <ref>〔固定タグ番号はユーザ確認・develop〕。**CLI=net10.0 のみ／Web Forms=net48 のみ／WSClient variant は csproj で判断〔Win2 は WS 非依存の単独 P層〕**。RichClient 基盤要サンプル注記〔2CS/WPF/3層〕）
opentouryo-project-setup-build    実効169L tok~4350  完了（③。ZIP取得→ランタイム別バッチ→ベンダ。footgun＋偽の成功＋MAX_PATH短ルート＋PowerShell 既定。短ルート展開ツリーをワークスペース化。**Business.RichClient は別 sln＝2CS/RichClient なら必須・base2 非依存**。生成 .ps1 は `scripts/` 配下・CWD 非依存）
                                  └ examples.md 実効233L tok~4044  実機 as-built スクリプト3本（setup-build/setup-build-netcore/build-app。netcore は extract 流用・TFM 両サブフォルダをベンダ。**build-app は WS を ProjectReference で同ソリューション一括ビルドに改訂**〔copy-to-Build 廃止〕。ツールは `OT_Tools\`）
opentouryo-project-setup-core     実効 73L tok~1635  完了（④⑤＝核心。取り出し〔+開発支援ツール→`OT_Tools\`・**csproj Include とファイル実体を毎回照合**〕・HintPath 張替・WS/3層の扱い。references/samples を保持）
                                  ├ references/reference-rewrite.md 実効54L tok~1295  ⑤の edge case（Build_* 全 DLL＝MySql/Oracle 非復元・**WSServer/WSIFType は ProjectReference＝DLL張替の対象外**・net48 も PackageReference 併用時 restore・MAX_PATH）
                                  ├ samples/webservices.md 実効152L tok~4407  WS/3層の共通機構＋**WSClient 4 variant 実測表**〔依存形3種・config 0〜2・ClickOnce〕。**参照方式＝FW は DLL／サンプル B・D・型は ProjectReference**・WS ホスト ServiceInterface 引き込み・`_all.sln` 雛形差替・core 実用不可
                                  ├ samples/webforms.md    実効42L tok~881   Web Forms 固有（cc 画面 CS0246・(A)=WS を ProjectReference/(B)画面差し替え・config二段・test*マスタ固有名）
                                  ├ samples/daogentool.md  実効39L tok~912   開発支援ツール DaoGen_Tool（墨壺＝D層自動生成。`OT_Tools\` 配下・HintPath＋PackageReference 混在＝restore 要）→ dao-generated
                                  └ samples/dpquerytool.md 実効35L tok~798   開発支援ツール DPQuery_Tool（PARAM タグ。取り出し/張替は daogentool.md と同じ）→ query-definition
opentouryo-project-setup-config   実効 83L tok~1846  完了（⑥⑦。resource 移設・config パス張替〔%OT_RESOURCE_ROOT%〕・.gitignore・接続文字列/InitConfiguration/StateServer・ビルド/実行検証。references を保持）
                                  ├ references/resource-config.md   実効84L tok~1876  ⑥の詳細（相対不可・%VAR%展開・パスキー一覧・**自己完結型 `.\Dao` は張替しない例外**・log4net PatternString・綴りの罠・config二段）
                                  └ references/run-verify.md        実効97L tok~2085  ⑦実行確認（net48 IIS Express／core Kestrel／デスクトップ exe 生存／**Batch・CLI 引数・Console.ReadKey・DB 条件付き**／3層は WS ホスト ServiceInterface 起動）
opentouryo-project-setup-db       実効 98L tok~2203  完了（**選択式**の環境構築。LocalServicesOnDocker で SQL Server/MySQL/PostgreSQL/Redis/MongoDB を Docker 起動。既定が サンプル接続文字列と一致〔SQL 1433/sa/seigi@123/Northwind＝ConnectionString_SQL、MySQL＝ConnectionString_MCN〕。Oracle は対象外。Docker 変更は SETUP-CHANGES.md 記録。既存 DB あれば不要。**★4 DB は永続無し＝毎回リセット・redis のみ残る／Northwind 基本表は自動再作成・ORDERS2 等サンプル固有表は都度再投入**。clone は repo 外・起動前ポート プリフライト・Start-Services.ps1 の up/down/ps/logs＋-NoWait/-NoPause）
opentouryo-project-transform      実効101L tok~2263  完了（セットアップ後の変形＝2層化・サンプル整理・CS0246 解消。実機E2E反映：改行LF/非対話PSガード・2層化のDB DLL付替・test*マスタ警告・csproj剪定手法。実行は任意）
opentouryo-layer-b               実効293L tok~4133  完了
opentouryo-layer-d             実効151L tok~2239  完了（Dao 3系統の使い分け・入口）
opentouryo-dao-custom          実効205L tok~2928  完了
opentouryo-dao-common          実効143L tok~2096  完了
opentouryo-dao-generated       実効157L tok~2112  完了
opentouryo-batch-update        実効 79L tok~1758  完了（**DataTable の RowState バッチ更新**。グリッド外[追加]=Added・グリッド内[削除]=`dr.Delete()`=Deleted・セル編集=Modified を `switch(dr.RowState)` で自動生成 Dao の S1_Insert/D3_Update/D4_Delete に振り分け。`DataRowVersion.Original` で楽観排他〔Deleted 行は Original のみ〕、`AcceptChanges`、Web は Session 保持、大量は SQLUtility/ExecGenerateSQL。実サンプル GenDaoAndBatUpd_sample で裏取り）
opentouryo-query-definition    実効343L tok~4109  完了
opentouryo-message             実効140L tok~1760  完了
opentouryo-shared-property     実効 75L tok~ 779  完了
opentouryo-screen-transition   実効119L tok~1485  完了
opentouryo-transaction-control 実効129L tok~1652  完了
opentouryo-transmission        実効141L tok~2063  完了
opentouryo-exception           実効298L tok~4407  完了
opentouryo-logging             実効167L tok~2114  完了
opentouryo-log-analysis        実効 85L tok~2092  完了（**出力ログの分析＝読む側**。ACCESS/SQLTRACE/OPERATION/SERVICE-IF の parse、ERROR/FATAL＋スタックトレース＋例外型による分類、実行時間/CPU時間の外れ値・遅いSQL・N+1・分離レベル、重大度順の提案〔証跡→原因→対処→使うスキル〕。実ログ `resource/Log` で書式裏取り。references に実行行例・原因/対処表・grep 集計レシピ）
opentouryo-config              実効200L tok~2746  完了
opentouryo-auth                実効312L tok~4952  完了 ★上限に貼り付いている
opentouryo-oauth2-client       実効266L tok~2853  完了
opentouryo-project-policy      実効195L tok~4515  完了（親クラス2 の挙動・運用ルールの確認手順＝読む側。Business 実ソース全スキャンで Web API/引数戻り値/非同期/サブシステム/属性の確認地図を追補。検証実行で①ソース所在を現行化〔短ルート C:\otr・使い捨て・上流 archive/<ref>.zip 取得手順〕＋overlay 空/不在=未改変確定の L166 例外・接続文字列キーは config 先読み・空振り起動ガード・確定事実は PROJECT-POLICY.md へ記録。<ref> は setup-build が build-ref.txt に残す。★DBMS 選択等の4行は 2CS なら MyFcBaseLogic2CS.cs を読む・ActionType は PascalCase・Dam はランタイム別）
opentouryo-base2-customize     実効169L tok~4878  完了（親クラス2 のカスタマイズ＝纏め者向け・作る側。オーバーレイ+固定タグ。短ルート展開ツリーをワークスペース化。★2CS=Business.RichClient は別 sln〔BusinessRichClient_*.sln〕要ビルド／overlay 適用は Copy-Item＋UTF-8 BOM 保持／overlay はファイル丸ごと差替＝パッチでない。Web API/引数戻り値/非同期/RcMyCmnFunction/サブシステム/属性の差し込み点を追補。検証実行で UOC_ConnectionOpen は deprecated 双子含む4クラス重複／DBMS 増減の面チェックリスト／RichClient sln は非SDK＝/t:build・obj 共有掃除〔examples.md 2b〕／overlay 適用の正典1本／ODP ガード不揃い注意）
```

**全34スキルの本文を書き終えた。** 全て標準準拠、目安（500行 / 5000トークン）内。
「実効」は HTML コメント除去後（Claude Code ではコメントが除去されるため）。
計測は `scratchpad/measure.py` 相当のスクリプトで行う（見積り式：ASCII 1/4字 + 非ASCII 1/1.1字。
tiktoken 生値はこれより約1.3倍〔日本語過大計上〕なので、上表は見積り式で統一）。
値は 2026-07-20 に全スキル再計測して更新（WS/ProjectReference・OT_Tools・命名規則・TFM 改修を反映）。

**`opentouryo-auth` は 約4,950トークンで上限 5,000 に接している。**
これ以上の加筆は分割とセットで考えること。外部 IdP 連携を `opentouryo-oauth2-client` として
独立させたのもこれが一因（2.5 参照）。

相互リンクしている（B層 → D層 → クエリ定義、全層 → 例外、P層3種 → auth、
auth → oauth2-client、setup → config / project-policy、など）。
`AGENTS.md` は tok~3403（スキル一覧表は README〔GitHub リンク〕へ移設済み＝§4.3 2026-07-19。
常時ロード枠を約1000 節約）。残るのは横断事実（DBMS 差・名前空間・ランタイム差・セットアップ）と
非推奨リファレンス表が中心で、これ以上は load-bearing な情報を削ることになる。スキル一覧と使いどころは README 参照。

**残るのは各スキル内の TODO（プロジェクト固有の値・未確認の論点）と AGENTS.md の TODO。**

---

## 4. 調査で判明した重要事項

**再導出のコストが高い。** 次のセッションで同じ調査を繰り返さないこと。

### 4.1 公式ドキュメント（2016年版）の扱い

`documents/1_User_Guide/ja-JP/1_User_Guide(Common).doc` は **2016/10/3 版で内容が古い**。
前提が VS2010-2015 / .NET 3.5sp1-4.6 / IE11 で、P層の記述はほぼ全て Web Forms 前提。

**版が古いのは事実だが、設計の記述そのものは信頼できる。** 実装と突き合わせて確認すること。

#### 各機能編（doc 6）で判明した「ドキュメントが古い」実例（2026-07-16）

`6_User_Guide(Each_Function_Editing).doc` を確認。ch.3〜6（共有情報/メッセージ・画面遷移・
トランザクション・通信制御）は既存スキルと一致。**新規は子画面表示機能（ch.2）**を
`opentouryo-webforms-dialog` として起こした。この機能で**ドキュメントが実装から乖離**していた：

- ドキュメントの制限事項（ch.8）は「業務モーダルはモダンブラウザで表示できない（IE専用）」
  とするが、**最新版は IE 以外で擬似ダイアログを使う**（作者に確認）。
  OK・YES/NO＝**Floating div**、業務モーダル＝**`window.open`**。
- **`CloseModalScreen_WithAllParent` はサポートされなくなった**（メソッドは残存・`[Obsolete]`無し）。
- `FxEnum.IconType` の値は **`Information` / `Exclamation` / `StopMark`**。
  ドキュメントの `INFORMATION` 等の綴りは古い（実装で確認）。

**教訓：制限事項・API 綴り・サポート状況はドキュメントを鵜呑みにせず実装と作者に当たる。**
Ajax連携（ch.7＝.NET 2.0 世代）と共通APIユーティリティ（ch.1）はスキル化せず（レガシー／
APIリファレンスで足りる）。

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

**凡例（この節で使う記号）**：
- セットアップ工程番号は固定＝**①②**サンプル/取得元選択・**③**基盤ビルド・**④⑤**取り出し/参照張替・**⑥⑦**resource/config・検証・**〔選択式〕**DB（§3・facade と同じ番号）。
- 一方、英字/数値のレポート項目ラベル（`A/B`・`K/L`・`(1)(2)`・`①〜` 等）は**各行スコープ**で、同じ記号でも別行では別内容を指す＝内容は各行内（`K（スキル）＝…`）または見出しの〔〕で明示している。

| 項目 | 内容 |
| --- | --- |
| UOCメソッドのシグネチャ | `private void UOC_XXX(パラメータ値クラス)`。**引数1つ・戻り値void**。レイトバインドのため |
| 戻り値の返し方 | `this.ReturnValue = ...` を**業務処理より先に**設定。`finally` で回収されるので例外時も戻る |
| `messageID` | **小文字始まり**。C#の命名規則に反する |
| 自動生成Dao の `S` / `D` | **`S`=WHEREが主キー固定 / `D`=WHEREも動的**。静的/動的の意味ではない（`S1_Insert`だけ`.sql`なので誤読しやすい） |
| 楽観排他 | `[ts] = RAND()` + `WHERE [ts] = @ts` → **更新件数0チェックが判定そのもの** |
| `SetUserParameter` | **SQL文字列への置換**。ユーザ入力を渡すとSQLインジェクション（`SetParameter`とは別物） |
| ランタイムで使えない共通部品（csproj で確認・作者指摘） | **net48 専用**（core の csproj で `Compile Remove`）：`Public.IO` の `Zipper` / `UnZipper` / `ZipBase` / `BinarySerialize`、`Public.Win32` / `WinProc`、`Db\DamOLEDB` / `DamOraClient`。**`Public.Security` は「除外」ではなく独立アセンブリ**で両対応（core は `IdentityImpersonation` と CNG系ECDHのみ除外）。**リモート呼び出し（通信制御 `protocol="2"`＝Web サービス/WCF）も net48 専用**：`CallController` は core でもビルドされるが `#if NETCOREAPP` でリモート系は `return null`（`BinarySerialize` のドロップが原因）。core はインプロセス（`protocol="1"`）のみ。`common-parts` / `transmission` / `richclient-async` / `AGENTS.md` に反映 |
| 動的クエリの補完（doc4 で整合性確認） | 13タグは既に網羅。**穴3点を追記**：①テキスト内パラメタ（`@p`、処理後残る・全タグに作用）と タグ内パラメタ（`name`属性、消える・最初の1タグのみ）の区別。②XML 中の `<`/`>` は `&lt;`/`&gt;` か CDATA。③`DBNull`（DB の NULL 値・INSERT/UPDATE 用・WHERE 不可）と `null`（タグ無効化）は別物。`query-definition` に追記 |
| 暗黙の型変換（doc7 4.2） | `string`→`nvarchar`。列が`varchar`だと不一致で**列側が変換されインデックス不使用**（性能劣化）。既定は型を指定せず、劣化確認後にSQL側キャストで対処。`LIST`タグはSQL内キャストが効かない（自動展開のため）。`query-definition`に追記 |
| `SetParameter`のオーバーロード（doc7 4.4） | 値のみ／`+dbTypeInfo`／`+size`／`+ParameterDirection`。ストアドは`ParameterDirection.ReturnValue/Output`で宣言し`GetParameter`で取得。`dao-custom`に追記 |
| パラメタ名の接頭辞 | **コードの`SetParameter`名は接頭辞なし**（`"P1"`。`@`/`:`を付けない。接頭辞は DBMS 別 Dam が付ける）。当初ストアド例で`"@P1"`と書いたのは誤りで修正。サンプルは全て`SetParameter("P1", ...)` |
| DBMS 依存（作者指摘） | **スキルの SQL 例は SQL Server 中心**。SQL 定義ファイルは DBMS 別（`sqlserver/`＝`@P1`、`oracle/`＝`:P1`、db2/hirdb/mysql/pstgrs…に同じクエリ）。型情報も DBMS 依存（`SqlDbType.Int`／`OracleDbType.Int32`）。**横断注意は AGENTS.md に一度だけ**（対象バージョン節）、詳細は`query-definition`／`dao-custom`。SQL 構文（`CAST`・関数）も DBMS で違う |
| DBMS の選択箇所（作者指摘） | **親クラス2 `MyFcBaseLogic.UOC_ConnectionOpen` が `actionType.Split('%')[0]`（引数クラスの `actionType` の先頭）で Dam を選ぶ**。コード：`SQL`→`DamSqlSvr`／`ODP`→`DamManagedOdp`／`ODB`／`MCN`／`NPS`（Core）／`OLE`（net48）／既定は SQL Server。対応する `ConnectionString_<コード>` をロード。**既定テンプレートの挙動**（纏め者がカスタマイズ可） |
| `actionType` は自由文字列＝サンプル規約（作者指摘） | **`actionType` の書式はフレームワーク仕様ではなく業務コードが解釈する自由文字列。** フレームワーク（既定テンプレート）が読むのは `[0]`（DBMS）だけ。サンプルの規約は `DAP%MODE1%MODE2%EXROLLBACK`：`[0]`=DBMS、`[1]`=Dao種別（`common`/`generate`/他）、`[2]`=クエリ種別（`static`/`dynamic`）、`[3]`=ロールバックテスト（`Business`/`System`/`Other`で例外スロー）。`[1]` 以降は WSServer_sample の `LayerB`/`LayerD` が `switch` で分岐（`ActionType.Split('%')[1..3]`）。当初「DBMS選択＝フレームワークの仕組み」と書きすぎたのを是正。`p-call-business` に記述 |
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
| ハンドラのイベント名 | **接頭辞だけでなくイベント名もコントロール種別で固定。** UOC 名は `UOC_<接頭辞+名前>_<イベント名>`。イベント名は種別ごとに決まっている：ボタン系＝`Click` / テキストボックス＝`TextChanged` / ドロップダウン・リスト系＝`SelectedIndexChanged` / ラジオ・チェックボックス＝`CheckedChanged` / リピータ＝`ItemCommand` / GridView・ListView＝複数（`RowUpdating` 等）。`FxLiteral.UOC_METHOD_FOOTER_*` 定数と `BaseController` / `BaseControllerWin` の結線で確認。**`_Click` は万能ではない**（ドキュメント読解だけでは `_Click` だけを例示しがちで、そこが穴になっていた） |
| P層イベント対応の拡張（作者の補足） | **対応コントロール・イベントは固定ではない。** `MyBaseController` / `MyBaseControllerWin`（親クラス2）の `addControlEvent` に実装を足せば拡張できる（`CheckBox` 自体がその実例で、親クラス1 ではなく親クラス2 側で結線）。**拡張は纏め者の作業**なのでスキルには手順を書かず「存在と確認」だけ置いた（確認方法＝提供コードの `addControlEvent` を読む → `project-policy`）。**未対応のコントロール・イベントは .NET 標準の結線でも書けるが、その場合フレームワークの例外処理（`UOC_ABEND` の振替・共通エラー画面）とアクセスログを通らない** ← 開発者が知るべきトレードオフ。webforms/winforms の両方に注記した |
| 2層C/S のトランザクション | **`BaseLogic2CS` は `BaseLogic` と別物。** コネクションが `static` でグローバル、**正常系のコミットは手動**（`CommitAndClose()`）、**業務例外ではロールバックしない**（`★★業務例外時のロールバックは自動にしない。`）、`UOC_AfterTransaction` も呼ばれない。**設計意図は 4.4 を参照**（実装だけ見ても理由には到達できない） |
| 2層C/S の B層 | **書き方は Web/MVC と同じ。** 自動振り分け（`Latebind.InvokeMethod`）・`this.ReturnValue`・UOC のシグネチャ・直呼びガード（`WasCalledFromDoBusinessLogic`）まで一致。**違うのは継承元（`MyFcBaseLogic2CS`）とトランザクション制御の2点だけ**（2026-07-16 に実装で再確認）。ただし API には差がある：**`DoBusinessLogicAsync` が無い**（同期版2つのみ）／**キー付き Dam（`SetDam(key,dam)` / `GetDam(key)`）が無い**（Dam はアプリで1つ）。`User` の振替先が `ReadCommitted` なのは `MyFcBaseLogic` と同じ |
| 接頭辞の結線箇所 | **親クラス1 と親クラス2 の2箇所に分かれる。** `PREFIX_OF_CHECK_BOX` だけ `MyLiteral`（親クラス2 の層）にあり親クラス2 で結線。有効な接頭辞は Web Forms が14種、WinForms が**6種だけ**（`TextBox` / `GridView` 等は WinForms で結線されない）。`FxPrefixOfCommand` は未使用（Mobile Web の名残） |
| XML定義ファイル | **6種とも DTD 埋め込み・`id` の先頭に数字不可（XML の `ID` 型）・`Fx*` キーでパス指定**という共通枠組み。`MSGDefinition` の `%1`/`%2` は **`GetMessage` ではなく P層の親クラス2 が置換**（しかも `MyBaseController`＝Web Forms にしか実装が無い。実装コメントに `方式は、プロジェクト毎に検討のこと。`）。`SCDefinition` の `mode` 属性は **DTD と定数だけあって読む実装が無い**（機能していない） |
| セッション破棄のタイミング | **ログアウトではなく「ログイン画面に入るとき」に `FxSessionAbandon()` で消す**設計。`DeleteUserInformation()` は通常不要。**Core だけ `Session.Clear()`**（他は `Session.Abandon()`。`ISession` に `Abandon()` が無いため） |
| 親クラス2 の abstract 差 | **Web Forms の `MyBaseController` は `abstract`**（`UOC_FormInit` が実装必須）だが、**`MyBaseControllerWin` は具象**（空実装済みで override 任意） |
| net48 MVC の認可 | **`web.config` の `<authorization>` と `[Authorize]` の二段構え**。属性だけではない（Web Forms の `<location>` に相当するのが属性） |
| Core の必須構成 | `Startup` で `services._AddHttpContextAccessor()` / `app._UseHttpContextAccessor()` を呼ばないと `UserInfoHandle` が動かない（`MyHttpContext.Current.Session` に依存）。**忘れてもコンパイルは通る**。先頭の `_` は誤記ではない |
| resource パスは環境変数方式（実測フィードバックで判明・`ResourceLoader` で確認） | **相対パス（`resource\...`）は不可。** `ResourceLoader.Exists` は設定値をフルパス前提で `File.Exists` に渡し、相対はプロセスのカレント基準＝IIS Express/w3wp ではアプリ外で 500。解決の直前に `StringVariableOperator.BuiltStringIntoEnvironmentVariable` が **`%環境変数%` を展開**するので、`%OT_RESOURCE_ROOT%\...`（リポジトリ直下 `resource\` を指すユーザ環境変数、セットアップ スクリプトで設定）に張り替える。可搬性も保てる。`project-setup` ⑥ を相対→環境変数方式に是正（作者承認 2026-07-17） |
| ベンダ対象は `Build_*\` の DLL 全部（同上・csproj で確認） | **`OpenTouryo.*` だけではない。** net48 WebForms_Sample の `MySql.Data` / `Oracle.ManagedDataAccess` は `packages.config` に無く HintPath が他サンプルのビルド出力（`WS_sample\Build`）を指すため **NuGet 非復元**。基盤ビルド出力 `Build_net48\` に同梱（`OpenTouryo.DamMySQL` / `.DamManagedOdp` の依存）されるので、これらも `OpenTouryo.*` と同様にベンダ先へ張り替える。「触らない」のは NuGet 復元される 3rd-party だけ |
| net48 は `nuget restore` が必須（同上・公式 `10_Build_WebApp_sample.bat` で確認） | `packages.config` 方式は **msbuild の前に `nuget restore <sln>`**（`msbuild /t:restore` では復元されない）。`nuget.exe` は ZIP 同梱の `root\programs\nuget.exe` を流用。`project-setup` ⑦ に追記 |
| 3層サンプルの2層化はセットアップ範囲外（作者方針 2026-07-17） | WebForms_Sample は 3層構成で、ZIP に無い他サンプルのビルド出力（`WSServer_sample.dll` / `WSIFType_sample.dll`）に依存し、単体では as-is でビルドが通らないことがある。**当初スキルに「3層部分を削る」詳細手順を書いたが作者がオーバースペックと判断**：セットアップの役割は「取り出し・参照・リソース・config を整えてソリューションを開ける状態」まで。層の取捨・改変は利用者がソリューションを俯瞰して別途エージェントに依頼する後工程に委ね、セットアップ中に判断を求めない。スキルは短い「範囲外」注記に置換。**削る場合の実務知識（参考）**：2層画面 `sampleScreen_cc.aspx.cs` が `using WSIFType_sample;` で WS 側の型（`TestParameterValue` 等）を掴んでおり、同名クラスが同梱ソース（`AppCode\sample\Common\`、`using MyType;`）にもあるため `using MyType;` に差し替え。周辺（`3TierTableAdapter`・3層専用B層 `GetMasterData.cs`・menu のリンク）も除去。確実なのは WS 参照を外して `CS0246` を潰す手順 |
| net48 config の綴りは実フォルダと不一致（同上・app.config で確認） | net48 サンプルの app.config は `resource\XML\...`（大文字）・`resource\test`（小文字）だが実フォルダは `Xml` / `Test`。Windows では顕在化しないが **Linux で core を動かすなら実フォルダ側に config を合わせる**。当初スキルの「net48 は Xml」は逆だったので是正 |
| ベンダ元パスの起点（同上） | `Build_*` の生成場所は `<extract>\root\programs\CS\Frameworks\Infrastructure\`。スキルの xcopy 元は起点 `root\programs\CS\` を省いていたので明示 |
| 親クラス2 の所在とビルド（作者提案でスキル化） | 親クラス2＝`Frameworks/Infrastructure/Business`（`My*` 群、`OpenTouryo.Business(.RichClient)`）。親クラス1 の `UOC_*` 共通フックを **override** して接続・例外・ライフサイクル・画面初期化を注入。ビルドは `3_Build_Business_*`（`2_Build_NuGet_*` の後）。`opentouryo-base2-customize`（纏め者向け・作る側）を新設、`project-policy`（読む側）と対 |
| セットアップで `.gitignore` を生成（作者提案 2026-07-17） | `Temp/`（ZIP 展開・基盤ビルドの作業ツリー。丸ごとの基盤ソース＝親クラス2 を含む）を除外。標準 .NET 生成物（`bin/`/`obj/`/`packages/`/`.vs/`/`*.user`）も。`OpenTouryoAssemblies/`（ベンダ DLL）は**除外しない**（コミット） |
| 親クラス2 修正のバージョン管理＝オーバーレイ＋固定タグ（作者決定 2026-07-17） | 丸ごとではなく**修正ファイルだけ**を元パス保持で `base2-overlay/` に置きコミット（アプリ リポジトリ同居）。ビルドは固定タグ展開ツリーへ `xcopy base2-overlay\* → <extract>\root\programs\CS\` してから `3_Build_Business_*`。DLL は「固定タグ＋オーバーレイ」で再現可能。`develop` 不可（土台が動く）。複数アプリ共有時のみ纏め者専用リポジトリ。`base2-customize` / `project-setup` に反映 |
| 生成スクリプトが実環境で3回失敗（**実機検証 2026-07-18**：VS2026 / .NET SDK 10.0.302 / コンソール CP65001） | 基盤ビルド バッチを非対話で回すと3点で嵌る。①**末尾 `pause`** で入力待ち停止 → `< nul` で標準入力を塞ぐ。②生成 `.bat` の**全角コメント／`echo`** が UTF-8（`chcp 65001`）コンソールで破損し直後の `%変数%` 展開ごと壊れる → **ASCII 限定**。③`NoDefaultCurrentDirectoryInExePath=1` 環境で `.\` 無しの `call` が「認識されない」で失敗 → `call .\<bat>` と明示。模範 `3_BuildLibsAtOtherRepos.bat` にも注記が無く踏む。`project-setup` ③ に3点を追記 |
| WebForms_Sample の `Web.config` endpoint は3層固有でない（**実機検証 2026-07-18**・作者へ B 報告） | 当初 `project-transform` の「削る」に `Web.config` endpoint を挙げたが誤り。`system.serviceModel` の endpoint は 3層サンプル（`WSServer_sample`）用ではなく**フレームワークの Transmission WCF 設定**（`IWCFHTTPSvcForFx` / `IWCFTCPSvcForFx`）と `IJSONService`。`WSServer_sample` は DLL 参照でインプロセス呼び出しされ専用 endpoint を持たない。消すと2層化に不要かつ実行時構成を壊しかねない → **「触らない」に是正**。transform の他項（`using WSIFType_sample;`→`using MyType;` の罠、3層画面・`3TierTableAdapter`・`GetMasterData.cs`・menu リンク除去）は実機と完全一致で正確だった |
| VS エディションによる msbuild 解決は**利用側で対処**（**実機検証 2026-07-18**・作者判断） | 本体の `z_Common.bat` は **VS18 系で `18\Community` しか見ない**（VS2022 までは Community/Professional/Enterprise 網羅）。VS18 の BuildTools/Professional/Enterprise だけだと `BUILDFILEPATH` が空になり基盤ビルドが失敗する。当初 C として本体報告候補にしたが、**本体はエージェント/CI・新しい VS エディションでの非対話ビルドを想定して作られていない**ため本体の不具合ではなく**利用側（このセットアップ）で対処する前提**とする（作者判断）→ **Issue 化しない**。対処＝ビルド前に msbuild が解決できることを確認し、駄目なら Community 導入／msbuild のパス通し／`z_Common.bat` へ自環境パス補正。注記は `opentouryo-project-setup-build`（旧 setup-script.md）の「VS のエディション・バージョンによる msbuild 解決」節へ |
| 実機で追認できた既存指摘（**実機検証 2026-07-18**・D＝直さない確認） | 次はスキル記述どおりで正しかった：⑤3rd-party DLL 張り替え（`MySql.Data`/`Oracle.ManagedDataAccess` は NuGet 非復元でベンダ先へ）／⑥config 綴りの罠（`XML/test`→実体 `Xml/Test`）／⑥環境変数方式（`%OT_RESOURCE_ROOT%\...` を `ResourceLoader` が展開し IIS Express で解決）／⑦net48 は msbuild 前に `nuget restore <sln>` 必須・`nuget.exe` は ZIP の `root\programs\nuget.exe` 流用／「3層サンプルは as-is で通らないことがある・2層化は後工程」の切り分け。**変更不要** |
| ①の表が WS/3層依存サンプルを明示していなかった（**実走 2026-07-18** Web Forms/net48/tag 03-20・A） | `WebForms_Sample` は取り出し直後に `sampleScreen_cc.aspx.cs` が `WSIFType_sample`/`WSServer_sample`（`WS_sample\Build` 出力）へ依存し **`CS0246` が必ず残る**。総論の「3層サンプルの扱い」節はあったが①の表に印が無く、利用者が「Web Forms を選んだのに as-is で通らない」と面食らう。→ ①表に **「WS/3層依存」列**を追加（`WebForms_Sample`＝確定該当・実測、他は未確認）。表直下に**到達点＝「ソリューションが開ける状態」で as-is クリーンビルドは保証しない**を再明示。削減は transform |
| 非対話ビルドで追加2 footgun＋PowerShell ラッパ既定推奨（**実走 2026-07-18**・B） | 既知3注意は的中。実走で2つ追加：①`if(...)` ブロック内 `echo` の**未エスケープ `)`** でブロックが早期に閉じ後続 `goto :error` が無条件実行（ビルド成功でも Step 3 で失敗に見える）→ `^)` にエスケープ。②**Bash/MSYS 経由 `cmd //c ".\x.bat"`** は Windows 絶対パス引数が MSYS 変換され `if exist "D:\..."` が実在フォルダを MISSING 誤判定 → PowerShell の `cmd /c` から実行で正常。→ `opentouryo-project-setup-build`（旧 setup-script.md）の注意に2点追記＋**「エージェント/CI は PowerShell ラッパを既定推奨（子 .bat は `cmd /c`）」節**を新設 |
| 4バッチ順次実行は単一ランタイム標的に過剰（**実走 2026-07-18**・C） | ①では Web Forms＝net48 のみで netcore100 の基盤ビルドは不要（無駄な時間と失敗面が増える）。今回は net48 の2バッチにスコープして問題なし → `project-setup` ③ と `opentouryo-project-setup-build`（旧 setup-script.md）を **「標的サンプルのランタイムのバッチだけ回す（両対応が要るときだけ4本）」** に是正 |
| net48 Web Forms の config 二段構成（**実走 2026-07-18**・D 軽微） | 実効 config は `Web.config` だが、**パス系キーは `<appSettings file="app.config"/>` で読む `app.config` 側**、接続文字列は `Web.config` 直下、と分かれる。⑥の「app.config/appsettings.json のパス系キー」は結果的に正しいが初見だと `Web.config` を探して迷う → ⑥に一文追記 |
| `project-setup` を分割（作者提案・**2026-07-18**） | 容量は分割前も目安内（③詳細は既に外部ファイル化済み）で、分割の狙いは**凝集度と再利用性**。作者案は3階層（build / pickout / pickout-webforms）だったが、per-sample スキルは現状 WebForms しか実測が無く空スキルの乱立になるため見送り、**2スキル＋参照ファイル**に落とす（合意）。①**③基盤ビルド＝サンプル非依存・一度作れば使い回す・単独起動可**なので `opentouryo-project-setup-build` へ昇格（`setup-script.md` を昇格して削除）。②`project-setup` は入口オーケストレータ（①②④⑤⑥⑦）として据え置き、③は build スキルへ委譲。③**サンプル固有の癖は `samples/<name>.md` 参照ファイル**先行（`samples/webforms.md`＝WS/3層依存・config二段。内容が育ったら `-sample-*` スキルへ昇格）。インストーラは `Copy-Item ...\*  -Recurse` でディレクトリ丸ごと拾うため `samples/` も自動同梱。全29→30スキル。AGENTS.md 表・README 一覧・§3 インベントリに反映 |
| WS/3層依存の解消は「2層化」一択ではない＝**3層維持ルートを明文化**（作者指摘・**2026-07-18**。実ソースで確認済み） | それまで `webforms.md`／`project-setup` ①・③注記は `CS0246` の解消を **(B) 2層化＝transform** だけで書いていた。だが **`reference/csharp/` の実ソースで確認**：`WebForms_Sample.csproj` 252-256 は `WSIFType_sample` / `WSServer_sample` を `..\..\..\WS_sample\Build\*.dll` として参照し、`sampleScreen_cc.aspx.cs:21` が `using WSIFType_sample;`。**無いのはビルド出力だけで、`WS_sample\WSIFType_sample` / `WS_sample\WSServer_sample` のソースは実在**（`WSServer` は `..\WSIFType_sample` を ProjectReference。両者の参照は `OpenTouryo.Business/.Framework(/.Public)` のみで追加 3rd-party 無し）。**ビルド出力は `WS_sample\Build\`（`WSIFType_sample.dll`/`WSServer_sample.dll`）に落ちる**（作者確認。csproj の `OutputPath` は `bin\Release\` だが実出力先は外部ビルド スクリプトが決める＝`AfterBuild`/`PostBuildEvent` は空）。**WebForms 側の参照はそのまま `WS_sample\Build\*.dll` を指すので向け直し不要**。よって **(A) 3層のまま通す＝WS も取り出し⑤と同じ要領で `OpenTouryo.*` を張り替えてビルドするだけで `CS0246` が消える**（`Web.config` endpoint は Transmission 設定なので触らない）が正当で、**取り出し・参照張り替え＝セットアップの範囲で完結**する。→ `samples/webforms.md` を (A)/(B) 併記（(A) は実証済み具体手順）に、`project-setup` ①注記と「3層（WCF/WS）サンプルの扱い」節も両ルート併記に是正 |
| **アセット repo に C# 実ソースのミラー `files/csharp/` がある**（作者提示・**2026-07-18**。当初 `reference/csharp/`→`files/csharp/` へ移動） | **`files/csharp/`**（`Frameworks` / `NuGet` / `Samples` / `Samples4NetCore`）に OpenTouryo 本体の実ソースがミラーされている（例：`Samples/WS_sample/{WSIFType_sample,WSServer_sample,WSClient_sample,ASPNETWebService}`・`Samples/WebApp_sample/{MVC_Sample,WebForms_Sample}`・`Frameworks/Infrastructure/...`）。**スキルの主張（csproj の参照・HintPath・using・プロジェクト依存・取り出せるサンプルの網羅）はここで裏取りできる**。ビルド出力（`Build\` 等）は生成物なのでミラーには無い点に注意。※ このパスはセッション途中に `reference/csharp/` から移動（メモリ `reference-csharp-source-mirror` も更新済み）。以降の §で「`reference/csharp/`」と書かれた箇所は現 `files/csharp/` を指す |
| ①表に**3層リッチクライアント（WS クライアント）**を追加（作者提示・**2026-07-18**。実ソース確認） | WS/3層依存サンプルは WebForms だけでなく **`Samples\WS_sample\WSClient_sample`** 一式（`WSClientWin_sample`/`WSClientWPF_sample`/`WSClientWin2_sample`/`WSClientWinCone_sample`。いずれも `OutputType=WinExe`・net48、`WSIFType_sample`/`WSServer_sample` を `..\..\Build\*.dll` 参照＝**構成上の 3層依存**）。**.NET Core 版**も `Samples4NetCore\Legacy\WS_sample\WSClient_sample\` にある。→ ①表に「3層リッチクライアント（WS/WCF 経由・WinForms/WPF）」行を net48／.NET10 で追加（WS/3層依存＝**あり・構成上必須**）、①注記の「確定該当」を **WebForms＋WSClient 2系統**に拡張。WSClient は 3層で使う前提なので **(A) が本筋・(B) 2層化は非該当**。P層リッチクライアントは `richclient-async`／`layer-p-winforms-screen` も参照 |
| **SKILL-FEEDBACK.md 実走**（WebForms/net48/tag 03-20・VS18 Community・SDK 10.0.302・**深いリポ パス77字**・**2026-07-18**。IIS Express 起動＋DB 接続まで到達） | `feedback/SKILL-FEEDBACK.md`。反映：**(3)factual error＝`WS_sample` の場所**＝当初 webforms.md「`WebApp_sample` 配下」は誤り、正しくは `Samples\WS_sample`（`WebApp_sample` の**兄弟**。HintPath `..\..\..\WS_sample\Build` が `Samples\WS_sample\Build` に解決）→ webforms.md 修正。**(4)「WS をビルドすれば CS0246 が消える」は不十分**＝`msbuild WSServer_sample.sln` は各 `bin\Debug\` に出て `WS_sample\Build\` は `.sln` 直ビルドで生成されない → **ビルド後に `bin\Debug` の `WSIFType_sample.dll`/`WSServer_sample.dll` を `WS_sample\Build\` へコピー**（＋DB DLL をベンダ先から）まで必須。webforms.md (A)・⑤・「3層サンプルの扱い」に配置手順を明記（先の「作者確認＝Build\ に落ちる」は本体の外部ビルド スクリプト経由の話で、`.sln` 直ビルドとは別）。**(1)MAX_PATH(260)**＝深いリポ直下だと net48 Business ビルドが `MSB3553`（長い `.resources` 完全修飾パス超過）→ `setup-build` に「短い作業ルート `C:\ot` でビルド／long path」。**(2)MAX_PATH×nuget restore**＝相対配置維持だと `packages\...\analyzers\...\pt-BR\...` で超過 → ⑤・webforms.md に「深いリポは**リポ直下へフラット化**して HintPath 張替」。**(5)偽の成功**＝バッチは末尾 `pause` で msbuild 失敗でも exit 0 → `setup-build` に「exit code 不信・生成 DLL 実在（`OpenTouryo.Business.dll`）で判定」。**(6)接頭辞だけでない**＝サンプル HintPath は `…\Build\`（サフィックス無し）、ベンダ先は `Build_net48\` で末尾フォルダ名も変わる → ⑤是正。**(7)FYI**＝`2_Build_NuGet_net48.bat` は `Nuget_RichClient_net48.sln` も必ずビルド（RichClient DLL 生成・無害）→ ②注記。**(8)FYI**＝net48 Web の `sessionState mode="StateServer"` は ASP.NET State Service 前提（不要なら `InProc`）→ ⑦。**参考実装**＝as-built PowerShell 2本を `project-setup-build/examples.md` に収録（`setup-build.ps1`/`build-app.ps1`。雛形化時パラメタ化） |
| WS/3層の共通機構を **`webservices.md` へ切り出し**（作者提案・**2026-07-18**） | それまで WS/3層の取り出し・ビルド・`Build\` 配置・core 実用不可・MAX_PATH を `samples/webforms.md` に厚く書いていたが、これらは**サンプル非依存で、以降増える `WSClient_sample` ラインナップと共有すべき**共通機構。→ **`samples/webservices.md`**（共有 on-demand。`samples/` 配下に揃える＝作者指摘）に集約し、`samples/webforms.md` は **Web Forms 固有のみ**（cc 画面の `CS0246`・(B) の `using WSIFType_sample;`→`using MyType;`・config 二段）に縮小（60→28行）。SKILL.md の①注記・⑤・「3層サンプルの扱い」は「共通は `samples/webservices.md`／サンプル固有は `samples/<name>.md`」に是正。WSClient のサンプル メモを起こす際も `samples/webservices.md` を参照させる |
| 短ルート ビルド × 親クラス2 カスタマイズの両立（作者指摘・**2026-07-18**） | MAX_PATH 回避で基盤ビルドを短い作業ルート（`C:\ot\`）で回すと、**親クラス2 カスタマイズの元ソース `Frameworks/Infrastructure`（特に `Business`）がワークスペース外の使い捨てツリーにしか残らない**（`base2-overlay/` に残るのは差分だけ＝差分を起こす／当てる元が要る）。→ **通常アプリは DLL だけベンダで問題なし。親クラス2 カスタマイズ時のみ、基盤ソース `Frameworks/Infrastructure` をワークスペースにも展開しておく**（`.gitignore`・コミットは差分のみ・ビルドは短ルートで）。`opentouryo-project-setup-build` §1 の MAX_PATH 注記に例外を追記、`opentouryo-base2-customize` のバージョン管理節に「基盤ソースはワークスペースにも置く」＋ xcopy 例を `Temp\` 固定から `<extract>`（短ルート可）へ一般化 |

| `project-setup` SKILL.md をさらに圧縮（⑤⑥ 詳細を `references/` へ・作者要望・**2026-07-18**） | SKILL-FEEDBACK 反映で 250行/cl100k 6830（目安上限付近）まで膨張。核心（④⑤ の HintPath 張り替え・全体フロー）は inline のまま、**間違えやすい edge case（⑤）と機構詳細（⑥）を on-demand の `references/` 新設フォルダへ退避**：`references/reference-rewrite.md`（接頭辞だけでない・`Build_*` の DLL 全部＝MySql/Oracle 非復元・MAX_PATH フラット化）、`references/resource-config.md`（相対不可の理由＝`ResourceLoader`・`%VAR%` 展開が `FxContainerization` と別機構・パスキー一覧・綴りの罠・config 二段）。config は `opentouryo-config` へ丸投げせず相互参照（`%OT_RESOURCE_ROOT%` のパス内 `%VAR%` 展開と `FxContainerization` の値まるごと上書きは別物のため）。→ **217行/cl100k 5747（≈ Claude 4,300・目安内）**。`samples/`＝サンプル別、`references/`＝横断リファレンス、の2フォルダに整理 |

| **E2E 実行レポート**（WebForms/net48/tag 03-20・VS18 Community＋VS2022・SDK 10.0.302・**2026-07-18**。**全工程クリーンビルド＋実機動作確認済み**：フラット化→2層化→サンプル整理、残 aspx 10・csproj 527行） | 全スキル記載どおり通過を追認（setup-build の「exit code 不信＝`OpenTouryo.Business.dll` 実在で判定」・reference-rewrite の末尾フォルダ名変更／MySql・Oracle 張替／フラット化・webforms/webservices の (A) 3層維持＝`bin\Debug`→`WS_sample\Build\` 配置／`using MyType;`・resource-config の `%OT_RESOURCE_ROOT%`／config二段・⑦の `InProc`／`nuget restore`）。**改善反映（transform）**：①**改行 LF**＝サンプルの csproj/config は LF（GitHub ZIP 由来）で CRLF 前提の複数行置換が失敗→基本方針。②**非対話 PS ガード誤検知**＝`Remove-Item` と `/>` 断片を同一コマンドに混ぜると「システムパス削除」誤検知でブロック→削除と置換を分ける・基本方針。③**2層化の DB DLL**＝WebForms csproj は `MySql.Data`/`Oracle.ManagedDataAccess` も `WS_sample\Build\` 参照、完全2層化には要張替→「削る」節。④**★`test*` でも実マスタ**＝`testBlankScreen.master` は login/logout/menu/ErrorScreen/OAuth2 の MasterPageFile。`test*` 一括削除で足場全滅→新設「サンプル整理」節＋`samples/webforms.md` に固有名（残す＝`testBlankScreen.master`／CRUD＝`sampleScreen.master`）。⑤**csproj 大量剪定**＝「実在しない Include を消す」XML DOM 剪定（PreserveWhitespace＋空白ノード除去・ワイルドカード/Reference 除外）→「サンプル整理」節 |

| ②「固定タグ」で例示 `03-20` が強制選択された（作者フィードバック・**2026-07-18**） | 取得元で「固定タグ（安定運用）」を選ぶと、エージェントが**例示の `03-20` を勝手に既定値として使い、どのタグか選べなかった**。② の表が「固定タグ｜例 `03-20`」と例示を弱く書いていたのが原因。→ `project-setup` ② に「**固定タグを選ばれたら具体的なタグ番号を必ずユーザに確認する。`03-20` は例示で既定値にしない**」を明記し、タグ一覧の確認先（`.../OpenTouryo/tags`）を追加。`project-setup-build` の入力表・`examples.md` の `$ref` コメントも「例示・プロジェクトごとに設定」に補強 |
| 親クラス2 スキル2本を **Business 実ソース全スキャンで網羅性検証**し抜けを追補（作者依頼・**2026-07-20**。`C:\otr\OpenTouryo-03-20\...\Frameworks\Infrastructure\Business` 全 .cs） | `opentouryo-project-policy`（読む側）/`opentouryo-base2-customize`（作る側）はコア論点（接続・例外・ログ・イベント結線・ユーザ情報・メッセージ）は正確だったが、**「（テンプレート）／自由に拡張して利用できる」と明記の親クラス2 が5〜8クラス両スキル未言及**と判明。作者指定の優先度で上限まで追補：①`Common/MyParameterValue`・`MyReturnValue`（引数/戻り値親クラス2・`[Serializable]`＝WS転送）②`Presentation/MyBaseAsyncApiController`(±Core)（**Web API＝P層処理方式が丸ごと欠落**・`EnumHttpAuthHeader` の Basic/Bearer 認証・権限/閉塞 stub・ACCESS/例外ログ）③`RichClient/Asynchronous/MyBaseAsyncFunc`（非同期親クラス2・`UOC_*`・`CanOutPutLog`）④`RichClient/Util/RcMyCmnFunction`（WinForms のイベント結線・`ShowErrorMessage*`）⑤`Util/MySubsysInfo`・`MyAttribute`（サブシステム区分・独自メタ属性＝継承/追加で拡張）。base2 は層別マップ＋差し込み点表、policy は P層処理方式表＋確認地図＋A表へ反映。スコープ外＝`_3TierEngine`/`CstSqlSessionStateProvider`/`CmnDao`/`BaseConsolidateDao`/`Mu*・_3Tier* Value`/`GMTMaster`/`MyTimeZone`(internal)/`MyMVCCoreFilterAttribute` 等（フレームワーク側インフラ・生成物・internal）。tok：base2 3772→4306、policy 3238→3573（いずれも auth 4952 実績上限内） |
| `opentouryo-project-policy` の検証実行レポート6点＋①テーブル現行化を反映（実機検証・**2026-07-21**。overlay 無し・Temp 無し・DLL のみ構成で分岐を実走） | 最頻ケース（DLL のみ／未改変確定）で手順が途切れる問題群。**根＝①のソース所在テーブルが古い**（`Temp/OpenTouryo-<ref>/...` だけ書き短ルート `C:\otr\OpenTouryo-<ref>\root/programs/CS/...` を欠く。両者とも使い捨て）＋**`<ref>` が構築後 repo のどこにも残らない**（`setup-build` は入力扱い・展開ツリー使い捨て、`SETUP-CHANGES.md` はマシン変更用でタグ非記録＝grep 確認）。高：①上流取得フォールバックに手順が無く `<ref>` 復元不能→①表を現行化＋「最頻ケース手順（`build-ref.txt` から `<ref>`／無ければ聞く→`archive/<ref>.zip` の `root/programs/CS/...` を読む）」を新設。②L80『DLL でも道あり』とL87『DLL なら即③』の矛盾→「`.dll` しか無くても即③ではない」に統一。中：③**overlay 空＝未改変の肯定確定**を活かせず L166 と衝突→「overlay 機構下で overlay に無ければ既定値＝仕様と確定してよい」を L166 の明示例外として追記。④「接続文字列キー/DBMS」分類ズレ→キーは config 先読み・DBMS は `actionType` 接頭辞ごとで単一でない、を A表と②に反映。軽微：⑤確定事実の恒久置き場が無い→プロジェクト方針ノート記録の導線（AGENTS.md/SETUP-CHANGES.md には書かない）。⑥空振り起動ガード→適用範囲に追記。**併せて産出側 `setup-build` §3 に `<ref>` 記録指示（`OpenTouryoAssemblies\build-ref.txt`）を追加**し policy の復元手順と接続。tok：policy 3573→4208、setup-build 4935→4995（上限内） |
| `opentouryo-base2-customize` の検証実行レポート（Oracle 除去タスク）7点を反映（実機検証・**2026-07-21**。`C:\otr` 実ソース＋RichClient csproj で全点裏取り） | A-1**deprecated 双子への UOC 重複**：`UOC_ConnectionOpen` は `MyFcBaseLogic`/`…2CS` だけでなく `[Obsolete]` の `MyBaseLogic`(L72)/`MyBaseLogic2CS`(L70) にも同分岐が重複（実測）＝片方だけ直すと DLL に旧 `ConnectionString_ODP` 残存→差し込み点表に「4クラス全部直す」を明記。A-2**DBMS 増減は"面"**：分岐削除だけでは csproj `<Reference>`+`HintPath`（`DamManagedOdp`。RichClient net48 csproj L69-70 で実測）・ベンダ Dam DLL・config `ConnectionString_<code>` キーが残る→4点チェックリスト新設。A-3/A-4（ビルド機構＝`examples.md` 2b へ）：`BusinessRichClient_net48.sln` は**非SDK・HintPath のみ**で `/t:restore` が `Microsoft.NuGet.targets` エラー→`/t:build` 単体に修正（例スクリプトが `/t:restore,build` の実バグを保持していた）。net48/netcore RichClient が **`RichClient\obj\` 共有**（obj に v4.8 と net10 が同居＝実測）→ビルド前に `obj\project.assets.json`・`obj\*.nuget.*` を掃除（＝RC を `C:\otr\rc` で別ビルドしていた真因）。B-1 overlay 適用の責任＝実は `setup-build/examples.md` 1b に既存→base2 手順②から導線強化（「任意」表記で見落としやすい点のみ）。B-2 「展開ツリー直接編集」と「script overlay 上書き」二重→**正典1本**（tag 再生成→overlay 適用が唯一の変更経路・直接編集は必ず overlay 取込）を明記。C-1（参考・upstream）ODP ガードが4クラスで不揃い（`#if NETCOREAPP2_0` 旧ガード・net10 未定義で実質無効）→境界節に一言。tok：base2 4306→4878（examples.md は参照ファイルで予算外・setup-build SKILL は 4995 据置）。**追記（作者提示の as-built 差分 `OTRVCAS/scripts` で裏取り）**：私の examples.md obj 掃除パスが誤り（`Infrastructure\RichClient\obj`＝不在）→実物どおり **`Business\RichClient\obj` と `CustomControl\RichClient\obj` の2つ**に修正（`ls` で実在確認）。1b overlay 適用・2b `/t:build`・obj 掃除 loop はすべて as-built と一致を確認 |
| **「選択肢を間引かない」を横断ポリシーとして `AGENTS.md` に集約**（作者提示の chooser 描画・**2026-07-21**） | base2-customize の差し込み点選択で、スキルは8+項目を挙げるのに実 chooser が**固定4択に畳み `%1/%2`・Web API 認証・引数戻り値・非同期・サブシステム/属性を脱落**＋無関係項目を併合（例外画面＝UOC_ABEND＋事前定義例外、接頭辞＋ライフサイクル）。①サンプル選択で既出の同一病理の再発。setup-selection には既に対策文言があるが base2 には無し。**base2 は tok~4891 で予算逼迫＋横断的問題**のため、各スキルに重複させず `AGENTS.md`「その他のポリシー」（TODO プレースホルダ）へ一度だけ集約：「固定 N 択に畳んで落とさない・無関係項目を併合しない・UI が絞るなら全候補を番号付きリストで」＋実測脱落例（サンプル系列／差し込み点）を明記。全スキルに波及。tok：AGENTS.md 3396→3580。**さらに作者方針で「重複させる」＝AGENTS.md はインストーラ再生成で上書き／誤削除されうるので、スキル単体でも効くよう冗長化**：base2-customize の やってはいけない にも簡潔版を複製（setup-selection は既にスキル側にも保持済み＝両者で冗長）。base2 予算逼迫のため step2 の RichClient 詳細を examples.md 2b（正本）へ寄せて圧縮し捻出。tok：base2 4878→4954（auth 4952 相当・上限内） |
| **実装着手前に各スキルへコピー元コードスニペット `references/snippets.md` を整備（完了）**（作者依頼・**2026-07-23**。UserGuide 正典＋C# 実ソース裏取り。作者選択の範囲＝開発者日常コード層＋機能スキル群＋纏め者側、新領域〔AsyncEventFx/CustCtrl/Ajax〕は除外） | 各スキルに **on-demand `references/snippets.md`**（SKILL 予算外・インストーラが `-Recurse` で自動同梱）を新設し、SKILL 本文 H1 直後に `> 📋 コピー元` 導線を1行追加（導線が無いと参照が見えないため必須）。**計25スキル完了**：①データ/業務中核7（layer-b・layer-d・p-call-business・dao-custom・dao-common・dao-generated・query-definition）②P層5（layer-p-webforms-screen/event・layer-p-mvc・layer-p-winforms-screen/event）③機能11（exception・message・logging・config・transaction-control・transmission・screen-transition・shared-property・webforms-dialog・auth・richclient-async）④纏め者2（base2-customize＝UOC override テンプレ集／project-policy＝読む側の見どころ断片＋質問テンプレ）。実ソース裏取り例：`new CmnDao(this.GetDam())`/`cmnDao.SQLFileName`/`new DaoShippers(this.GetDam())`/`genDao.D5_SelCnt()`/`Crud1Controller: MyBaseMVController`+`DoBusinessLogicAsync`+`SelectIsolationLevel(model.DdlIso)`／`BusinessApplicationException(id,msg,info)`〔3引数＝doc の2引数は誤り・是正〕／`BusinessSystemException(id,msg)`／`UserInfoHandle.GetUserInformation<T>()`(Core)/`GetUserInformation()`(net48)／`LogIF.InfoLog(logger,msg)`／`GetMessage.GetMessageDescription`／`GetSharedProperty.GetSharedPropertyValue`／`BaseLogic.InitDam(patternID,dam)`。全 SKILL 5000未満維持（auth 4980・base2 4989 は導線を短縮して収めた）。※新領域4件（AsyncEventFx/CustCtrl/Ajax/親クラス3）は範囲外で未着手 |
| **公式 FAQ「B層フレームワーク」から未収録の上級Tx/層省略5件を取り込み**（作者提示 URL・**2026-07-24**。BaseDam.cs/DamOraClient.cs で裏取り） | FAQ の大半（`UOC_ConnectionOpen` で Open+Tx開始・完了時に自動Close/commit/rollback・例外時のみロールバック・2CS 手動 `CommitAndClose`/`RollbackAndClose`・属性ベースTx・`SetDam`/`GetDam`・複数DBMS接続）は既収録。**未収録5件を追加**（いずれも「標準化観点で例外認可を個別検討」の非標準エスケープハッチとして注記）：①**手動トランザクション制御**（B層は `this.GetDam()` の Tx メソッドで手動制御可＝新規 Dam 生成不要。**2度是正**：2本目以降の接続は**キー付き Dam＝標準機能**。サーバ側 `BaseLogic` は `SetDam(key,dam)`/`GetDam(key)`＋`_dams`〔`Dictionary<string,BaseDam>` L87/523/494〕で複数 Dam を管理下保持し**一括コミット/ロールバック**。★2CS `BaseLogic2CS` はキー付き `SetDam` なし・単一 `static _dam`〔L69〕のみで、追加接続は `InitDam(パターン,dam)` で開けるがコミット/クローズは手動〔`CommitAndClose` は `_dam` だけ〕。`TransactionControl.InitDam` は Dam を保持せず開くだけ）②**分割コミット**（`this.GetDam().CommitTransaction()`→`BeginTransaction(iso)`。`BaseDam.cs` L3011-3019 で実在確認）③**SAVEPOINT**（プロバイダ固有。Oracle `((DamManagedOdp)this.GetDam()).DamOracleTransaction.Save/Rollback`。`DamOraClient.cs` に `public OracleTransaction DamOracleTransaction` 実在）④**2フェーズコミット未サポート**（`TransactionScope` 対応の親クラス1 を作れば可・需要低で見送り）→ ①〜④は `opentouryo-transaction-control` 本文に新節「高度なトランザクション操作（★非標準・要相談）」＋snippet にコード。⑤**層の省略**（P層で直接 `Dam`＝P層のみ/P・D層、共通Dao/自動生成Dao で自作Dao 割愛＝P・B層のみ。非標準）→ `opentouryo-layer-b`「層の省略」節。tok：transaction-control→1882・layer-b→4157（全て上限内） |
| **公式 FAQ「ASP.NET P層フレームワーク」から未収録項目を取り込み**（作者提示 URL・**2026-07-24**。実ソースで全点裏取り） | FAQ を WebFetch し既存スキルと突合。取り込み：**[高] 共通エラー画面は素の `System.Web.UI.Page`**（`ErrorScreen.aspx.cs` を OTRVCAS で確認＝`: System.Web.UI.Page`。`MyBaseController` 継承すると `SessionAbandonFlag` 重複でエラーループ）→ webforms-screen 本文＋やってはいけない。**[中] ログイン/予期せぬ Session タイムアウト対策3択**（P層FW非使用／`IsNoSession=true`／`FxSessionAbandon`。継続運用なら関連機能 OFF）→ auth 本文はポインタ・詳細は auth snippet（本文満杯のため）／webforms-screen ログイン節に3択導線。**[中] P層セキュリティ/セッション スイッチ**（`FxDoubleTransmissionCheck`=二重送信防止／`FxRequestTicketGuidMaxQueueLength`=不正操作防止／`FxButtonhistoryMaxQueueLength`=ボタン履歴／`FxScreeenGuidMaxQueueLength`・`FxWindowGuidMaxQueueLength`=セッション領域自動削除。FxLiteral.cs で実在確認）→ config 表＋説明。**[中] ウィンドウ別セッション領域**（`SetDataToBrowserWindow`/`GetDataFromBrowserWindow`＝BaseController.cs で確認・複数ウィンドウ対応）→ webforms-dialog。**[中] IFRAME 親画面操作不能→`Form.Attributes.Remove("onSubmit")`**→ webforms-dialog。**[中] MenuItem 対応**（`UOC_FormInit` で `MenuItem.Click` に共通ハンドラ・ベース2 不要）→ winforms-event。**[低] 接頭辞 空指定=イベント処理キャンセル・動的生成も再帰結線**→ webforms-event、**マスタ ネスト可**→ webforms-screen、**HTML タイトル=`UOC_CMNFormInit` で `Page.Title`**→ base2 snippet。**取り込まず**：旧ブラウザ互換・Enter 抑止差異・カスタムコントロールJS法/グリッド内ラジオ（CustCtrl 領域=保留）。全 SKILL 5000未満維持（auth 4997・base2 4989 は追記を snippet 側へ回して収めた） |
| **公式 FAQ「D層フレームワーク」から未収録項目を取り込み**（作者提示 URL・**2026-07-24**。実ソースで全点裏取り） | FAQ を WebFetch し既存 D層スキルと突合。**A（未収録）を反映**：**A1 ストアド**（`SetSqlByFile2(名前, CommandType.StoredProcedure)`〔`Business/Dao/MyBaseDao.cs` L68〕・複数結果セット=`ExecSelect_DR()`→`DataTable.Load()`/`NextResult()`）→ dao-custom 本文＋snippet／dao-common はポインタ拡充。**A2 配列バインド**（ODP.NET/HiRDB。`((DamManagedOdp)this.GetDam()).ArrayBindCount`〔`DamManagedOdp.cs` L134〕＋各パラメタ配列・`OracleDbType` 必須。FAQ の `DamOraOdp` は旧称）→ batch-update「大量データ」節＋dao-custom 本文/snippet。**A3 IsDPQ 静的フォールバック**（`.xml` 書式検証→正なら動的DPQ・不正なら静的SQLへ・`IsDPQ`〔`BaseDam.cs` L155〕で判別）→ query-definition 本文。**A4 ORA-00972**（接頭辞/接尾辞で識別子30字超→ツール設定で短縮再生成/一括置換）→ dao-generated 本文。**A5 埋め込みDLL からSQLロード**（`EmbeddedResourceLoader.LoadAsString()`〔`Public/IO` L179〕・Azureスイッチ・`SetSqlByFile2` カスタマイズ・`GetManifestResourceNames()`）→ query-definition 本文ポインタ＋snippet。**A6 名前バインドのみ**（ODP.NET固定・OLEDB/ODBC/HiRDB は内部変換）→ query-definition 本文。**B（補強）**：**大量SELECT は `ExecSelect_DR`(DataReader) が `ExecSelectFill_DT` より速い（10万件目安）**→ dao-common/dao-custom／**CommandTimeout はconfig `SQL_COMMANDTIMEOUT` でも設定可**〔`BaseDam.SetCommandTimeout` L259〕→ dao-common。**既収録で対象外**：デッドロック/ロックタイムアウト/キー重複→業務例外（exception 既載 L83）・200タグ性能・`<>`エンコード・IN句 SUBタグ・パラメタ名ユニーク制約・SetParameter 型/サイズ・SetUserParameter ポリシー・楽観排他/タイムスタンプ・DAO使い分け。**A7 CLOB は作者指示で見送り**。tok：query-definition 4235→4469・dao-custom 2581→2896・dao-common 2139→2273・dao-generated 2149→2272・batch-update 1840→1925（全上限内） |
| **公式「バッチクエリ作成支援機能」ページ照合で `ExecGenerateSQL` 署名の誤りを是正**（作者提示 URL・**2026-07-24**。`SQLUtility.cs`/`BaseDao.cs`/`BaseDam.cs`/`CmnDao.cs` で裏取り） | ページは batch-update「大量データ」節（`SQLUtility`/`GetInsertSQLParts`/`GetUpdateSQLParts`/`ExecGenerateSQL`）と既収録で新規取り込みは不要だが、**照合でスキルの誤りが判明→是正**：①**`ExecGenerateSQL` の署名は `(SQLUtility sqlUtil)` の1引数**（`BaseDao` L413=`protected`／`CmnDao` L373=`public new`／実体 `BaseDam` L3156 abstract。委譲 `this._dam.ExecGenerateSQL(sqlUtil)`）。スキルの `ExecGenerateSQL(fileName, sqlUtil)` は誤り→本文・snippet 両方是正。②ページの「第2/第3引数＝型/日付書式」は `GetInsertSQLParts` ではなく**`SQLUtility` コンストラクタ引数**（`SQLUtility(dbms[, convertString[, dateTimeFormatString]])`。SQL Server 既定 `nvarchar`／`yyyy/MM/dd HH:mm:ss.fff`。`GetInsertSQLParts(dt)`=1引数・`GetUpdateSQLParts(dt, pk[])`=2引数）→ snippet に明記。③補強＝値はパラメタでなく SQL 文字列へ展開（パラメタ数上限回避）・`Convert()` で型明示・`NULL` 明示・複数 UPDATE は `;` 連結（snippet）。tok：batch-update 1925→1964（上限内） |
| **↑の①「ExecGenerateSQL 署名是正」を再是正（前回の是正が行き過ぎ）**（**2026-07-25**。生成物 `DaoShippers.cs` L568 で裏取り） | 前回 `Frameworks/Infrastructure` のみ見て「署名は1引数、`(fileName, sqlUtil)` は誤り」としたが、**自動生成 Dao の生成物は公開の2引数 `ExecGenerateSQL(string fileName, SQLUtility sqlUtil)` を持つ**（`WebApp_sample/.../Dao/DaoShippers.cs` L568。中身＝`SetSqlByFile2(fileName)`→`SetCommandTimeout()`→`SetParametersFromHt()`→`base.ExecGenerateSQL(sqlUtil)`）。つまり元の `(fileName, sqlUtil)` は正しかった。正：**自動生成 Dao＝公開2引数 `ExecGenerateSQL(fileName, sqlUtil)`／基底 `BaseDao`＝1引数 `protected`／`CmnDao`＝1引数 `public new`／実体 `BaseDam`**。本文・snippet を生成物のコード付きで復元。教訓：生成物（`Samples`）まで見る。tok：batch-update 1964→2027（上限内） |
| **spec→plan→実装ワークフローの規約化＋評価用チュートリアルの配布**（作者提案・plan mode 承認・**2026-07-25**） | 導入先での「使い始め」導線＋作者の field-test ハーネスを兼ねる。**確定判断**（ユーザ選択・全て推奨案）：①配布ソースは `src/` 配下＝新カテゴリ **`src/docs/{spec,plan,tutorial}/tutorial1.md`**（repo直下 `docs/` は執筆ガイド専用のまま。SSOT を `src/` に一元化）②インストーラは **opt-in `-IncludeTutorial`**（既定挙動不変・利用者の実 spec/plan を上書きしない）③AGENTS.md は**推奨デフォルト**として明記（強制しない）。**題材**＝サンプル DB **Shippers**（`ShipperID`/`CompanyName`/`Phone`・**タイムスタンプ列なし**を `DaoShippers.cs` で確認）の CRUD を Web Forms/net48 で1機能。通過スキル＝query-definition/dao-generated/layer-b/webforms-screen＋event/p-call-business/exception。**実装**：`src/docs/` に spec（要件・受入条件）/plan（使用スキル・ファイル・手順・層分離チェック）/tutorial（手順＋評価チェックリスト）を新設。`install.ps1` に `-IncludeTutorial`＋`$DocsSource`＋docs 配布ブロック（`Write-AssetFile` 流用＝マーカー無し内容は既存があれば `-Force` 時のみ上書き）＋Help 2件。`src/instructions/AGENTS.md` に「開発の進め方（spec→plan→実装：推奨）」節（「スキル」節の前・約12行）。README 構成図に `src/docs/`／`-IncludeTutorial` 例／進め方節。**git 操作なし。**§3 スキル件数は不変（新規スキルなし） |
| **作者 field-test（TestPlan2.txt ①）レポートの反映**（**2026-07-25**。全点を実ソース／as-built `OTRVCAS`／実 csproj で裏取り） | 8指摘を裏取りし**既出と真ギャップを区別**。**既出（レポートは旧版スキル実行）**：#2 マスタ新規作成（`BaseMasterController`＋12 Fx 隠しフィールド＋`Fx_Document_OnLoad`）・#3 非SDK csproj 登録（Content/Compile/DependentUpon/ASPXCodeBehind/designer 手書き）・#4 `actionType.Split('%')[0]`→接続選択（p-call-business に既節）は現行スキルに収録済み。**是正/追加**：**#1 画面遷移スイッチ**＝`FxScreenTransitionMode`（主・T/R/off）が off だと `FxScreenTransitionCheck`（副）に関わらずチェック強制無効〔`BaseController.cs` `_transitionMethod==off`→`_transitionCheck=false`〕。既収録だが表崩れ＋主スイッチ明示が弱く、**表を修復し主/副の真理値表に**＋OTRVCAS は Mode=off で実際は無効の注記（screen-transition）。**#6 誤ったキー名を是正**＝ボタン履歴 on/off は `buttonHistoryRecorder`（存在しない）でなく **`FxButtonhistoryMaxQueueLength`（>0でON・≤0でOFF）**〔`BaseController.cs` L1013-1022〕（webforms-dialog）。**#5 グリッド削除レシピ（真ギャップ）**＝`DataKeyNames`＋`LinkButton CommandName="Delete"`＋`UOC_..._RowDeleting(FxEventArgs, GridViewDeleteEventArgs e)`＋`DataKeys[e.RowIndex].Value`＋動的コマンドボタンは `EnableEventValidation="false"`〔OTRVCAS `testGridView` で裏取り〕（webforms-event 本文＋snippet）。**#8 真ギャップ（軽）**＝`return url` の Transfer/Redirect は Mode=off 時 app キー **`ScreenTransitionMethod`（1=Transfer/2=Redirect）**〔`MyBaseController.cs` L535-550〕（screen-transition）。**#2 細部是正**＝実 as-built マスタは直リンクでなく **ASP.NET バンドル**（`Scripts.Render("~/bundles/touryo")` 等）＋`onload="Fx_Document_OnLoad();Fx_AdjustStyle();"`（webforms-screen snippet）。**#7**＝`UserInfoHandle`/`FxEnum.IconType` は `Touryo.Infrastructure.Framework.Util`＝webforms-screen snippet に using 早見を追加（auth snippet には既載）。tok：screen-transition 2010・webforms-event 3748・webforms-dialog 2494（全上限内） |
| **`testFxLayerP/table` サンプル（GridView/ListView/Repeater）を webforms-event snippet に取り込み**（作者指示・**2026-07-25**。`Samples/.../table/test{GridView,ListView,Repeater}.aspx.cs` で裏取り） | データバインド系グリッドの実装パターンを snippet 化（予算外）。**#1 第2引数を具体型の表に**：`RowUpdating`→`GridViewUpdateEventArgs`／`RowDeleting`→`GridViewDeleteEventArgs`／`PageIndexChanging`→`GridViewPageEventArgs`／`Sorting`→`GridViewSortEventArgs`／`RowCommand`・`SelectedIndexChanged`は第2引数なし。**UOC で来るのは「…ing」系のみ**、対の `RowEditing`(`GridViewEditEventArgs`)/`RowCancelingEdit`/`SelectedIndexChanging`/`…ed` は**標準ハンドラ `(object sender,…)` のまま**。**#2 編集/削除/コマンドの実レシピ**：`RowUpdating` は `Rows[e.RowIndex].FindControl("…")` で編集セル取得＋`DataKeys[e.RowIndex].Value` でキー＋`EditIndex=-1`→再バインド／`RowCommand` は `InnerButtonID` にコマンド名。**#3 Repeater/ListView**：行内 AutoPostBack コントロールは自前 UOC に来て **`PostBackValue`＝アイテムの index**（`Items[int.Parse(PostBackValue)].FindControl`）。★ ListView 編集系（`ItemUpdating`/`ItemDeleting`/`OnItemCommand`）は `(object sender, ListView…EventArgs e)` 署名で来る実装があり既存に合わせる。`FxEventArgs.PostBackValue` の説明も「コマンド名」→「アイテム index」に精緻化。**追加取り込み（`.aspx` マークアップ）**：Repeater は `CommandName="<%# Container.ItemIndex %>"`（＝`PostBackValue` の正体）・`HeaderTemplate`/`ItemTemplate`/`FooterTemplate`・`DataBinder.Eval`／ListView は `LayoutTemplate` の **`itemPlaceholderContainer`/`itemPlaceholder` 必須**・`OnItemEditing`/`OnItemCanceling` をマークアップ結線・`CommandName="Edit/Delete/Update/Cancel/Sort"`(+`CommandArgument`)・`Bind`・`DataPager`(`PagedControlID`/`PageSize`/`NumericPagerField`)・カスタムコントロールの `Register`。**さらに ListView/Repeater のコードビハインドも追加**：Repeater＝バインド（DataSource は公開プロパティ・`HeaderInfo` 辞書）＋全行読み戻し（`foreach RepeaterItem … FindControl`）／ListView＝`BindListViewData`（Session の DataTable→`DataBind`）・編集ライフサイクル（`ItemEditing`/`ItemCanceling` は標準・`ItemUpdating`/`ItemDeleting`/`OnItemCommand` は `UOC_` でも `(object sender, ListView…EventArgs e)`）。**★GridView と違いキーは `e.RowIndex` でなく `e.ItemIndex`**／`OnItemCommand` は対象外で `null` 返し／Sorting・PagePropertiesChanged は `FxEventArgs` 版。webforms-event 本文は不変（snippet のみ）。**その後、3コントロールの記載レベルを統一**：散在していた markup/コードを「共通ノート＋操作×型の対比表＋各コントロール `### GridView`/`### ListView`/`### Repeater`（各 `#### .aspx`／`#### .aspx.cs`）」の並列構成に再構成（GridView にも `BindGridData`/`RowEditing` を足して対等化）。**SKILL.md からリンク**：削除レシピ節を「一覧表示系の実装」節に置換し `references/snippets.md#gridview`/`#listview`/`#repeater` へリンク＋要点（`DataKeyNames`・`RowIndex`/`ItemIndex`・`EnableEventValidation`・`PostBackValue`=index）。SKILL の `PostBackValue` 説明も「コマンド名」→「アイテム index」に是正。tok webforms-event 3801（上限内） |
| **公式「自動生成Dao性能対策」ページから未収録の「クエリ・キャッシュ」機能を取り込み**（作者提示 URL・**2026-07-24**。生成物 `DaoShippers.cs`＋`LayerB.cs` L538 で裏取り） | **未収録の実機能を dao-generated に追加**。列数の多いテーブルの自動生成 Dao は動的PQ組立コストが高く、コンストラクタに**クエリ・キャッシュ ID** を渡すと組立済み SQL（`CommandText`）を静的 SQL として再利用。実ソース裏取り（WebForms 版生成物）：`protected static ConcurrentDictionary<string,string> CDicQueryCache`〔L53〕＝**Dao クラス単位の static**・キー＝`CacheId+sqlFileName`／コンストラクタ2種〔無印 L94・`(dam, cacheId)` L99〕／ラッパ〔L313-350〕は CacheId 空=毎回 `SetSqlByFile2`、ヒット=`SetSqlByCommand(キャッシュ済)`、ミス=組立後 `DamIDbCommand.CommandText` を格納。使用例 `new DaoShippers(this.GetDam(), "f54d…")`〔`WebApp_sample/.../LayerB.cs` L538〕。規則：**生成テンプレートを `DaoTemplate2` に切替再生成**（ツール app.config `DaoTemplateFileName`=`DaoTemplate2`）／**ID は固定値（GUID か完全修飾名）・`Guid.NewGuid()` 不可**（ヒットせず肥大）／**同一 ID は同一パラメタ・セットのみ**（動的タグ差で `CommandText` が変わり不一致エラー）／別 Dao とは非共有／v02-50 追加・テンプレ修正のみで旧版可。→ 本文に新節＋やってはいけない2件、snippet にキャッシュ実装（理解用）。tok：dao-generated 2272→2909（上限内） |
| **「繰り返し実行時のパラメタ・クリア」を系統横断で整理**（作者依頼・**2026-07-24**。`CmnDao.cs`/`BaseDao.cs`/生成物 `DaoShippers.cs`/`TestMTC.cs` で裏取り） | ループ/明細で同じ Dao を繰り返し実行するときの実行間パラメタ・クリアが系統ごとに違う点を整理。裏取り：**`ClearParameters()` は `CmnDao` 専用**〔`CmnDao.cs` L173。`BaseDao`/`MyBaseDao` に無い〕→ 個別Dao は生コマンドでクリア＝**DBMS 中立形 `this.GetDam().DamIDbCommand.Parameters.Clear()`**〔`DamIDbCommand` は `BaseDam` L179 抽象〕、DBMS 依存形 `((DamSqlSvr)this.GetDam()).DamSqlCommand.Parameters.Clear()`〔Oracle は `DamManagedOdp.DamOracleCommand` L112 等。サンプル `TestMTC.cs` L141 で生コマンド取得を確認〕。自動生成Dao は `ClearParametersFromHt()`〔生成物メソッド・`SetParameteToHt` の Hashtable をクリア〕＋クエリ・キャッシュ。反映：**`opentouryo-layer-d` に系統別クリア比較表**（新節）、**`opentouryo-dao-custom` に個別Dao の生クリア**（`ClearParameters()` 不在＝genuine gap を補充）。dao-common は `ClearParameters()` 既載・dao-generated は `ClearParametersFromHt()` 既載。tok：layer-d 2294→2622・dao-custom 2896→3019（上限内） |
| **公式「共通の初期化処理」ページから2点を反映**（作者提示 URL・**2026-07-24**。`MyBaseDao.cs`/`OAuth2AndOIDCClient.cs`＋各サンプルで裏取り） | 起動時共通初期化2点。**①埋め込みリソース（D層）＝前回 A5 を正確化**：スイッチは `MyBaseDao.UseEmbeddedResource = true;`〔`MyBaseDao.cs` L56 static bool・L71 分岐。true で `SetSqlByFile2` が通常ファイルでなく埋め込みを読む〕＋appSettings `Azure`＝既定名前空間。SQL は EntryAssembly 以外にも埋め込み可・SQL 以外は EntryAssembly。サンプル `GenDaoAndBatUpd_sample/Form1.cs` L50 で使用確認。→ query-definition 本文の A5 記述を「`EmbeddedResourceLoader`/Azure スイッチ」から**実スイッチ `UseEmbeddedResource`** に是正＋snippet 更新。**②`OAuth2AndOIDCClient.HttpClient = new HttpClient()`（起動時）は oauth2-client に既収録だが「Core は」と過小限定→是正**：ゲッターは `set` のみ・`_HttpClient` 既定 `null`・遅延生成なし〔`OAuth2AndOIDCClient.cs` L58/61〕で **Framework/Core とも起動時設定が必須**（net48 `Global.asax` L81/94・Core `Program.cs` L38 の双方で設定を確認）。→ 見出し「Core は」→「起動時（Framework/Core 共通）」、コード注に Global.asax/Startup/Program、やってはいけないを是正。tok：query-definition 4469→4504・oauth2-client →3026（上限内） |
| **新スキル `opentouryo-batch-update`（DataTable RowState バッチ更新）を新設**（作者依頼・**2026-07-24**。ベターユース編 §4.3/§4.8＋実サンプル `GenDaoAndBatUpd_sample` で裏取り） | グリッド系 UI に `DataTable` をバインドした明細一括更新。UI→RowState 対応表：グリッド外[追加]→`NewRow()`+`Rows.Add()`=**Added**／グリッド内[削除]→**`dr.Delete()`**（★`Rows.Remove()` でなく）=**Deleted**／セル編集=**Modified**。B層で `foreach DataRow`→`ClearParametersFromHt()`→`switch(dr.RowState)`→自動生成 Dao（Added=全列→`S1_Insert`／Modified=`PK_`＋WHERE は `DataRowVersion.Original`・`Set_列_forUPD`=現在値→`D3_Update`／Deleted=PK は **Original のみ**→`D4_Delete`）。楽観排他＝`DataRowVersion.Original` を WHERE に（件数0＝タイムスタンプ アンマッチ）。**★ Deleted 行は現在値を読めない**（Original 限定）。成功後 `AcceptChanges()`。Web 複数ポストバックは `DataTable` を Session 保持（メモリ注意）。大量＝`SQLUtility.GetInsertSQLParts/GetUpdateSQLParts`＋`CmnDao` 複数 VALUES／`BaseDao.ExecGenerateSQL`（SQL Server のみ）。**CommandBuilder/DataAdapter 自動更新は非サポート**。実ソース `LayerB_BatUpd.cs` で全パターン裏取り。tok~1758・name一致・desc725字。cross-ref：dao-generated→本スキル、README/§3/最終更新行（35→**36スキル**）。references に RowState switch 全文・グリッド追加/削除・SQLUtility |
| **新スキル `opentouryo-log-analysis`（出力ログの分析＝エラー/性能から対応提案）を新設**（作者依頼・**2026-07-24**。実ログ `C:\root\files\resource\Log` で書式裏取り） | 既存 `opentouryo-logging` は「出す側」で、**出たログを分析して対応を提案する側**が無かった。新設。実ログで書式を裏取り：**ACCESS**＝`[日時],[LEVEL],[thread],,ユーザ名,IP,レイヤ矢印(`----->`/`<-----`),画面名,処理名(`(OnActionExecuting/Executed)`),,実行時間,CPU時間,エラーメッセージID,エラーメッセージ`＋**ERROR 行の直後がスタックトレース**（`型: msg`／`場所 …:行 N`）。**SQLTRACE**＝`実行時間,CPU時間,[commandText]:SQL [commandParameter]:`。OPERATION（業務・自由書式）／SERVICE-IF（WS）。日付ローリング・`_WS` 変種。分析方針＝ERROR/FATAL 抽出→例外型分類（`FrameworkException`=運用事象/`BusinessSystemException`=停止/`other Exception`=未ハンドル。**業務例外は ErrorFlag で返り ACCESS に出ない**）→スタックトレースの `場所…:行` で層確定→責任スキルへ。性能＝実行時間/CPU時間の外れ値・同一SQL多発(N+1)・暗黙型変換・CPU≪実行時間(I/O待ち)・デッドロック/分離レベル。提案は重大度順に「証跡→原因→対処→使うスキル」。references に実行行例・エラーID/例外型→対処表・性能パターン表・grep/awk 集計レシピ。tok~2092・name一致・description 532字。cross-ref：logging→本スキル、README/§3 インベントリ/最終更新行（34→**35スキル**）に反映 |
| **実装スキルの「配布サンプル/テンプレートcode 依存」を全数抽出し、読み替え/取り込み注記を追加**（作者依頼・**2026-07-24**） | 抽出：A=実装スキルでサンプル前提の7箇所（強2＝#1 `sampleScreen.master` 雛形／#2 マスタが `Framework/Js/common.js`・`ie_key_event.js`・`Css/style.css`+`onload/onunload` に依存、中3＝login/menu/logout.aspx・login.aspx.cs・SampleLogConf.xml、弱2＝`ShowNormalScreen("testScreen.aspx")`・oauth2 の `OAuth2AuthorizationCodeGrantClient.aspx.cs`）／B=サンプルクラス名（多くは「PJ依存」明記済み）／C=setup・transform 系（サンプル操作が本務＝正当）／D=フレームワーク提供（常在）。**A 全部を是正**：#1/#2→webforms-screen 本文＋snippet に「**配布物の JS/CSS を自PJへ取り込む（無いとダイアログ/子画面/キー抑止/不正操作防止が動かない）**」「マスタ名はコンテンツ .aspx と別名に読み替える・`sampleScreen` は配布物固有名で残さない」を明記。#3/#4→login/menu/logout.aspx・login.aspx.cs に「サンプル画面名＝自PJに読み替える」。#5→`ShowNormalScreen` 引数は例示 URL の注記。#6→oauth2 コールバック画面名は「サンプル固有名・任意名でよい」。#7→`SampleLogConf.xml` は「配布サンプルの log 設定＝自設定に読み替える/雛形コピー可」を logging 本文/snippet・config 本文に。C の resource-config は setup の本務なので据置。全 SKILL 5000未満維持 |
| **TestPlan2 ケース①（WebForms 実装）の検証レポート5点を反映**（作者提示・**2026-07-24**。`OTRVCAS` 実物・纏め者編 §5.2 で全点裏取り） | 実タスク＝マスタに5ボタン＋初期処理でキャプション/disable・Suppliers 件数(個別Dao)→OKダイアログ・画面A→B遷移・一覧(CmnDao)・CUD＋YES/NO 更新。**①webforms-event の命名例が衝突名で誤導**：本文が `UOC_sampleScreen_...` を使うが `sampleScreen.master` と `sampleScreen.aspx` が**両方実在**（OTRVCAS で確認）＝マスタ名/コンテンツ名を判別不能→エージェントが実バグ（`private` 同様の静かな失敗）。→命名表に「実装先」列＋「接頭辞は `.master` 名・コンテンツ `.aspx` 名でない」★注記＋やってはいけない1行、例を非衝突 `TestScreen` に統一。**②webforms-screen にマスタ新規作成が無い**（`BaseMasterController` 継承・Fx 隠しフィールド12個〔ChildScreenType…RequestTicketGuid、実物で確認〕・ScriptManager が無いとダイアログ/子画面/不正操作防止が動かない）→本文にトリガ節＋snippet に全文。**③④どのスキルも新規 WebForms の csproj 登録/designer 手書きを扱わない**（VS 前提。非SDK csproj は `.aspx/.master`=`<Content>`、`.cs`=`<Compile>+DependentUpon+ASPXCodeBehind`、`.designer.cs`=`<Compile>+DependentUpon`〔実csproj で確認〕。designer は全サーバコントロールを protected 宣言・マスタ上は不要=GetMasterWebControl 経由）→webforms-screen 本文＋snippet に追加。**⑤（軽微）screen-transition** に単純遷移（return URL/FxRedirect/FxTransfer・SCDefinition 不要）vs 論理名遷移（ScreenTransition＝SCDefinition 必須）の対比を追記。tok：wf-event→3191・wf-screen→2401・screen-transition→1629（全て上限内）。※レポート Q2（エージェントが webforms-dialog 以外を読まず crud サンプルから導出したのが誤りの主因）はスキル欠陥でなく利用問題だが、①の非衝突化が再発防止に直結 |
| **SKILL 本文と `references/snippets.md` の重複コードを除去（完了・保守的方針＝作者選択）**（作者依頼・**2026-07-23**） | 方針：**snippet と verbatim 重複するコード fence だけを本文から除き、表・トリガ語・教育的に固有なコード例は残す**（トリガは維持）。実測で「本文トークンの大半は表/トリガ/概念＝残す対象」で、重複コードは一部＝削減は中程度。退避で snippet に無い断片は先に snippet へ足す（例：exception に `FrameworkException` コンストラクタを追記してから本文 fence を除去）。**完了（9）**：project-policy（質問テンプレ全文）／auth（MyUserInfo 骨格・GetUserInformation 例）／exception（コンストラクタ一覧・受け取り例）／richclient-async（実装パターン大 fence・派生クラス例→①〜⑤ prose 化）／transaction-control（TCDefinition.xml・GetTransactionPatterns）／shared-property（SPDefinition.xml）／message（MSGDefinition.xml）／screen-transition（SCDefinition.xml）／transmission（TMInProcess/TMProtocol 定義XML）。**主に XML/config 定義ブロック＋大きな多メソッド例を除き、属性/isolevel 等の表・小アンカー例・安全/警告例は残す。** tok 例：policy 4559→4235・auth 4980→4922・exception 4457→4250。**後半（8編集）**：dao-generated（CRUD使用例）2196→2096／dao-custom（クラス例・SetParameter一覧・ストアド例）2987→2581／layer-b（骨格・引数戻り値定義〔先にsnippetへ退避〕・P層呼出・UOC_ConnectionOpen抜粋）4189→3838／layer-p-mvc（コントローラ全文）3757→3546／p-call-business（中核4ステップコード）2840→2768／webforms-dialog（YesNoコールバック・ModalDialog_End）2337→2220／layer-p-webforms-screen（UOC_FormInit対）／layer-p-webforms-event（命名3例）。**スキップ（8・重複なしと判定）**：layer-d・dao-common（小アンカー＋SQLi安全例のみ）・query-definition（タグ別ミニ例＝教材本体）・layer-p-winforms-screen/event（ログイン例等固有）・logging（書式仕様・矢印表＝固有）・config（表中心）・base2-customize（fence 2つ＝overlay 運用で snippet と別物）。**副産物の是正**：webforms-dialog snippet の `FxEnum.IconType.INFORMATION`（旧doc綴り）→ **`Information`**（本文の実ソース裏取りに合わせた。Exclamation/StopMark も同様）。各 SKILL は 5000 未満維持（全数チェック済）・description（主トリガ）は不変 |
| **公式 UserGuide 8編を全読了し C# 実ソースと照合、スキルへ反映**（作者依頼・**2026-07-23**。`OpenTouryo.wiki/userguide` の Index/Common/Developers/DynParamQuery/D_LayerAutoGen/IndividualFunctions/RichClient/Leaders 計~6,500行） | **結論：スキル群は既にガイドの ~95% を反映**（同じ C# ソース＋docs で多セッション熟成済み）。実ソース裏取りで確認した**真の残差ギャップは2件のみ→反映済み**：①**動的クエリはタグ総数200超で性能負荷**（公式ガイド・コード定数ではない）→`query-definition` に注記（tok 4109→4184）。②**`buttonHistoryRecorder`=off だと `parentFxEventArgs.ButtonID` が常に `"dummy"`**（実ソース `FxLiteral.VALUE_STR_DUMMY_STRING`＝BaseController.cs で確認）で後処理の switch 分岐が効かない→`webforms-dialog` に注記（tok 2193→2283）。**照合で"既にカバー済み"を多数確認**：Developers（GridView 2引数・マスタページUOC命名・UseEmbeddedResource）／Common（FxEventArgs 全プロパティ・ユーザコントロールUOC・例外4型）／DynParamQuery（13+タグ・テキスト/タグ内パラメタ・DBNull/null）／D層自動生成（S/D・DynUpd危険・JOIN非サポート・楽観排他）／IndividualFunctions（dialog `WithAllParent`廃止・window.open・isolevel 8種・CmnTransition・directLink）／RichClient（RcFxEventArgs・非同期呼出デリゲート・6接頭辞）／Leaders（UOC_*・addControlEvent・例外メッセージ定義・TransferErrorScreen）。**新領域＝専用スキル/サンプルが無く要判断（未着手）**：非同期イベント `AsyncEventFx`（名前付きパイプ IPC）／カスタムコントロール `CustCtrl`（TextBox/MaskedTextBox 検証・`CmnCheckFunction.HasErrors`）／Ajax連携（Client Callback・AJAX Extensions）／画面コード親クラス**３**（サブシステム共通イベント層）。※ base2-customize は tok~4954 で満杯につき niche 追加は見送り |
| **repo 直下 `AGENTS.md`（＝この repo の開発ポリシー原本）を新設・拡充**（作者が新規追加→本セッション履歴/§4.3 から集約・**2026-07-21**） | 作者が repo 直下に `AGENTS.md`（Git 操作禁止のみ）を追加。**配布物 `src/instructions/AGENTS.md` とは別物＝スキル authoring 用**。本セッションで確立した開発ポリシーを集約追記：①2つの AGENTS.md を混同しない（authoring vs 配布物）②主張は実ソースで裏取り（`C:\otr\...\CS`／`OpenTouryoDocuments\documents`／as-built は `git diff` 閲覧・in-repo `files/` は削除済み）③トークン規律（SKILL は ~5000・auth 4952 基準・`measure.py` 見積り・`references/samples/examples.md` は予算外へ退避）④DevelopmentHistory §4.3/§3 に記録・相対日付→絶対⑤prescriptive（利用側に判断させない・variant は csproj 判断・選択肢は間引かない）⑥**横断ルールは実害大なら集約せず重複（defense-in-depth。AGENTS.md 上書き/欠落対策。現該当＝「選択肢は間引かない」）**⑦検証レポート反映手順（裏取り→既出区別→反映先配分→記録）⑧標準準拠（name=ディレクトリ名・description ≤1024・HTML コメントは除去され執筆者メモ可・破壊的変更は確認）。※本ファイルは authoring 用で SKILL 予算対象外 |
| `opentouryo-project-policy` 2回目の検証実行レポート＋**②確認地図の 2CS 抜け**を修正（作者指摘＋エージェント検証・**2026-07-21**。`C:\otr` 実ソースで裏取り） | 作者依頼「④ DBMS 選択方式・接続文字列のキー」で②が `Business/MyFcBaseLogic.cs` のみ指し **`RichClient/Business/MyFcBaseLogic2CS.cs`（2層C/S 版）を落とした**。実ソース確認：**2CS 版は同名 UOC を全部持つ**（`UOC_ConnectionOpen` の DBMS 分岐・接続文字列が同一、`UOC_PreAction/AfterAction`、`UOC_ABEND`×3、`IsolationLevelEnum.User`）＝ 2CS 構成では別ファイルを読むべき。既存の L122「B層も同様」注記が弱く行どおり読んで取りこぼす。類似抜けの調査：P層行は「処理方式ごとにファイルが違う」＋P層表で担保、D層 `MyBaseDao` は 2CS 双子なし、`addControlEvent` 行は既に両方記載＝**系統的な抜けは MyFcBaseLogic を指す4行のみ**。→ ★注記を「`User`振替・DBMS選択・例外振替・ACCESS ログの4行は 2CS なら `…2CS.cs` を読む（分離/トランザクション/ロールバック挙動が違う）・片方だけで結論しない」に強化。エージェント5点も反映：①**build-ref.txt が既存構築物に無い**（本 repo 実測＝マニフェスト無し・SETUP-CHANGES に ref 無し）→ step1 に「展開ツリー `C:\otr\OpenTouryo-<ref>` のフォルダ名から `<ref>` を読む／無ければ聞く」を追加。②**base2-overlay/ 自体が無い**（overlay 機構未使用＝DLL 参照のみ）構成の扱い未定義→「同様に未改変＝stock 既定値を仕様とみなす」を追記。③保存先「プロジェクト方針ノート」の実体未定義→ **repo 直下 `PROJECT-POLICY.md`（コミット・全エージェント可視。Claude 固有メモリはリポ外で不可）**に具体化。④DBMS 行に「対応 Dam は `#if` でランタイム別（OLE/ODB/ODP=net48・NPS=core）」。⑤表記ゆれ `actionType`→実コード `parameterValue.ActionType`（PascalCase）に是正。tok：policy 4208→4515（上限内） |
| `opentouryo-project-setup-db` の実走レポート8点を反映（実機検証・**2026-07-21**。参照リポ `DNDIWGOSSC/LocalServicesOnDocker` 実装に全点当て・全件再現） | スクリプト本体（`Start-Services.ps1`/`_wsl2.ps1`/`start-up.sh`）は堅牢で、問題は**スキル文書 ↔ compose の非永続設計の不整合**が主眼。高：①**4 DB は永続ボリューム未使用**（`docker-compose.yml` で mysql/postgres/sqlserver/mongo の data マウントをコメントアウト・redis のみ `./redis/data`）＝**`-v` の有無に関わらず `down`→`up` で毎回リセット**。旧記述「`-v` でボリューム削除＝データ全消し」は「無印なら残る」誤含意→是正（スクリプト自身も `Start-Services.ps1` L9・README L175 で「永続無しゆえ作り直し無害」と明言）。②**Northwind 基本表は `start-up.sh` が毎起動で自動再作成**だが `instnwnd.sql` に **ORDERS2 無し**（grep 0）＝サンプル固有表は**都度再投入**（非対称を明記）。中：③`Start-Services.ps1` の実IF（`up`/`down`/`ps`/`logs`＋`-NoWait`/`-NoPause`・DB 準備待ち・自動作り直し・localhost 到達確認）を過小紹介→追記。④**clone 先＝プロジェクト repo 外**を明記。⑤起動前ポート プリフライト（`Test-NetConnection localhost -Port 1433`）追加。低：⑥初回 pull 目安（SQL Server 2022 約1.5GB 含む5 イメージ・数分）。⑦WSL2 手動 `docker network create` は既存だと2回目エラー→`inspect ||` 冪等形／`*_wsl2.ps1` へ寄せる（`.ps1` は L198-206/L288-289 で冪等）。⑧redis のみ残る点を①と対で明記。新設「★ データは毎回リセット」節＋起動節を書替。tok 1472→2203 |

| ①サンプル表が全系列を網羅していなかった（作者指摘・**2026-07-18**。`files/csharp/` で全列挙） | 取り出せるのは **WebApp_sample / 2CS_sample / Bat_sample / CLI_sample / WS_sample(WSClient_sample)** の系列だが、表は一部（WebApp の MVC/WebForms＋2CS/Bat/CLI/WSClient の各1つ）しか出さず決め打ちさせていた。実ミラーで確認した漏れ：**CLI は net48 にも存在**（`Samples\CLI_sample\{Simple_CLI,DAG_Login_CLI,LIR_Login_CLI}`。表は core だけだった）／**2CS に WPF・機能デモ多数**（`2CSClientWPF_sample`・`AsyncEvent_sample`〔net48 のみ〕・`CustCtrl_sample`・`GenDaoAndBatUpd_sample`・`TimeStamp_sample`）／**Bat は複数**（`SimpleBatch_sample`・`RerunnableBatch_sample`〜3）／**WSClient は4種**（`WSClientWin_sample`/`WPF`/`Win2`/`WinCone`）／**core に `Backend\ASPNETWebService`**（Web サービス バックエンド）。→ ①表を全系列網羅に再構成（接頭辞規約 net48＝`Samples\`・core＝`Backend\`/`Legacy\` を明記、ランタイムは `net48 / .NET 10.0` 併記、WPF 行と ASPNETWebService 行を追加、派生の存在を注記）＋「**候補を提示してユーザに選ばせる（一部だけ出して決め打ちしない）**」を明記 |

| ①表の「未確認」を実ミラーで確定＋残件の2分類（作者質問・**2026-07-18**） | 「未確認」＝`samples/` にファイルが無い残件か？との問い。整理：**「未確認」は WS/3層依存の検証軸で、`samples/` の有無とは別軸**。`files/csharp/` の csproj を調べて確定：**net48 MVC は WS 依存**（`Crud1Controller` が `TestParameterValue`/`TestReturnValue` を使用・csproj が `WSIFType_sample`/`WSServer_sample` 参照。**core MVC はなし**）／**2CS(Win/WPF)・Bat＝なし**（WS 参照無し確認）。→ 表の WS 列を確定値へ、凡例（なし/あり/未確認†）を追加。**CLI_sample 各種・`Backend\ASPNETWebService`・`Frontend` はミラーが README のみのスタブ**で実ソース未収録＝WS 依存を確定できず「未確認 †」。残件は2種と明記：①`samples/<name>.md` 未整備（ドキュメント。現状 webforms.md のみ）②`未確認 †`（検証。ミラー未収録で実物 csproj 要確認）。※ ミラー自体が部分的（一部サンプルは README スタブ）と判明 |

| `ASPNETWebService`・`Frontend` は別リポジトリと判明→①表から除外、CLI は依存なし確定（作者フィードバック＋手修正・**2026-07-18**） | 前項で「ミラーが README のみのスタブ」と括っていた `Backend\ASPNETWebService`（Web サービス／リソースサーバ）と `Frontend`（SPA フロント）は、**ミラーの取り込み漏れではなく OpenTouryo 本体とは別のリポジトリ**だった：`ASPNETWebService`＝<https://github.com/OpenTouryoProject/ResourceServerTemplates>、`Frontend`＝<https://github.com/OpenTouryoProject/FrontendTemplates>。→ **作者の最終判断**：別リポジトリはそもそも「OpenTouryo から取り出すサンプル」ではないので **①表から完全に除外**（このスキルの ZIP フロー対象外。立ち上げは各 repo 側手順）。あわせて **`CLI_sample` は WS 依存なしを確定**（`なし`）。結果、**表に未検証行が無くなり `未確認 †` 区分は廃止**、凡例は `なし`／`あり` の2つ、「残件」は `samples/<name>.md` 未整備の1種類だけに単純化。メモリ `reference-csharp-source-mirror` にも「ミラーの穴＝別リポジトリ（URL）」を記録 |

| (A)/(B) の呼称を層数ベース→WS 依存の有無ベースへ（作者フィードバック・**2026-07-18**） | 「(A) 3層のまま通す／(B) 2層で使う（2層化）」という**層数（2層/3層）ベースの呼称が混乱を招く**：core 版は通信制御（Transmission）を使っても `BinaryFormatter` 廃止で**インプロセスのみ＝実質2層**になり得るため、「WS を残す＝3層」が常に成り立たない。→ 判断軸を**WS 依存の有無**に統一し、**(A) そのまま残す／(B) WS 依存を切り離す**へ改称。反映先：`project-setup` SKILL.md（①凡例まわり・「3層サンプルの扱い」・完了後の transform 案内）、`samples/webservices.md`（(A)/(B) 見出し）、`samples/webforms.md`、`project-transform` SKILL.md（節見出し「WS 依存を切り離す」・本文の「2層化」表現・description。ただし `2層化`/`3層を削る` は検索語として description に温存、`3Tier` フォルダ名や `3層画面`・`2層画面` の実体名はそのまま） |

| 短ルート ビルド時の「基盤ソース引き込み」が抜けた→念押し格上げ（作者フィードバック・**2026-07-18**） | 深いリポ回避で短い作業ルート（`C:\ot\`）でビルドした際、**親クラス2 カスタマイズ用の基盤ソース `root\programs\CS\Frameworks`（`Infrastructure`）をワークスペースへ引き込む手順をエージェントが実行しなかった**（使い捨てツリーにしか残らず base2 カスタマイズ不可）。原因：`setup-build` §1 で「例外」として柔らかく書いていただけで見落とされた。→ **`setup-build/SKILL.md` §1** に見出し付きの必須手順「★ 基盤ソースの引き込みを必ず行う」へ格上げ（`xcopy` 例＋**`<workspace>\...\Frameworks\Infrastructure\Business` の実在確認**、無ければ止めてやり直し）、**やってはいけないこと**にも「引き込まない」を追加。**`base2-customize/SKILL.md`** の該当バレットも「★ 最初に引き込む（省略しない）」の imperative へ強化（同じ `xcopy`＋実在確認）。両スキルを相互参照。サイズ：setup-build tok~3603・base2 tok~3185（目安内） |

| ④ 取り出しに開発支援ツール（`Frameworks\Tools`）を追加＋ツール別ドキュメント新設（作者フィードバック・**2026-07-18**） | セットアップの ④取り出しは**サンプルだけ**を対象にしていたが、OpenTouryo は `Frameworks\Tools\` 配下（`Samples\` ではない）に GUI 開発支援ツールを同梱する。→ **④に「開発支援ツールも取り出す」を追加**：`DaoGen_Tool`（＝墨壺。D層自動生成＝`opentouryo-dao-generated`/`layer-d`）と `DPQuery_Tool`（動的クエリ試験＝`opentouryo-query-definition` の `PARAM` タグ）。両ツールもサンプルと同じ `Reference`+`HintPath` 方式で ⑤ と同じ張替。**実ミラーで確認した net48 の要注意点：`packages.config` が無く、3rd-party（`MySql.Data`/`Oracle.ManagedDataAccess`）含め全 HintPath が `..\..\Infrastructure\Build\` を指す＝全部ベンダ先へ張替**（core は `PackageReference`＋`Build_netcore100\net10.0\`）。WinExe/WinForms、net48（`*.csproj`）＋core（`*Core.csproj`＝`net10.0-windows7.0`）。→ **`samples/daogentool.md`・`samples/dpquerytool.md` を新設**（置き場所・ランタイム・張替手順・関連スキル・使い方の要点）。①「残件」の現存ファイル列挙も更新 |

| 「残件」は本文でなく執筆者メモ（`<!-- -->`）にする（作者指摘・**2026-07-18**） | `project-setup` ① の「残件」（`samples/<name>.md` の整備状況＝ドキュメント TODO）が**可視の本文**に書かれていた。これはエージェントへの実行指示ではなく**執筆者向けのメタ情報**なので、`base2-customize`/`oauth2-client`/`project-transform` と同じく **`<!-- 執筆者メモ（Claude Code は読み込み時に除去）… -->`** へ移した。実行に効く一文（「専用 `.md` が無いサンプルも表＋`samples/webservices.md` で取り出せる」）だけ本文に残置。コメントは measure の実効（eff）・読み込みから除外＝予算に効かない（tok~4971→4882）。**方針**：スキル本文はエージェントが従う指示だけ、整備状況・将来 TODO・執筆意図は `<!-- -->` に置く（既存の慣行を横展開） |

| ①サンプル選択が間引かれ 3層CS/WSClient_sample が選べなかった→全系列提示を明記（実環境レポート・**2026-07-18**） | ① の選択で、エージェントの提示が**4バケット（MVC / Web Forms / WinForms 2CS / CLI・バッチ）＋「Type something」に間引かれ、3層リッチクライアント（`WS_sample\WSClient_sample`）と WPF が選択肢から欠落**した。原因は**提示層のバケット化**（実質4択の chooser に押し込めるため系列を落とす）。表は全8系列を列挙済みで、既存注記「一部だけ出して決め打ちしない」だけでは防げなかった。→ **① 表直後を強い明示指示に差し替え**：「上表の全系列を必ず提示してユーザに選ばせる／系列をまとめて間引かない（実測で 3層CS・WPF が欠落）／**選択 UI が選択肢数を制限しても、収まらなければ全系列を番号付きリストで提示して番号で選ばせる**／派生は系列を選んだ後の枝でよいが系列そのものは全部見せる」。**やってはいけないこと**にも「サンプル選択で系列を間引く（固定4択に押し込めて WSClient_sample/WPF を落とす）」を追加。追記で cl100k が 5000 を超えたため、凡例の MVC 重複・`なし`行の重複・派生の列挙を刈って **tok~4997（目安内）** に収めた |

| コピーバックが繰り返し抜ける→「短ルートをワークスペースに追加」方式へ転換（作者フィードバック・**2026-07-18**） | 前々項で「基盤ソースの引き込み（`xcopy` で深いリポへコピーバック）」を必須手順へ格上げしたが、**あいかわらずエージェントが実行しなかった**（2回目の実測）。作者提案：**もう `C:\otr` をワークスペースに追加すればよい**。→ 設計転換：コピーという抜けやすいステップ自体を**廃止**。基盤ソース `Frameworks\Infrastructure` は ZIP 展開時点で `C:\otr\OpenTouryo-<ref>\root\programs\CS\Frameworks\Infrastructure` に**既に在る**ので、深いリポへコピーせず、**短ルート `C:\otr` をワークスペースに追加して展開ツリーを直接編集・ビルド**する（VS Code「フォルダーをワークスペースに追加」／エージェントは絶対パスで直接読み書き）。「ソースが無くて始められない」も「コピー忘れ」も原理的に起きない（＝実行必須のアクションが無い）。コミットは差分 `base2-overlay/` だけ、展開ツリーは使い捨て。長パス有効化でリポ直下ビルドし分離自体を無くす選択肢も併記。反映：`setup-build/SKILL.md` §1 の ★ 節＋やってはいけないこと、`base2-customize/SKILL.md` の該当バレット（`xcopy` コピーバック例は削除）。サイズ：setup-build tok~3570・base2 tok~3133（目安内） |

| 検証レポート `skill-feedback-report.md` 反映（WebForms/net48/03-20 実機・**2026-07-18**。**ビルド→IIS Express 実行〔login 200〕まで完走**） | **A-1（最重要・記述訂正）**：`DaoGen_Tool`/`DPQuery_Tool` が素でビルド不可（`CS0234` Microsoft.Data.SqlClient）。ミラー確認で真因判明＝**net48 ツール csproj は `HintPath` と `PackageReference` の混在**（`packages.config` は無いが `Microsoft.Data.SqlClient`・`Azure.*` 等を `PackageReference` で持つ）。私の旧記述「net48 は packages.config 無し＝全 HintPath＝復元なし」は**誤り**→ `daogentool.md`/`dpquerytool.md`/`reference-rewrite.md`/① inline を訂正：**HintPath はベンダ張替＋`PackageReference` は restore（`msbuild -t:restore`/`nuget`/`dotnet`）**。`Microsoft.Data.SqlClient` は SNI ネイティブ要＝restore が正道（ベンダ DLL への HintPath 追加は compile 通るがネイティブ落として起動失敗しやすい）。**B-1**：⑦「実行できることを確認」の how-to を `references/run-verify.md` 新設（IIS Express を HTTP ポートで起動して SSL 回避／`OT_RESOURCE_ROOT` を起動コマンドで明示／`Ping.aspx`=302・`login.aspx`=200 スモーク／500＝resource・config 解決失敗）＋⑦に短ポインタ。**D-1**：⑦完了後に**コミット促し**を追加（未コミットで作業ツリーから消失した実測。git 操作は人の原則は維持）。**C（回帰確認・変更不要）**：タグ確認フロー／サンプル全系列提示（4択制限を番号付きリストで回避し WSClient/WPF を落とさず）／短ルート MAX_PATH 回避／exit code 不信→DLL 実在判定／VS18 Community 限定検出／sessionState InProc／resource 綴りの罠／HintPath 末尾フォルダ名＋MySql/Oracle 張替／構成A は④⑤で完結——すべて記述どおり通用。**D-2（任意・未対応）**：`build-app.ps1` 雛形にツール2本のビルドを足せば A-1 をセットアップ時に炙り出せる（examples.md への追記余地。今回は見送り）。追記で ① が cl100k 5000 を超えたため ⑤ XML を net48 例のみ化・重複刈りで **tok~4995** に収めた |

| 検証レポート `skill-feedback-report-base2.md` 反映（SQL Server 固定・net48・03-20・IL 逆アセンブルで反映実証・**2026-07-18**） | **A-1（最重要・記述訂正）**：`3_Build_Business_net48` は **2CS＝`OpenTouryo.Business.RichClient` をビルドしない**。ミラーで裏取り：2CS クラス（`MyBaseLogic2CS`/`MyFcBaseLogic2CS`）は `Business/RichClient/Business.RichClient_net48.csproj`（別アセンブリ）にあり、`Nuget_RichClient_net48.sln` は `Framework.RichClient` **のみ**ビルド（＝`Business.RichClient` は別 sln `BusinessRichClient_net48.sln` が要る）。旧記述「成果は `Business(.RichClient).dll`」は**net48 で不成立＝2CS の改修が無言で無視される**。→ `base2-customize`（親クラス2 とは／層別マップ★／変更→反映ループに 2CS 用の別 sln ビルド追加）と `setup-build`（RichClient 注記に「出来るのは Framework.RichClient まで」）を訂正。core も同構成で同穴の可能性（要確認）と注記。**B-1**：overlay 適用の非対話・エンコーディング注意＝`xcopy` は F/D を訊くので **`Copy-Item -Recurse -Force`**（or `xcopy /Y /E /I`）、基盤ソースは **UTF-8 BOM 付き**でツール生成時に BOM/エンコード維持。**B-2**：overlay は**ファイル単位の丸ごと差替（パッチ＝行差分ではない）**を明記。**D**：`UOC_ConnectionOpen` を 1 DBMS 固定に簡素化すると `actionType` の DB 切替が無効化される副作用を row に注記。**C（回帰確認・変更不要）**：差し込み点表の正確さ／overlay+固定タグ再現／ビルド順／override シグネチャ不変で依存アプリ無変更、すべて記述どおり。サイズ：base2 tok~3735・setup-build tok~3659（目安内） |

| `examples.md` の as-built 雛形メンテ（2レポートの D-2／base2 A-1 反映・**2026-07-18**） | 2つの検証レポートで判明した点を雛形に織り込み（前回「見送り」とした D-2 を実施）。**build-app.ps1**：任意ステップ3を追加＝取り出した開発支援ツール `DaoGen_Tool`/`DPQuery_Tool` を `msbuild /t:restore,build` でビルド（`PackageReference` restore で `Microsoft.Data.SqlClient` の欠落＝`CS0234` をセットアップ時に炙り出す。HintPath 張替済み前提）。**setup-build.ps1**：base2 用の任意ブロック2つ＝(1b) `base2-overlay` があれば `Copy-Item -Recurse -Force`〔F/D プロンプト回避・UTF-8 BOM 保持〕で展開ツリーへ適用、(2b) `3_Build_Business` が作らない 2CS＝`BusinessRichClient_net48.sln` を vswhere 解決の msbuild でビルド→ Build_net48 経由でベンダ、post-vendor で `OpenTouryo.Business.RichClient.dll` の実在確認。末尾に run-verify.md への実行確認ポインタ。**as-built 雛形＝環境に応じ調整（Configuration/restore 方式）**と明記。162行（on-demand なので本体予算に無影響） |

| **sessionState は InProc に変えず StateServer を維持（前言撤回・作者指示・2026-07-18）** | 以前 SKILL-FEEDBACK/⑦ で「State Service が要るなら `InProc` に変える」と誘導していた（上記 317/323/345 行）が、**作者判断で撤回**：**`StateServer` のまま残すのが正**。理由＝StateServer は**セッションをシリアライズ可能に保つ**ので、後で out-of-proc 化・スケールアウトへ移す変更が効く（`InProc` にすると失う）。net48 は **ASP.NET State Service を起動**して使う（`root\files\bat\aspnet_state-stat.bat` で起動／`aspnet_state-stop.bat` で停止。ミラー `files/else/bat/` で確認）。**core は StateServer 非対応**なので必要なら Redis 等の分散セッション。設定値は `<sessionState timeout="20" cookieless="false" mode="StateServer" stateConnectionString="tcpip=127.0.0.1:42424" />`。→ ⑦ の当該バレットを「StateServer を残す・State Service を起動」に書き換え（旧「InProc に変える」は削除）。追記で ① が cl100k 5000 を超えたため ⑥/⑦ の重複を刈って tok~4997 に収めた |

| `project-setup` を手順の順序で分割＝ファサード化（作者指示・**2026-07-18**） | ① が field feedback の積み増しで毎回 cl100k 5000 に張り付く過積載になっていた。作者指示で**手順順に分割**：`opentouryo-project-setup` を**ファサード**（全体の流れ＝4スキルの呼び出し順・完了後・全工程共通の禁止事項のみ、tok~1490）にし、**①②→`-selection`**（tok~1785）／**③→`-build`**（既存）／**④⑤→`-core`**（tok~1308。references/reference-rewrite.md・samples/* を保持）／**⑥⑦→`-config`**（tok~1637。references/resource-config.md・run-verify.md を保持）へ委譲。⑥⑦ の置き場は作者選択で独立スキル `-config`。サブファイルは `mv` で該当スキル配下へ移設。**クロス参照を全更新**：transform〔⑤/reference-rewrite→core〕・transmission〔①表→selection〕・base2〔DLL ビルド/ベンダ→build、②固定タグ→selection、description も〕・examples.md〔run-verify→config〕・moved 各 md の自スキル名・AGENTS.md 表・README 一覧。名前=ディレクトリ名／description≤1024 を全新スキルで確認、`install.ps1 -TargetRoot <tmp>` で3新スキルが references/samples ごと同梱されることを実測。全30→33スキル。各スキルが目安に**大きく余裕**（過積載解消） |

| 2件の不具合修正：ログ定義内の出力先が未張替／インストール AGENTS.md 文字化け（作者報告・**2026-07-18**） | **(1) ⑥ の穴**：`resource\Log\*.xml`（`SampleLogConf.xml` 等）の appender `<param name="File" value="C:\root\files\resource\Log\ACCESS">` が未張替でログが旧パスへ出続けた。ミラーで機序確認：`LogManager_log4net` は**ログ定義ファイルのパスだけ**を `%VAR%` 展開（生ストリームで開き `XmlConfigurator` に渡す＝中身は非展開）、log4net も素の `<param name="File">` を非展開。→ `resource-config.md` に「★ ログ定義の中の出力先も張り替える」節＋config SKILL.md ⑥ に手順3追加：**log4net の `<file type="log4net.Util.PatternString" value="%env{OT_RESOURCE_ROOT}\Log\...">`** で環境変数展開させる（`%OT_RESOURCE_ROOT%` 直書きは不可）。**(2) インストーラの文字化け**：`install.ps1` が `Get-Content -Raw`（`-Encoding` 無し）で AGENTS.md を読む→Windows PowerShell 5.1 の既定 ANSI が UTF-8 を誤読→文字化けを UTF-8 で書き戻していた。→ 読み取りを **`[System.IO.File]::ReadAllText()`**（BOM 検出＋UTF-8 既定）に変更（161・108行）。`install.ps1 -TargetRoot <tmp>` で **source バイトが installed AGENTS.md に verbatim 含有・UTF-8「このファイルは」存在**を実測確認 |

| selection フロー検証で判明した3件（作者報告・**2026-07-18**。いずれもスキル doc 側、本体は既知どおり） | **A（doc バグ）**：`run-verify.md` の IIS Express `/path` が Web ルートと1階層ずれ。ミラー確認：WebForms は `.sln` が外側 `WebForms_Sample\`、`Web.config` は内側 `WebForms_Sample\WebForms_Sample\`。→ `/path` を内側に修正＋「`/path`＝`Web.config` のある階層、sln パスとは別階層」を明記。**B（構成の穴）**：ファサードが新規前提で、既存 repo への**追加・再実行（冪等性）**の手当て無し。→ ファサードに「既存への追加・再実行」節（既存成果を上書きしない・同一ランタイムなら ③ 流用・⑥⑦ 再張替不要）、selection ② に「2本目が同ランタイムなら ③ スキップ可」。**C（reference-rewrite が WebForms 前提のみ）**：`MySql.Data`/`Oracle` の元 HintPath がサンプルで割れる（ミラー確認：MVC net48＝`..\..\..\..\Frameworks\Infrastructure\Build\`／WebForms＝`..\..\..\WS_sample\Build\`、しかも WebForms でも `DamMySQL` だけ Frameworks 側）。→ reference-rewrite.md に「元 HintPath はサンプルで割れる・一律接頭辞置換せず各 HintPath の実際の元を見る」を追記。**本体側の新規報告は無し**（MAX_PATH/MSB3553・VS18 msbuild 検出・DB 未起動の /Ping タイムアウトは既記載の既知事項） |

| README のスキル一覧を用途・利用者順に3グループ化（作者要望・**2026-07-19**） | 層順のフラット一覧を**ライフサイクル／利用者**で再編：**①立ち上げ・構成**（初期設定＝立ち上げ担当/纏め者。project-setup 一式＋transform＋policy＋base2-customize の8）／**②各層のコード実装**（日常常用＝アプリ開発者。P/B/D＋Dao＋query-definition の14）／**③制御・定義／横断機能**（機能利用＝必要時参照。定義ファイル群＋exception/logging/config/auth/oauth2/common-parts の11）。全33件を欠落なく分類（`grep` で件数一致を確認）。README のみ変更（AGENTS.md のスキル選択表は据え置き） |

| 再実行（.NET 10.0 / Core MVC 追加）で判明した core・混在ランタイム系5件（作者報告・**2026-07-19**。B〔冪等性〕は前回更新で解消済み） | **D**：`examples.md` に netcore100 の例が無く net48 専用だった → **`setup-build-netcore.ps1` 雛形を追加**（既存 ZIP 展開を再 DL せず流用・netcore バッチのみ・`Build_netcore100\` の TFM 両サブフォルダをベンダ）。混在ランタイム repo〔net48 済みで .NET10.0 だけ後追加〕に対応。**E**：`run-verify.md` が net48/IIS Express 専用 → **core＝Kestrel（`dotnet run`）節を追加**。`dotnet run` は **launchSettings.json の applicationUrl を優先**し `ASPNETCORE_URLS` を無視する〔実測：5080 指定でも 5219 起動〕→ `--urls`/`--launch-profile` で固定 or launchSettings のポートを使う。**F**：ファサード冪等性節に「**同系列を別ランタイムで足すとフラット化フォルダ名が衝突**〔net48 MVC が `MVC_Sample\` 占有・Core MVC も同名〕→ 別名 `MVC_Sample_Core\`」を追加。**minor**：`reference-rewrite.md` に「`Build_netcore100\` は **TFM サブフォルダ2種**〔`net10.0\`＝Web/MVC/Bat/CLI、`net10.0-windows7.0\`＝WinForms/WPF・2CS〕」を明記（ミラーの csproj TargetFramework で確認）。**G〔本体側〕**：Core MVC が **log4net 3.2.0** を参照し `NU1902`〔GHSA-4f7c-pmjv-c25w・中〕が出る（ビルドは通る）→ 本体のバージョン更新検討事項。スキルは examples.md に「既知警告・セットアップ側で差し替えない」と注記（net48 系では出ない core 固有） |

| 再実行（2CS/WinForms・net48・既存流用）で判明した3件（作者報告・**2026-07-19**） | **H（最重要）**：「同一ランタイムなら ③ 流用でスキップ可」が **2CS/リッチクライアント系で破綻**。ミラー確認：`2CSClientWin/WPF`・`GenDaoAndBatUpd`・`WSClient_*` 全種が `OpenTouryo.Business.RichClient` を参照するが `2_/3_Build_net48` は生成しない（別 sln `BusinessRichClient_net48.sln` 必須）＝**base2 カスタマイズと無関係の素の依存**。従来 examples.md の 2b ブロックが `if (Test-Path $overlay)`〔base2 がある時だけ〕でガードされ、setup-build も「親クラス2 の 2CS カスタマイズ時に効く」位置づけだったのが誤解の元。→ **(a) ファサード冪等性節に「2CS/RichClient は同ランタイム・同タグでも ③ に追加ビルド要」の例外**、**(b) setup-build を「RichClient 系サンプルなら必須・base2 と無関係」に格上げ**（★節に）、**(c) examples.md 2b を `$needRichClient -or overlay` に変え overlay 非依存化**（`setup-build-richclient.ps1` 相当）。**I**：selection の系列表に「**RichClient 基盤の追加ビルドが要る**（WinForms 2CS・WPF 2CS・3層リッチクライアント。WS/3層依存とは別軸）」の注記を追加。**J**：run-verify.md に**デスクトップ（WinForms/2CS）検証**節＝exe 起動→プロセス生存（起動時クラッシュ無し）、DB 依存操作は SQL Server 前提、3層は WS サーバ起動も要。**※当初「本体が Business.RichClient を出さないパッケージング設計」と書いたが誤り＝下行で訂正** |
| 【訂正】H〔基盤ビルドが `Business.RichClient` を出さない件〕は本体の欠陥ではない＝スキルのサブセット選択が原因（作者指摘・**2026-07-19**） | 前行で「標準基盤ビルドが `Business.RichClient` を出さない」を本体側要因としたのは**誤り**。作者指摘：**`root\programs\CS` の各 bat を順次回せば（まとめ役 `root\programs\9_CICD.bat` でも）Business.RichClient も含め全部ビルドされる**。本スキルは**標的を絞って速くするため `2_/3_Build_*` サブセットだけを回す方針**なので、そのサブセットに `BusinessRichClient_*.sln` が入っていないだけ（＝本体の欠陥ではない。`9_CICD.bat` を使わない設計自体は妥当）。→ 4スキルの「標準フロー」表現を「③ が回す `2_/3_Build_*` サブセット（フル一式／`9_CICD.bat` なら出る）」へ訂正（setup-build ★節・facade 例外・selection 注記・base2）。開発元への報告事項は無し（挙動は仕様どおり） |

| 再実行（WPF 2CS・net48・既存流用）＝新規欠陥ゼロ（作者報告・**2026-07-19**） | WPF 2CS は WinForms 2CS とほぼ同一で一発通過（フラット化・参照張替・`SqlTextFilePath` 1点張替・`/t:restore`・起動スモーク）。**新規 Issue は無し**。**J（デスクトップ実行検証）は前ターンで対処済み**（`run-verify.md` のデスクトップ節）を再確認＝WPF も同節でカバー。見出しに `WPF` を明示追記。**C（MySql/Oracle の元 HintPath がサンプルで割れる）も対処済み**（reference-rewrite.md）。任意改善として selection に「**WPF 2CS ≒ WinForms 2CS 同一手順**（desktop・RichClient 要・`SqlTextFilePath` 1点）」の一言を追加。※報告者の `Select-String -SimpleMatch 'C:\root'` 取りこぼしはエージェント側の検査コマンド不備（`C:\\root` エスケープ or `.Contains` を使う）で、スキル／本体の欠陥ではない＝doc 変更なし |

| Issue `skill-issue_netcore-richclient-windows-tfm.md`：netcore の RichClient 欠落は Business/Dam* ごと（作者報告・**2026-07-19**。net10.0 WinForms 2CS で実測） | H〔RichClient は別 sln で追加ビルド要〕の netcore 版の精度不足。前回「2CS/RichClient は `Business.RichClient` が別ビルド（core は `_netcore100`）」と書いたが、**netcore は欠落範囲が広い**：標準 `2_/3_Build_netcore100` 直後の `Build_netcore100\net10.0-windows7.0\` に **`OpenTouryo.Business` と `Dam*`（DamManagedOdp/DamMySQL/DamPstGrS）まで無い**（`net10.0\` 側にはある）。`3_Build_BusinessRichClient_netcore100.bat` でこれらと `Business.RichClient` が揃う。core 2CS csproj は `OpenTouryo.Business` も `net10.0-windows7.0\` から参照するので、`Business.RichClient.dll` だけ拾うと `OpenTouryo.Business` で `CS0246`。→ **対処＝`net10.0-windows7.0\` フォルダを丸ごと再ベンダ**。net48 は TFM 分岐が無く欠けるのは `Business.RichClient` のみ（＝本体の欠陥ではない・記述の過小表現の修正）。反映：build SKILL ★節に netcore 段落／facade 例外／selection 注記／`reference-rewrite.md` の netcore TFM 節に「⚠ net10.0-windows7.0 は標準直後だと不完全＝丸ごと再ベンダ」／`examples.md` setup-build-netcore.ps1 に `$needRichClient` ガードの `3_Build_BusinessRichClient_netcore100.bat` ステップ＋Windows TFM 側 Business.dll の実在チェック。**J 追補〔デスクトップ実行検証〕**：run-verify デスクトップ節に GUI 合否基準（数秒生存＝startup OK・DB 依存は SQL Server 前提）を追記。開発元への本体 Issue は無し |
| 同 Issue ファイルに J の追記 Issue が追加（合否基準の正式化・作者報告・**2026-07-19**。net48/.NET10 の WinForms/WPF 2CS 4例で実測） | GUI サンプルは HTTP エンドポイントが無く「起動する」以上の合否基準が未定義だった。→ run-verify デスクトップ節を**正式基準に強化**：**合格**＝exe を `OT_RESOURCE_ROOT` を渡して起動し **5–7s 生存＋初期画面**＝startup OK／**NG**＝起動直後の異常終了・未処理例外（resource/config 疑い）／**対象外**＝ログイン以降の DB 依存操作（`SqlTextFilePath` の SQL・SQL Server(Northwind)。DB 未起動での失敗はセットアップ不備でない＝Web の /Ping と同扱い）。**非対話チェックの雛形**（`Start-Process -PassThru`→`Start-Sleep 6`→`HasExited` 判定→`Kill()`）と **exe の具体パス**（net48＝`bin\Debug\<app>.exe`、core＝`bin\Debug\net10.0-windows7.0\<app>.exe`）を追加。本体 Issue 無し |

| グローバル変更の記録規約を新設（作者提案・**2026-07-19**） | 「repo 外＝マシン/ユーザ全体に残る変更を伴うスキルは変更ログを残すべき」との提案。横断監査で対象を特定：**config**（`OT_RESOURCE_ROOT` User 環境変数・ASP.NET State Service 起動）／**build**（短ルート `C:\otr\` 作成・long path `LongPathsEnabled` レジストリ・VS 導入/PATH）／**base2**（`C:\otr\` 作業ツリー）。誤検知（config の `FxContainerization` は読み取り機構、logging/richclient/transmission の「サービス」は WS 用語）は除外。置き場は作者選択で **規約→AGENTS.md／ログ→別ファイル**：`src/instructions/AGENTS.md` の「プロジェクト ポリシー」に **### マシン/ユーザ全体に残る変更は `SETUP-CHANGES.md` に記録する**（種別/対象/値/日付/巻き戻し・コミットする・AGENTS.md 自体には書かない〔再インストールで上書き〕・対象例と該当3スキルを列挙）を追加。常時ロードで効くので各スキルは**短ポインタのみ**（重複回避）：resource-config〔OT_RESOURCE_ROOT＋未設定マシンは起動失敗の配布注意も併記〕・config ⑦〔State Service〕・build §1〔C:\otr／long path〕。実ログ `SETUP-CHANGES.md` は target 側で生成する運用（アセット repo には置かない）。AGENTS.md tok~4422（常時ロード枠内） |

| 新スキル `opentouryo-project-setup-db`（選択式の DB/データストア構築・作者提案・**2026-07-19**） | 環境（データストア）構築が既存スキルに無く、⑦ config の接続確認・run-verify の DB 依存操作の前提が満たせなかった。作者が実運用で使う **LocalServicesOnDocker**（NetDevInfraWGinOSSConsortium）で SQL Server/MySQL/PostgreSQL/Redis/MongoDB を Docker 起動する**選択式（任意）**スキルを新設。WebFetch＋ミラー突合で**既定が OpenTouryo サンプルの接続文字列と一致**を確認（SQL 1433/sa/`seigi@123`/Northwind＝`ConnectionString_SQL`、MySQL 3306/root/`seigi@123`/test＝`ConnectionString_MCN`。同系プロジェクトで設計が揃っている）。多くは無改変で接続可。**Oracle は本 Docker に無い**（`ConnectionString_ODP`＝SCOTT/tiger は別途）。Docker のコンテナ/ボリューム/ネットワーク `common_link` は**グローバル変更＝`SETUP-CHANGES.md` に記録**（前項ポリシー）。位置づけ＝**必須ではなく選択式**（既存 DB あれば不要）。反映：ファサード flow に「（選択式）データストア」行／README ①群／AGENTS 表／config ⑦・run-verify から相互参照。install.ps1 で拾えることを実測。全33→34スキル |

| AGENTS.md のスキル表を README リンクへ置換／README を表形式（使いどころ）に（作者提案・**2026-07-19**） | 「エージェントは各 `SKILL.md` の `description` で自動認識するので、AGENTS.md〔常時ロード〕に 34 行の表を持つのは重複」との指摘（妥当）。→ **AGENTS.md `## スキル` の表を撤去**し、「description で自動認識・配置先・**一覧と使いどころは README 参照**（GitHub blob リンク）」の短い案内に置換。**README には `## スキル一覧` を新設**し、これまでのグループ分け（①立ち上げ・構成／②各層のコード実装／③制御・定義・横断）を**3つの表〔スキル｜使いどころ〕**にして使いどころを明記（AGENTS の良質な使いどころ文を移設）。構成ツリーの巨大なスキル列挙は1行に圧縮。効果：**AGENTS.md tok~4422→3403**（常時ロード枠を約1000 節約）。README に全34スキルが揃うことを `grep` で確認（欠落0）。リンクは target 配置の AGENTS.md からも辿れるよう GitHub の絶対 URL |

| 生成スクリプトの置き場を `scripts/` に明示（作者報告・**2026-07-19**） | 生成した `.ps1`（`setup-build.ps1`/`build-app*.ps1`/`setup-build-netcore.ps1`/`…-richclient*.ps1` 等 多数）が**リポジトリ ルートに散乱**していた。スキルは「スクリプト化して残す」とだけ言い、置き場が未指定だったのが原因。→ **`opentouryo-project-setup-build`** に「生成 `.ps1` は `scripts/` に置く（ルート直置きしない）」を明記＋やってはいけないこと更新。**雛形の `$repo` を親参照に修正**：`scripts/` 配下だと `$PSScriptRoot` が `scripts\` を指すため `$repo = Split-Path -Parent $PSScriptRoot`（相対 HintPath・ベンダ先はルート基準）。`examples.md` の3スクリプト（setup-build / setup-build-netcore / build-app）の `$repo` を全て修正＋冒頭に配置注記。`.gitignore`（⑦）は `scripts/` を除外しないので従来どおりコミットされる。**追記**：`$PSScriptRoot` 基準なので**どのカレントディレクトリからでも実行可**（examples 全行で CWD 相対パス無し・`.\` は `Push-Location $cs` 内のみ確認）。前提＝`.ps1` として実行〔貼り付け実行だと `$PSScriptRoot` 空〕・`scripts\` はルート直下1階層〔`Split-Path -Parent` が1階層前提〕を setup-build/examples に明記 |

| 再実行（Batch・net48）で判明した K〔run-verify に Batch/CLI 検証手順〕/L〔`Console.ReadKey` で exit code 不信〕＋DB 条件付き訂正（作者報告・**2026-07-19**。**DB 依存操作が初めて実測で通った**：localhost SQL Server/Northwind で SelectCount 3件） | **K（スキル）**：run-verify に Batch/CLI の検証手順・合否基準が無かった（Web＋デスクトップまではあった）。→ **`run-verify.md` に「バッチ/CLI」節を追加**：(a) 実行前にサンプルの `readme.txt` で**必要な引数を確認**（無引数だと `argsDic["/DAP"]` 等で `KeyNotFoundException`＝引数不足。SimpleBatch は `/Dap SQL /Mode1 individual /Mode2 static /EXROLLBACK -`）、(b) 合否＝framework 初期化＋業務ロジック到達（出力「3件のデータがあります」等）、DB があれば結果件数まで、(c) **exit code で判定しない**（下記 L）。**L（本体＝サンプルコード。OpenTouryo への Issue 候補）**：`SimpleBatch_sample` が末尾で `Console.ReadKey()`（Program.cs 79/85）を呼ぶため、**非対話（stdin リダイレクト）だと成功でも `InvalidOperationException` で exit code 非ゼロ**（業務処理は成功済み）。ミラー確認：**`RerunnableBatch_sample`/2/3 も全て `Console.ReadKey` あり**（＝バッチ サンプル全般。無人実行前提のバッチに ReadKey は不適切→コンソール有無で分岐 or 削除が望ましい、が本体側指摘）。スキルは「成否は標準出力で判定」で回避。**訂正**：これまでの「DB 依存は対象外」を**条件付き**へ（DB があれば結果まで確認／無ければ対象外）＝desktop 節も同様に修正。**本体 Issue 候補は L**（久々の本体側指摘） |

| 派生（variant）も勝手に決め打ちされた＝選択を2段階に明文化（作者報告・**2026-07-19**） | 前回「①系列を全部提示」を直したが、**その1段深い派生レベルで再発**：バッチ系列を選んだ後、`RerunnableBatch_sample`/2/3・`SimpleBatch_sample` の中から **`SimpleBatch_sample` が無選択で選ばれた**。原因＝selection の旧文「派生は系列を選んだ後の枝**でよい**」が「代表を自動で選んでよい」と解釈された。→ **selection を「サンプル選択は2段階」に書き換え**：①系列を全部提示、②**選んだ系列に複数のサンプルがあれば派生も提示して選ばせる（代表を1つに決め打ちしない）**。例列挙（バッチ＝Simple/Rerunnable〜3、WSClient＝Win/WPF/Win2/WinCone、2CS＝機能デモ各種）。派生が1つのときだけ確認不要。やってはいけないことにも「派生を勝手に1つに決め打ちする」を追加。selection tok~2426（目安内） |

| RerunnableBatch 実測で判明した N〔相対 `.\Dao` は張替しない〕＋K〔同梱 `CREATE *.sql` の適用〕/L〔`ReadKey` は Rerunnable も同様〕補強（作者報告・**2026-07-19**。DB稼働・ORDERS2既存で 830行 INSERT 成功＝「DB があれば結果まで」の実例） | **N（スキル）**：⑥ resource-config の「相対パス不可／絶対→`%OT_RESOURCE_ROOT%`」原則を素直に適用すると **`RerunnableBatch_sample`〜3 の `SqlTextFilePath=.\Dao`（相対・意図的設計）を書き換えて壊す**危険。ミラー確認：Rerunnable 3種は `.\Dao`＋`Dao\*.sql/.xml` を `CopyToOutputDirectory` で `bin\Debug\Dao` へコピーする自己完結型（SQL は resource\ 側に無い）。SimpleBatch のみ絶対パス（`C:\root\files\resource\Sql`）＝張り替え対象。→ **`resource-config.md` に「★ 例外：SQL 同梱の自己完結型（`.\Dao` 等）は張り替えない」節を追加**（張り替え対象＝共有 resource\ を絶対パスで参照するキーだけ。相対＝`bin\Debug` から実行前提。「相対不可」は IIS 等 CWD がアプリ外のプロセスの話と整理）＋キー一覧の `SqlTextFilePath` 行に例外参照。**K補強**：Rerunnable は引数不要だが **DB スキーマ前提**（Northwind に `ORDERS2`、同梱 `CREATE ORDERS2.sql`）→ run-verify バッチ/CLI 節に「同梱 `CREATE *.sql` を確認・適用」を追加、**setup-db にも「サンプル固有テーブルは Northwind に含まれない＝同梱 SQL を流す」**を追記（db tok~1472）。**L確定**：Rerunnable でも `Console.ReadKey()`（79/136/145）実測確認＝バッチ variant 共通で確定（run-verify に「Simple/Rerunnable 系共通・実測」明記）。**追記（2026-07-19）**：skill-issue ファイルの N/K/L に sample2 の再確認→さらに **Issue L を「バッチ全4 variant で確認」に更新**（`_sample3` を「推定」→確認済みに昇格）。ミラーで sample2/sample3 とも同一を確認（`Console.ReadKey` 79/136/145、`SqlTextFilePath=.\Dao`、`CREATE ORDERS2.sql` 同梱、Rerunnable 3種は 830行 INSERT）＝実測エビデンスが Simple＋Rerunnable×3 の**全4 variant** に。**追記（2026-07-19・.NET10 補強）**：skill-issue に core 側の再確認が加わり **N/L は net48/.NET10 両ランタイムで確定**。ミラー確認＝core ReadKey は SimpleBatch L86/92・Rerunnable×3 L86/143/152、`SqlTextFilePath` は Simple 絶対 `C:/root/files/resource/Sql`／Rerunnable×3 相対 `./Dao`（**core はスラッシュ**、net48 は `.\`）。→ **スキル反映**：resource-config の N 例外を「`.` 始まりの相対（net48 `.\`／core `./`）」＋出力先（core は `bin\Debug\net10.0-windows7.0\Dao`）＋「net48/.NET10 共通の規則」に一般化。run-verify の L に exit code `0xE0434352`/-532462766・「両ランタイムで実測」を明記。config スキル本体（SKILL.md）不変＝tok 影響なし |

| O：CLI は .NET 10.0 のみ（net48 はドロップ）だが selection 系列表が「net48 / .NET 10.0」と誤記（作者報告・**2026-07-19**） | selection の系列表・提示表が CLI を net48/.NET10 と表示していたが実態は **.NET 10.0 専用**。ミラー確認：net48 `Samples\CLI_sample\{Simple_CLI,DAG_Login_CLI,LIR_Login_CLI}` は **csproj 無し・README のみ**（`Simple_CLI\README.md`：「Sharpromptが.NET Fxのサポート終了したので…ドロップした」）。.NET10 `Samples4NetCore\Legacy\CLI_sample\*\*\*.csproj` は3本とも実在。→ **selection の系列表 CLI 行を「.NET 10.0 のみ」に是正**＋表下に「★ CLI は .NET 10.0 のみ（net48 はドロップ／Sharprompt が .NET Fx 終了。Web Forms が net48 のみ、の逆）」注記＋やってはいけないことを「ランタイム対象外の組合せ（Web Forms を core／CLI を net48／net48 専用を core）」に一般化。selection tok~2562（目安内）。本体側の欠陥ではない（依存ライブラリ都合の意図的ドロップ） |

| O続報：2CS 機能デモを「.NET10 のみ」と誤提示＝実在する net48 を落とした（O と逆方向。作者報告・**2026-07-19**） | selection の派生提示で **2CS 機能デモ `CustCtrl`/`GenDaoAndBatUpd`/`TimeStamp` が「.NET10 のみ」と表示され net48 が欠落**。ミラー確認：この3デモは **net48（`Samples\2CS_sample\`）・.NET10（`Samples4NetCore\Legacy\2CS_sample\`）両方に csproj 実在**＝両対応。さらに `AsyncEvent_sample` は **net48 のみ**（.NET10 に無い）の非対称も発見。原因＝派生ごとのランタイム可用性を確認せず決め打ち（O の「間引き」の派生ランタイム版）。→ **selection の派生提示注記(2)に 2CS 機能デモを実名列挙＋ランタイム明記**（CustCtrl/GenDaoAndBatUpd/TimeStamp＝両対応、AsyncEvent＝net48 のみ）、**新項(3)「派生ごとに対応ランタイムが違うことがある＝勝手に落とさない。csproj の有無（`Samples\`＝net48／`Samples4NetCore\`＝.NET10）で判断」を追加**。ミラー参照はスキル本文に書かない方針に従い「派生フォルダの csproj」表現に修正。selection tok~2724（目安内）。本体欠陥ではない（提示側の確認漏れ） |

| ランタイム表記を TFM（Target Framework Moniker）に統一（作者指示・**2026-07-19**） | `net48`（TFM）と `.NET10`/`.NET 10.0`（非 TFM）が混在していたのを **`.NET10`/`.NET 10.0`/`.NET 10` → `net10.0`**、**`.NET Framework 4.8` → `net48`** に一括統一（16ファイル・70箇所：skills 全般＋`src/instructions/AGENTS.md`）。除外＝`netcore100`（実バッチ名）・`.NET Core`/`core`/`netcore`（略称）・`net10.0-windows7.0`（既に TFM）・`.NET SDK`/`.NET Fx`（製品名）。誤爆源（`.NET 10.0.302` 等バージョン列）が無いことを確認済み。置換は短縮方向＝全スキル トークン減（例 auth 4958→4952）＝目安内維持。**注**：本 §4.3 の過去ログ記述（実測時点の `.NET10` 表記）は履歴として残す |

| WSClient_sample（3層 WS クライアント・net48）の取り出しを「決め打ち手順」化＝エージェントに判断させない（作者方針＋WSClientWin 完了報告・**2026-07-19**） | 方針「スキル利用エージェント側になるべく選択・判断させない」。WSClientWin 追加の実測報告から、毎回の判断だった4点を **`samples/webservices.md` に「WSClient_sample の取り出し＝以下で決め打つ」節として固定**：①**フラット化しない**（元階層 `WS_sample\WSClient_sample\<派生>\` 維持。`..\..\Build\`＝`WS_sample\Build\` の WSServer/WSIFType DLL 参照を保つため。MAX_PATH は long path で回避＝フラット化例外）②**⑤ HintPath は2系統**（OpenTouryo.*＋Newtonsoft→`..\..\..\OpenTouryoAssemblies\Build_net48\`〔3階層〕、WSIFType/WSServer→`..\..\Build\` 維持）③**`_all.sln` は削除・単一 `.sln` を使う**（`_all.sln` は `Frameworks\...\ServiceInterface\WCFService`/`ASPNETWebService` の**ソース プロジェクト参照**＝DLL 参照方針で不成立）④**⑥⑦ config は2キーのみ**（`SqlTextFilePath`→`%OT_RESOURCE_ROOT%\Sql`、`SpRp_RsaCerFilePath`→`%OT_RESOURCE_ROOT%\X509\SHA256RSA_Server.cer`。`FxXML*` は `EmbeddedResource`＝張替不要）。ミラー裏取り済み（csproj HintPath・`_all.sln` の WCFService/ASPNETWebService 参照・app.config 2キー絶対・EmbeddedResource 18件）。MAX_PATH 節にも「WSClient は例外＝フラット化しない」を追記。core SKILL.md は既に webservices.md を参照＝本体不変・トークン枠影響なし。到達点は「開ける・ビルド通る」まで（WS モード実動は WS ホスト起動＝範囲外） |

| 【重要訂正】3層CS の WS ホスト `Frameworks\Infrastructure\ServiceInterface` を引き込む工程が欠落＝実動不可だった（作者指摘・**2026-07-19**） | 前項で「WSClient は `_all.sln` 削除・単一 sln／WS ホストは範囲外」としたが**誤り**。ミラー精査で 3層CS の実動連鎖が判明：`WSClient →[WS protocol=2]→ ServiceInterface ホスト（WSServer_sample/WSIFType_sample を参照し OpenTouryo DLL 上でホスト）`。`ServiceInterface` は **`ASPNETWebService`（既定＝クライアント app.config が `TMProtocolDefinition2.xml`＝Web API 経路。`packages.config`→nuget restore）** と **`WCFService`（代替・`TMProtocolDefinition.xml`・`PackageReference`→restore）** の2ホスト。`_all.sln` は client＋WCFService＋ASPNETWebService を束ねる正しい3層構成だった（削除は誤り）。→ **`samples/webservices.md` の当該節を「3層CS＝クライアント＋WS ホストをセットで引き込む」に全面改稿**：①クライアント（従来手順）②業務ロジック（(A)節）③**WS ホスト引き込み**（`Frameworks\Infrastructure\ServiceInterface\` の相対位置を保つ＝`_all.sln` 解決／OpenTouryo.* を Build_net48 へ・WSServer/WSIFType を引き込んだ `WS_sample\Build\` へ張替／ASPNETWebService=nuget restore・WCFService=/t:Restore／`_all.sln` を使う）。到達点＝3プロジェクト 0 error ビルド、WS 実動確認は run-verify（ASPNETWebService を IIS Express 起動→クライアントから protocol=2 呼び出し）。**run-verify** のデスクトップ節「WS サーバ側起動」を ServiceInterface/ASPNETWebService 具体化。**facade** の禁止「Frameworks を取り込んで改造」に例外注記（WS ホストは実動必須で引き込む＝改造でなく配置・起動。facade body tok~2874・目安内）。ミラー裏取り済み（ServiceInterface 2 csproj の OpenTouryo/WSServer 参照・restore 方式・_all.sln の3プロジェクト・クライアント TMProtocolDefinition2 既定） |

| 開発支援ツール（DaoGen/DPQuery）の取り出し先を `OT_Tools\` 配下に固定（作者指示・**2026-07-19**） | 従来はリポ直下（`Tools\<tool>` 例示・HintPath `..\OpenTouryoAssemblies\...`＝1階層）で配置がやや曖昧。→ **`OT_Tools\DaoGen_Tool\` / `OT_Tools\DPQuery_Tool\` の1通りに固定**（`OT_Tools\` 配下にまとめてリポ直下に散らさない）。2階層になるので**ベンダ先 HintPath を `..\..\` に更新**（net48＝`..\..\OpenTouryoAssemblies\Build_net48\`、core＝`..\..\OpenTouryoAssemblies\Build_netcore100\net10.0\`）。反映：`samples/daogentool.md`・`samples/dpquerytool.md`（配置＋HintPath 深さ）、`opentouryo-project-setup-core` SKILL.md（取り出し先明記・tok~1467）、facade の配置固定規則に「開発支援ツールは `OT_Tools\` 配下」を追加（tok~2973）。いずれも目安内。原ソース（`Frameworks\Tools\<tool>`）と csproj 名（net48=`<tool>.csproj`／core=`<tool>Core.csproj`）は不変 |

| 【重要設計変更】`WSIFType_sample`/`WSServer_sample` を DLL 参照→ProjectReference に全面切替（作者指示・**2026-07-19**） | 指示：`WS_sample\{WSIFType_sample,WSServer_sample}` のバイナリ出力を参照していた**全アプリ**を DLL 参照→ProjectReference に。理由＝`WSServer_sample`=B・D層、`WSIFType_sample`=受け渡し型で、導入側が **P・B・D 層を並行開発**する対象だから（フレームワーク `OpenTouryo.*` は従来どおり DLL 参照）。→ **原則を確立**：フレームワーク＝DLL 参照／サンプル自身の B・D・型＝ProjectReference。**`WS_sample\Build\` への DLL コピー（copy-to-Build）は全廃**。反映（6ファイル）：**webservices.md**＝「なぜ CS0246／参照方式の使い分け／(A) 1ソリューション並行開発／3層CS 節（client step2・host bullet を ProjectReference 化・sln に WSIFType/WSServer も含める・到達点 5プロジェクト）／MAX_PATH（WS 系はフラット化しない理由を ProjectReference 相対パスに）」を全面改稿。**core SKILL.md**＝(A)/(B) 要約を ProjectReference に（tok~1550）。**webforms.md**＝WebForms も (A) で WSIFType/WSServer を ProjectReference、MySql/Oracle は 3rd-party＝ベンダ DLL 参照に張替。**reference-rewrite.md**＝WSServer/WSIFType は DLL 張替の対象外＝ProjectReference と除外注記。**transform SKILL.md**＝WS 参照除去の記述を「(A)＝ProjectReference」に整合（tok~2522）。**examples.md build-app.ps1**＝WS 別ビルド＆コピーを廃し WebForms ソリューション一括ビルド（WS は ProjectReference で同時ビルド）に改訂＋ツール path を `OT_Tools\` に。ミラー裏取り済み（WSServer→WSIFType は元から ProjectReference・OpenTouryo.* は各所 DLL・consumer は WS_sample\Build\ を DLL 参照）。※ホスト/クライアントの ProjectReference 相対深さは実ビルド未検証＝「配置に合わせる」表記 |

| WSClientWin 実ビルド完了報告からの §③ 精度向上4点（作者報告・**2026-07-19**。`_all.sln` 5プロジェクト 0 error 達成） | 実測で判明した記載の齟齬・漏れを webservices.md §③ に反映：**(1) `_all.sln` のホスト参照は「そのまま解決」しない**＝源は `Samples\` 階層前提（client から `..\..\..\..\Frameworks`）。`Samples\` 段を落とす repo 規約では client が3階層になり up4 が root を突き抜ける→ホスト参照を `..\..\..\`（up3）に**1段減らす**。§① の「フラット化しない」を「`Samples\` 段は落とす＝WS_sample はリポ直下・内部階層のみ保持（client 3階層）」に明確化。**(2) ASPNETWebService（packages.config）の復元先**＝`_all.sln` 一括 restore は packages をソリューション側に置くが、csproj は相対 `packages\...`（`Microsoft.Data.SqlClient.SNI.targets`）→ `nuget restore <asp>\packages.config -PackagesDirectory <asp>\packages` で project 直下へ別途復元が必須。**(3) ホスト config の resource 張替漏れ**＝ASPNETWebService/WCFService の app.config に `C:\root\files\resource\...` が**6キー**（FxXMLMSGDefinition/FxXMLTCDefinition/FxXMLTMInProcessDefinition/FxLog4NetConfFile/SqlTextFilePath/SpRp_RsaCerFilePath）。`%OT_RESOURCE_ROOT%` 化（build 不要・run-verify で必要）。ASPNETWebService は `Web.config` の `<appSettings file="app.config">` で app.config を実行時マージ（Web.config だけ見ると見落とす）。綴りは ASPNETWebService=`Xml`／WCFService=`XML`。**(4) `_all.sln` のインデント**＝このサンプルの `ProjectConfigurationPlatforms` はタブ2個＝追加行は既存に合わせる。ミラー裏取り済み（host app.config 6キー・Web.config appSettings file=・綴り差）。**CLI 再掲**は前セッションで修正済み（表・★注記とも「net10.0 のみ」で一致）＝齟齬解消済み。**申し送り解決状況**：**項目1（ProjectReference 段数）＝解決**——今回の実ビルド（0 error）＋レイアウト完全固定で、client→WSServer/WSIFType＝`..\..\WSServer_sample\...`（WS_sample 内2階層・(A)節既載）、host→WSServer/WSIFType＝`..\..\..\..\WS_sample\WSServer_sample\...`（host 4階層・§③ に明示）と決め打ち確定。**項目2（build-app.ps1 新フロー）＝未解決のまま**——今回は WSClient を `_all.sln` 直ビルドで検証しており、build-app.ps1（WebForms 用・WS を ProjectReference で同ソリューション一括ビルドする改訂フロー）は再実行未検証。冒頭注記は維持 |

| `WSClientWin2_sample` は WS 非依存の単独 P層 UI デモ＝「WSClient 系＝全部3層」前提を是正（作者報告・**2026-07-19**。Win2 net48 ビルド 0 error） | 「`WSClient_sample` の派生 Win/WPF/Win2/WinCone は全て3層WSクライアント（5プロジェクト必須）」という前提が誤り。ミラー確認で **variant 4種のうち Win/WPF/WinCone は WS 依存あり（WSServer/WSIFType を ProjectReference・WS 型使用・`_all.sln` あり）／`Win2` のみ WS 依存なし**（ProjectReference 0・WS 型 0・単一 `.sln` のみ）＝UserControl 親子やフォーム間戻り値受け渡し等の**単独 P層 UI コントロール デモ**。Win2 は WS ホスト（ServiceInterface）引き込み不要・源同梱の単一 sln で成立・app.config に絶対 resource パス無し（⑥⑦ 実質ゼロ。ローカル Content XML=MSG/SPDefinition/SampleLogConf2CS は出力コピー）。ただし **`Business.RichClient` は参照する**ので ③ の RichClient 追加ビルドは Win2 にも必要（WS 軸と RichClient 軸は別）。→ **selection**：系列表の 3層行を「WPF/WinCone は WS 依存あり・**Win2 は例外＝WS 非依存の単独 P層 UI デモ**」に、派生列挙も同様に是正（tok~3373）。**webservices.md**：3層CS 節の対象を `<Win/WPF/WinCone>` に絞り「★ WSClientWin2_sample は例外＝この節の対象外」注記を追加。ミラー裏取り済み |

| WSClient の「Win 実測を variant 全体に一般化」を「csproj を見て判断」へ寄せる＋取りこぼしファイル確認（作者フィードバック 1〜5・**2026-07-19**） | 前項で Win2 を個別是正したが、根因＝「Win の挙動を variant 全体の決め打ちに一般化」がまだ残る。→ **webservices.md の 3層CS 節を判定ゲート方式に再構成**：見出しを「まず csproj を見て『3層WSクライアントか単独 P層か』判定する」に変え、**名前（Win/WPF/Win2/WinCone）で決め打ちせず csproj の `WSServer_sample`/`WSIFType_sample` 参照・WS 型使用・`_all.sln` 有無で分岐**（あり→client＋server＋host 一式／なし→単一 sln で DLL 参照だけ張替。Win2 は後者）と明記。**実ビルドは Win のみ／WPF・WinCone はミラー確認済み・未ビルド**の但し書きも追加（点1）。**config「2キーだけ」→「app.config に絶対パスが在るキーを張替（variant で有無・数が違う）」に緩和**（点3）。**selection**：WS/3層依存内訳を「Win/WPF/WinCone＝WS 必須／WSClient の variant は依存構造が異なる＝名前で決めず csproj で判断」に是正（点2。tok~3503）。**core SKILL ④**：**取り出し後、csproj の `<Compile>`/`<EmbeddedResource>`/`<None>`/`<Content>` の Include を実ファイルと突き合わせ欠落確認**（サブツリー選択展開で `Properties\AssemblyInfo.cs` 等を取りこぼす実測。点4。tok~1745）。**点5（CLI net48/net10.0 表記）は既に修正済み**（表本体・★注記とも「net10.0 のみ」）＝再掲は解消済み。根因の共通解＝「variant 差は csproj を見て判断」（ランタイム・WS 依存・config 各軸で同原則） |

| WSClientWPF 追加で新規 A〔源 `_all.sln` は3プロジェクト〕/B〔platform セットが variant 差〕・裏付け C〔config キー数の variant 差〕/D〔取りこぼし再現〕/E〔variant 非同質〕（作者報告・**2026-07-19**。WPF 5プロジェクト 0 error） | WPF は Win と同じ5プロジェクト WS 構成（WSServer/WSIFType 参照・AsyncFunc・TMProtocol XML あり）＝判定ゲートが正しく「該当側」に分岐した実証。**新規反映**：**A/B（sln）**＝ミラー確認で**源の `_all.sln` は全 variant 3プロジェクトのみ**（client＋2ホスト。WSServer/WSIFType 無し・client は DLL 参照）＋**SolutionConfigurationPlatforms が variant で違う**（Win/WinCone=8種〔.NET/AnyCPU/Mixed/x86〕・WPF=4種〔AnyCPU/x86〕）。→ webservices.md の sln 手順を「**動く5プロジェクト `_all.sln` を雛形にコピーし client 行〔名前・パス・GUID〕だけ差し替え、共有4プロジェクトは流用**。雛形が無い初回だけ源3プロジェクト sln に WSServer/WSIFType 追加＋client を ProjectReference 化」に変更（platform 手編集を回避＝再現性）。**C（config）**＝実測が Win=2/WPF=1〔SqlTextFilePath のみ〕/Win2=0 とバラつき＝「絶対パスが在るキーだけ張替」の裏付け強化→config 節に 0/1/2 と WPF=1 を明記。**D（取りこぼし）**＝`Properties\AssemblyInfo.cs` 漏れが Win2・WPF 連続再現→④ の欠落確認に「2サンプルで再現」追記。**E（variant 非同質）**＝Win/WPF=5プロジェクト側・Win2=単独 P層側＝判定ゲート方針を再確認。**実ビルド済みを Win→Win/WPF に更新**（WinCone のみ未検証）。core tok~1776。ミラー裏取り済み |

| WSClientWinCone 完了＝WS 系4 variant 全実測（ClickOnce・第3依存形・config 4/4 確定。作者報告・**2026-07-19**。5proj 0 error） | 4 variant すべて実ビルド到達。**新規反映**：**ClickOnce（新規・重要）**＝WinCone は `SignManifests=true`＋thumbprint＋`.pfx`＋`GenerateManifests=true`（"Cone"）で素の `/t:Build` が **`MSB3482`（No certificates found）で署名失敗**。→ webservices.md に「★ ClickOnce variant（WinCone）＝`SignManifests=false` で回避（到達点はビルド/オープンまで＝publish 目的外・repo 内 csproj 変更のみ＝SETUP-CHANGES 不要）。`.pfx`/`Properties\app.manifest` も取り出す」を追加。**第3依存形**＝WinCone は **client が WSIFType のみ参照**（WSServer は client 非参照・PackageReference 無し）＝依存形は3種（Win/WPF=両参照・Win2=無・WinCone=WSIFType のみ）→ ①手順を「client が参照する WS プロジェクトは variant による」に、判定節に **4 variant 実測表**（client の WS 参照／config キー数／構成／特記）を新設。**config 4/4 確定**＝Win=2・WPF=1・WinCone=1・Win2=0＝「2キー決め打ちは誤り・app.config に在るものだけ張替」を4/4 で確定（③config を4 variant 完全データに）。**④の突き合わせを「毎回必須」に格上げ**＝取りこぼしは非決定的（Win2/WPF で漏れ・WinCone で漏れず）＝漏れた時だけ対処では不可（core tok~1823）。実ビルド済み＝Win/WPF/WinCone（＋Win2 単独）＝**4 variant 完了**。ミラー裏取り済み（WinCone csproj ClickOnce・WSIFType のみ・.pfx/app.manifest・app.config SpRp 1件） || 取り出しフォルダ命名を決め打ち規則に固定＝エージェントに判断させない（作者の現行構成提示・**2026-07-19**） | 実環境の現行構成（2CSClientWin_sample＋_Core、MVC_Sample＋_Core、SimpleBatch/Rerunnable×3＋各_Core、WebForms_Sample〔net48 のみ無印〕、Simple_CLI〔.NET10 のみ無印〕、WS_sample 階層維持）から命名規則を抽出。従来のファサード記述は「別名（`MVC_Sample_Core` 等）」止まり＝命名がエージェント任せだった。→ **`opentouryo-project-setup` の冪等性節を4規則に固定**：①net48 は元名のまま ②core は**衝突する net48 が在るときだけ `_Core` 接尾辞**（MVC_Sample_Core 等） ③net48 のみ（WebForms_Sample）・.NET10 のみ（Simple_CLI）は無印 ④WS 系は `WS_sample\` 階層維持（フラット化しない→webservices.md）。現行構成の全エントリと一致を確認。facade tok~2650（frontmatter 除く・目安内） |

| 命名規則の `_Core` 判定を「実衝突」→「net48 版の存在（固定属性）」に明確化（作者質問・**2026-07-19**） | 「net48 と衝突するときだけ `_Core`」が (a) repo 内で実際に今ぶつかる時 か (b) そのサンプルに net48 版が存在する時 か曖昧との指摘。→ **(b) に確定**（(a) は順序依存＝core を先に入れると無印で置き→後で net48 追加時に既存 core を改名する判断が発生＝方針「判断させない」に反する）。**判定材料＝そのサンプルが net48（`Samples\`）にも在るか、という選択時点で確定する固定属性**。core は net48 を repo に入れる前から `_Core`、順序不問・後改名なし。.NET10 のみ（Simple_CLI＝net48 版なし）は無印。facade の該当箇所を「net48 版が“存在する”とき（両ランタイム対応サンプル）／repo にいま入れたかは無関係」と書き換え |

| 2CS 機能デモ7本 完了＋新規落とし穴〔CustCtrl は `CustomControl.RichClient`（WinForms 版）が標準ベンダに漏れ〕（作者報告・**2026-07-20**。7本 0 error） | CustCtrl/GenDaoAndBatUpd/TimeStamp（net48＋_Core）＋AsyncEvent（net48・WinForms/WPF の2 exe）を取り出し。**新規（重要）＝CustCtrl は `OpenTouryo.CustomControl.RichClient`（WinForms 版）を参照**するが、標準ベンダ `Build_net48\` には **WebForms 版 `OpenTouryo.CustomControl.dll` しか無い**ことがあり漏れる（`Business.RichClient`＝H と同型の**第2の RichClient 欠落**）。ミラー確認：`Frameworks\Infrastructure\CustomControl\RichClient\CustomControl.RichClient_net48.csproj` は実在。**【翌日訂正 2026-07-20】当初「どの `.sln` にも含まれない＝単体ビルド」としたが誤り**（ミラーに `BusinessRichClient_net48.sln` 自体が無く grep 不成立を誤断定）。作者の実クローン確認では **`CustomControl.RichClient_net48` は `BusinessRichClient_net48.sln` に同梱**（`Business.RichClient` と同じ sln）で、**ベンダのコピー手順（`4_Build_CopyAssemblies` 相当）が漏らしていた**だけ。→ 正しい対処＝**`BusinessRichClient_*.sln` 追加ビルド後に sln の全出力がベンダされたか照合し `CustomControl.RichClient.dll`(/.pdb/.xml) も入れる**（単体 csproj ビルドでも可）。**netcore は元々揃う**（net48 のみの漏れ）。→ **build SKILL** の ③ RichClient 節を訂正＋「RichClient 追加ビルド後は sln 生成物を照合」の汎用教訓（tok~4679）、**selection** の RichClient 注記も同旨（tok~3028）。**裏付け**：ZIP サブフォルダ取りこぼし（Dao/Business/Common/Properties 欠落）を **④の Include 照合（毎回必須）で検出**＝当該手順が再度奏功。⑥ resource 移設は不要（デモは埋め込み or `.\Dao` で自己完結＝「絶対パスが在るキーだけ張替」通り0件）。AsyncEvent は2 exe 構成で HintPath 2階層（`..\..\`） |

| Login CLI 2本 完了＋セッション横断フィードバック A〜B〔6点〕（作者報告・**2026-07-20**。DAG/LIR Login CLI・net10.0・`--help` exit 0） | `DAG_Login_CLI`/`LIR_Login_CLI`（.NET10・二重ネスト維持）取り出し。反映6点：**A-1〔CustomControl.RichClient〕**＝前項の訂正（sln 同梱・コピー漏れ）を build/selection に反映済み。**A-2〔`_Core` 内側名リネームの実害〕**＝facade の `_Core` 規則が「.sln・参照も `_Core` 名に」で**内側 csproj/AssemblyName までリネームと誤読可能**→**「フォルダ名だけ `_Core`、内側 csproj/sln/AssemblyName は原名維持」に訂正**。実害＝`GenDaoAndBatUpd_sample` は `SqlTextFilePath="GenDaoAndBatUpd_sample.Dao"`（埋め込みリソース名前空間＝アセンブリ名依存。ミラー net48/netcore 両方で確認）＝アセンブリ名を変えると SQL 解決が実行時に壊れる（facade tok~2780）。**A-3〔ZIP 取りこぼし〕**＝「非決定的」表現を訂正→**`/*`（非再帰）は `Dao\`/`Business\`/`Common\`/`Properties\` を丸ごと落とす決定的挙動。`/**`（再帰）を使う**＋Include 照合は毎回必須のまま（core tok~1680）。**B-4〔非SDK csproj 直ビルド〕**＝`msbuild X.csproj /p:Platform="Any CPU"` は csproj 条件が `AnyCPU`（空白なし）のため OutputPath 未定義で失敗→**.sln 経由 or `/p:Platform=AnyCPU`**（reference-rewrite.md に追記）。**B-5〔CLI 依存差〕**＝`Simple_CLI` は OT 依存0（純テンプレ）だが `DAG/LIR_Login_CLI` は OT 依存あり（Framework/Public/Public.Security・net10.0）＝⑤ 張替要（selection）／非対話スモークは `--help`（RootCommand が `Prompt.Confirm` で対話ブロック・`login` は IdP `MultiPurposeAuthSite:44300` 前提＝範囲外。run-verify）。**6〔samples/*.md 起こし候補〕**＝custctrl/gendao-timestamp/login-cli は未作成（必要になれば起こす）。ミラー裏取り済み |

| WS ホスト ServiceInterface の配置を `WS_sample\ServiceInterface\` に集約（作者指示・**2026-07-20**） | 源 `Frameworks\Infrastructure\ServiceInterface` を、WS 一式（client/WSIFType/WSServer）と同じ **`WS_sample\` 配下（`WS_sample\ServiceInterface\<host>\`）** に置く方針へ。効果：Frameworks ツリーの部分取り込みが消え WS 関連が1箇所に集約、参照も短く一様に。**相対パス再計算**（host が4→3階層に）：host の `OpenTouryo.*` DLL＝`..\..\..\OpenTouryoAssemblies\Build_net48\`（4→3）、host→`WSServer/WSIFType` ProjectReference＝`..\..\WSServer_sample\...`（4→2＝client と同じ `..\..\`）、`_all.sln` の client→host 参照＝源 `..\..\..\..\Frameworks\...\ServiceInterface\` を **`..\..\ServiceInterface\<host>\<host>.csproj`** に張替（両者 `WS_sample\` 内の兄弟＝up2）。反映：**webservices.md** §③ 見出し・引き込み位置・_all.sln 参照・OpenTouryo/ProjectReference 段数、判定節の③、**facade** の WS 集約規則＋禁止例外注記、**run-verify** の WS ホスト起動、を `WS_sample\ServiceInterface` に統一（facade tok~2813）。旧「Samples\ を畳むと `..\` 段数がずれる」注記は新配置で不要になり削除 |

| アセット repo 内の `files/`（本体ソースミラー）を削除＝裏取りは実クローン2箇所を正に（作者指示・**2026-07-20**） | 「`files` を削除。以降は `D:\git\local\OpenTouryoProject\OpenTouryoDocuments` と `C:\otr` を参照」。→ 裏取り根拠を差し替え：**C# 実ソース＝`C:\otr\OpenTouryo-03-20\root\programs\CS\`**（旧 `files/csharp/` 置換。`Frameworks\Infrastructure\{Framework,Business,Public,CustomControl,ServiceInterface}`・`Samples\{2CS_sample,Bat_sample,CLI_sample,WS_sample,WebApp_sample}`・`Samples4NetCore\{Backend,Frontend,Legacy}`・`*_Build_*.bat` を実在確認）、**ドキュメント＝`D:\git\local\OpenTouryoProject\OpenTouryoDocuments\documents\`**。実クローンは旧ミラーより rich＝`Build_net48\`/`Build_netcore100\` 出力や `BusinessRichClient_net48.sln` 等の .sln も現物で確認できる（以前 A-1 で「ミラーに sln が無い」不確定が出た問題は解消）。反映：**§6.1 参照元**を新2ルートの表＋主要参照先パスに書換（`files/csharp/*` 表記を廃止）、memory `reference-csharp-source-mirror` を更新。**注**：`src/skills` 配下は元々 `files/csharp` を直接参照しておらず（grep 0件）**スキル本文の修正は不要**。設定/ログスキルの `C:\root\files\resource\…` は実行時インストールパスで無関係＝不変。過去 §4.3/§4.5 ログ中の `files/csharp` 表記は履歴として残す |

| 全24項目フルラン（`03-20`・完全新規リポ・全 0 error）で判明した DL/エンコード系の落とし穴（作者レポート `OTRVCAS\Reporting.md`・**2026-07-20**） | 全サンプル（MVC/WebForms/2CS×4/バッチ×8/CLI×3/WSClient 4 variant＋MVC・WebForms の WS 依存 net48 群）を実機で 0 error ビルド完走。**新規に踏んだ落とし穴2件をスキルへ反映**：**#1（重要）`WebClient.DownloadFile()` が GitHub codeload に 404**＝既定 TLS が古い（`HEAD` は 200 で紛らわしい）。→ **build SKILL §1＋examples.md の DL 2箇所**を `Invoke-WebRequest`＋`[Net.ServicePointManager]::SecurityProtocol=Tls12` に変更。**#2 `.ps1` の日本語コメントが `powershell.exe`(WinPS 5.1) で構文破壊**＝BOM 無しを Windows-1252 で読み、UTF-8 全角コメントが直後の文（`$ref='03-20'`）を巻き込み無効化→`$ref` 空→`archive/.zip` 取得で**「DL 404」に化ける**（原因特定困難）。既存の `.bat` 全角破損注記に**並ぶ `.ps1` 版注記を追加**（ASCII 化／BOM 付き保存／`pwsh` 実行のいずれか。雛形は ASCII 済み）。**#6 補強**：MSYS 経由 msbuild で `/nologo`→`C:/Program Files/Git/nologo`・`/p:`→`MSB1008` のスイッチ変換（既存の `.bat`/`cmd //c` 注記を msbuild スイッチにも一般化）。**既記載で再確認された分**（追加編集不要）：#3 WSClient の `Newtonsoft.Json` も Build フォルダ参照（webservices.md ⑤「2種」に既載）、#4 WinCone ClickOnce `MSB3482`→`SignManifests=false`、#5 ASPNETWebService の `packages.config` は project 直下復元（いずれもレポート「スキル記載通り」）。build SKILL tok~4935（追記後、要点圧縮で目安内）。**本体（OpenTouryo）の不具合ではなく非対話セットアップ固有の落とし穴**（レポート結論と一致） |

| 実リポ `OTRVCAS` のフォルダ構成をスキル意図と照合＝`WSClientWin2_sample` の配置が未定義で判断が入っていた（作者依頼の構成確認・**2026-07-20**） | 全24項目ビルド済みリポの構成を実物照合。**大半は意図どおり**を確認：命名（net48 原名／core は net48 版が在る時だけ `_Core`／WebForms=net48 のみ無印／CLI=net10.0 のみ無印）、**A-2（`_Core` はフォルダ名だけ・内側 csproj/sln は原名）完全準拠**（`MVC_Sample_Core\MVC_Sample\MVC_Sample.csproj`・`2CSClientWPF_sample_Core\2CSClientWPF_sample.csproj` 等）、WS 集約（`WS_sample\{ServiceInterface\ASPNETWebService, WSClient_sample\{Win,WPF,WinCone}, WSIFType_sample, WSServer_sample}`・階層維持）、`scripts\`・`tools\nuget.exe`・`resource\{Log,Sql,Xml,X509,Test}`・ベンダ `OpenTouryoAssemblies\{Build_net48, Build_netcore100\{net10.0,net10.0-windows7.0}}`、`.gitignore`（`Temp/`・`bin/`・`obj/`・`packages/`）。**唯一の乖離＝`WSClientWin2_sample` がトップ直下**（他 variant は `WS_sample\WSClient_sample\` 配下・HintPath 3階層だが Win2 だけ `..\` の1階層）。原因＝スキルが Win2 の**配置**を明示せず、エージェントが「WS 非依存だから単独＝トップ直下」と判断（＝「判断させない」方針の穴。ビルドは 0 error で内部整合は取れていた）。**作者判断（AskUserQuestion）：Win2 も `WS_sample\WSClient_sample\` 配下に統一・例外を作らない**。→ **webservices.md**（Win2 の「なし→単独 P層」節に「★ 配置は例外にしない＝`WS_sample\WSClient_sample\WSClientWin2_sample\`・HintPath は他 variant と同じ3階層 `..\..\..\`。WS 非依存は参照の話で置き場所は一律」を追記。tok~4537）、**facade**（WS 集約規則に「Win2 が WS 非依存でも配置は `WSClient_sample\` 配下＝例外を作らない」を追記。tok~2871）。現リポの top 直下 Win2 は移動対象（作者が実施） |

### 4.4 作者から得た情報（コードからは読めない）

**これらは実装を読んでも分からない。** 失うと再取得できない。

- **.NET Core 版の WS クライアント（`Samples4NetCore\Legacy\WS_sample\WSClient_sample\`）は実用性が無い**
  （作者情報 2026-07-18）。**`BinaryFormatter`（バイナリシリアライズ）が .NET Core で廃止**されたため、
  実質**インプロセス呼び出ししか動かず、本当の WS 越しの3層通信にならない**。コード／csproj を見ても
  「動く WS クライアント サンプルの1つ」にしか見えず、この非実用性は実装から読めない。→ **3層リッチ
  クライアントを実用するなら net48 側**（`Samples\WS_sample\WSClient_sample\`）を使う。`project-setup` ①表の
  .NET10 行に「実用性なし ※」を付し、①注記に理由を明記。**`opentouryo-transmission` の
  「リモート呼び出しは net48 専用」節にも、サンプル/ランタイム選択への含意（core 版 WSClient は起点として
  勧めない・実用は net48）を1段落追記**（transmission は core のリモート不可＝`BinarySerialize` ドロップを既収録）
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
- **名前空間と依存関係（作者提供 → 実装で検証）。** フレームワークは3つのアセンブリに分かれる：
  `Touryo.Infrastructure.Business`（親クラス2・**纏め者が開発**）→ `.Framework`（親クラス1・
  **NuGet**）→ `.Public`（汎用基盤部品・**NuGet**）。**参照は一方向**（実装で確認：`Framework` は
  `Business` を、`Public` は両方を `using` していない＝0件。逆は多数）。間飛ばし（`Business` →
  `Public`）はOK、逆向きは循環参照。作者提供テキストの `Touryo.Infrastructure.Business.Framework`
  等は表記の乱れで、実体は `.Framework` / `.Public`（grep で確認）。`AGENTS.md` の
  「クラスの階層と修正可否」表に名前空間・提供（NuGet/纏め者）列を統合
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
扱ってしまうため。ここに記録だけ残す。

**下記のアクセスログの件は、作者確認で「移植漏れの可能性が高く、今後修正するかもしれない」
との回答を得た（2026-07-17）。→ スキルには書かない方針で確定。** 修正待ちの本体課題であり、
「Core はログが粗い」と書くと、修正後に陳腐化し、かつバグを仕様として教えることになる。
**本体 Issue [#509](https://github.com/OpenTouryoProject/OpenTouryo/issues/509) を起票済み（2026-07-17）。**

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

**分類が肝。** 「このリポジトリで埋められる（＝OpenTouryo 共通の事実）」のか
「導入プロジェクトにしか決められない（＝プロジェクト固有の値）」のかで、扱いが正反対になる。
後者は**空欄のまま配布するのが正しい**。

### 5.1 このリポジトリで埋められる

**残っていない。** 以下はすべて完了した。

#### 完了済み（再調査しないこと）

- [x] **`AGENTS.md` のアーキテクチャ節**（各層の責務・基底クラス・層間の呼び出し規約）。
      5.2 に「導入プロジェクトが埋める欄」として分類していたが**誤りだった**。
      層の責務も呼び出し経路も OpenTouryo 共通の事実で、プロジェクトごとに変わらない
- [x] **`opentouryo-layer-b` と 2CS 系（`MyFcBaseLogic2CS`）の差の整理。**
      **未確認としていた3点は、すべて「同じ」だと実装で確認した**
      （UOC のシグネチャ / `this.ReturnValue` / 自動振り分け。`MyFcBaseLogic2CS` も
      `Latebind.InvokeMethod(this, "UOC_" + MethodName, ...)`、`WasCalledFromDoBusinessLogic`
      による直呼びガードも同じ）。
      **そして、この結論は既に `-winforms` に表として書かれていた**（この TODO 自体が陳腐化していた）。
      layer-b には**差分だけ**を足した（非同期版が無い / キー付き Dam が無い）。
      詳細は 4.3 の表を参照
- [x] **非推奨クラス一覧の網羅範囲。** **一覧は言語非依存で、VB を採取し直す必要は無い**と判明。
      VB には Framework（親クラス1）が無く CS のアセンブリを流用する
      （`VB/1_GetLibrariesFromCS.bat`）。VB の Business（親クラス2）は CS のミラーで、
      `MyBaseLogic` / `MyBaseLogic2CS` に同じく `<Obsolete>` が付く（実物で確認）。
      `Tools` 配下に `[Obsolete]` は無い。根拠は `AGENTS.md` の当該節の HTML コメントに記録
- [x] **P層の3分割**（`-mvc` / `-webforms` / `-winforms`）。
      `opentouryo-layer-p` は削除。WPF は P層フレームワークを持たないため対象外
- [x] **`opentouryo-auth` の「P層フレームワークごとの差異」節を P層スキルへ分配。**
      目安超過は解消（5,800 → 約4,100トークン）
- [x] **リッチクライアント（`-winforms`）の認証の扱い。**
      `UserInfoHandle` もセッションも使わず `static` な `MyBaseControllerWin.UserInfo` で保持。
      .NET の認証機構も使わない
- [x] **2CS で「業務例外時のロールバックを自動にしない」設計意図**（4.4 参照）。
      「アプリ = 1トランザクション」という設計の帰結だった
- [x] **リッチクライアントで有効な接頭辞の全一覧と既定値。**
      **6種のみ**（`btn` / `cbb` / `lbx` / `rbn` / `pbx` / `cbx`）。`-winforms` に記述済み
- [x] **ログアウト時のユーザ情報の破棄。** `DeleteUserInformation()` を `Logout` が呼ばないのは
      サンプルの漏れではなく設計。**ログイン画面に入る時点で `FxSessionAbandon()` を呼び、
      セッションごと消す**。`-auth` に記述済み
- [x] **外部 IdP 連携。** `opentouryo-oauth2-client` として独立させた
- [x] `opentouryo-config`: XML定義ファイルの中身の書き方。`opentouryo-xml-definition` として
      独立させた後、機能単位の5スキルへ解体（2.5 参照）

### 5.2 導入プロジェクトにしか決められない（空欄のまま配布する）

**このリポジトリ側では埋めきれない。** 埋めるのはアセットを導入する側。

**スキル内の TODO は全滅した（0件）。** すべて `opentouryo-project-policy`（纏め者への確認）
へ寄せたため。残るのは `AGENTS.md` の欄だけ。

#### 「纏め者の領分」は TODO にしない（2026-07-16・作者の指摘）

**当初ここに4件あった。まず3件が削除された。** 作者の指摘：

> `opentouryo-auth:62`、`opentouryo-logging:62`、`opentouryo-message:102` は
> 全てベースクラス２依存で使用者側のスキルは意識しなくて良い

| 削除した TODO | なぜ不要か |
| --- | --- |
| `auth`: `MyUserInfo` の追加項目 | 項目を足すのは親クラス2 を整備する側。使用者は**あるものを使うだけ** |
| `logging`: `OPERATION` の書式 | 標準を決めるとしたら纏め者。そもそもフレームワークが出力しないので**決まりが無いのが答え** |
| `message`: `%1`/`%2` の置換 | 置換するのは親クラス2。使用者は `GetMessage` / 例外スローを書くだけ |

**教訓：「親クラス2 に依存して決まること」＝「使用者側スキルの TODO」ではない。**
親クラス2 はバイナリで提供され、使用者は**その挙動に合わせるだけ**。
アセットの読者は使用者であって纏め者ではないので、纏め者の判断事項を欄として置くと、
永遠に埋まらない TODO になる。

**削除して終わりにはせず、「確認せよ」という指示に置き換えた。**
決めさせるのではなく、現物に**合わせさせる**。

#### 確認方法は「既存コードからの推測」ではない（作者の指摘）

当初は「既存の `MSGDefinition.xml` とスロー箇所を見て確認する」と書いたが、**これは誤り。**
作者から示された確認方法：

> ベースクラス２を読むこと、若しくは、提供されていればコードから読み取るか、
> 纏め者に確認しプロンプトで指示する。

つまり **① ソースが参照できるなら読む → ② 読めないなら纏め者に確認し、人がプロンプトで指示する**。
既存コードでの使われ方は手掛かりに過ぎず、**「使われていない」は「できない」の根拠にならない**
（既存エントリに `%1` が無いだけかもしれない）。

**あわせて「親クラス1・2 は必ずバイナリ」という認識も誤りだった。**
「提供されていればコードから読み取る」＝**ソースが提供されることもある**。
バイナリ提供は原則であって絶対ではない。`AGENTS.md` の「ソースが無いため修正できず」という
断定を改め、**修正不可の根拠を「整備するのは纏め者だから」という役割分担に寄せた**
（ソースが読めても修正してよいことにはならない）。

この確認方法は `message` 固有ではなく**親クラス2 依存の事項すべてに効く一般則**なので、
当初 `AGENTS.md` に置いたが、**後に `opentouryo-project-policy` として独立させた**（下記）。

#### `opentouryo-project-policy` の追加（2026-07-16・作者の提案）

> プロジェクト方針を確認するというスキルを作成するのはどうでしょうか？
> 「…Frameworks/Infrastructure/Business」のようなものが提供されればコードから確認でき、
> 提供されなければまとめ者向けのQ&Aにする。

**上記の「確認せよ」には穴があった。** `AGENTS.md` に「読めなければ纏め者に確認する」とは
書いたが、**何を・どこを見て・見られなければ誰に何を聞くのかがどこにも無く**、実質
「詰まったら人に聞け」で終わっていた。スキル化して手順を与えた。

内容：① 親クラス2 のソースを探す（**パスではなくファイル名で**。配置はプロジェクトによる）
→ ② 確認地図（事項 → ファイル → 見どころ。全て実装で裏取り済み）
→ ③ 読めなければ**纏め者への質問テンプレート**（既定値を示して差分だけ聞く形にした）。

`AGENTS.md` 側は「親クラス2 の挙動はプロジェクトごとに違う。推測で書かない。
確認方法は `opentouryo-project-policy`」まで削り、入口だけを残した。

#### 残った `logging` の2件も纏め者だった（作者の指摘）

> `opentouryo-logging:62`、`opentouryo-logging:154` の対応は同じで纏め者に聞くことです。

**`logging` の2件（`OPERATION` の書式 / イベントログの使いどころ）を、
「業務コードが直接呼ぶから使用者側のポリシー」と判断したが誤りだった。**
呼ぶのが業務コードでも、**書式や使いどころという「決めごと」は纏め者の領分**。

**「誰が呼ぶか」ではなく「誰が決めるか」で分ける。** ここを取り違えていた。

この2件で `opentouryo-project-policy` に**構造上の穴**が見つかった。当初の地図は
「親クラス2 のコードで確認できる」ものだけを前提にしていたが、この2件は
**フレームワークが出力も定義もしないので、読む対象が存在しない**。
そこでプロジェクト依存の事項を2分類した。

| 分類 | 確認方法 |
| --- | --- |
| **A. 親クラス2 の実装が決める** | ① ソースを探す → ② 地図で読む → 無ければ ③ 聞く |
| **B. 運用ルール**（`OPERATION` の書式、イベントログの使いどころ） | **③ へ直行**（読む対象が無い） |

**「決まりが無い」＝「自分で決めてよい」ではない**をアンチパターンに明記した。
`OPERATION` の書式について当初「決まりが無いこと自体が答え」と書いていたが、
これは**こちらが知らないだけ**だった。

`src/instructions/AGENTS.md` の TODO：

- [ ] OpenTouryo 本体のバージョン、IDE
- [ ] ディレクトリ構成、命名規約
- [ ] 実装時の必須ルール（2件記述済み：親クラス1・2 を修正しない / 業務例外はリスローされない）
- [ ] ビルドと実行のコマンド
- [ ] プロジェクト ポリシーのその他の項目（Git 操作の1件は既定で記述済み）

### 5.3 方針が決まったら起こす

- [ ] `opentouryo-oauth2-client`: **SAML2 クライアント機能**（`SAML2Client` / `SAML2Bindings`）。
      作者から「現時点でスキル化する必要はない」と明示されている。連携する方針になったら別スキルへ
- [ ] `opentouryo-oauth2-client`: 認可コードグラント以外のグラント
      （`ClientCredentialsGrantAsync` / PKCE / CIBA ほか。存在は本文に列挙済み）
- [ ] **D層自動生成ツール（墨壺）の CLI 化待ち**（作者が CLI 化を予定。2.7 参照。
      本体 Issue [#508](https://github.com/OpenTouryoProject/OpenTouryo/issues/508) 起票済み・2026-07-17）。
      CLI ができたら `opentouryo-dao-generated` に「生成の呼び出し方」を追記できる。
      現状スキルは「生成物の使い方」だけを扱う（生成そのものはツール前提）

### 5.4 作者に確認したいこと

**推測のままスキルに書けない事項。** 確認が取れたら、スキルに反映するか判断する。

- [x] **Core MVC のアクセスログ出力点が net48 より少ないのは意図的か、移植漏れか**（4.5 参照）。
      **解決（2026-07-17）：作者回答「移植漏れの可能性が高く、今後修正するかもしれない」。**
      → スキルには書かない（本体の修正待ち課題。仕様ではない）。本体 Issue
      [#509](https://github.com/OpenTouryoProject/OpenTouryo/issues/509) 起票済み。この項目に残作業は無い

---

## 6. 作業環境

### 6.1 参照元（すべて `.gitignore` 済み）

**2026-07-20：アセット repo 内の `files/`（本体ソースミラー）は削除。** 以降の裏取りは下記の**実クローン2箇所**を正とする（作者指示）。
旧 `files/csharp/…` パスは下表の実体に読み替える。

| 参照ルート | 中身 | 備考 |
| --- | --- | --- |
| `C:\otr\OpenTouryo-03-20\root\programs\CS\` | OpenTouryo 本体の C# 実ソース（タグ 03-20 クローン） | 旧 `files/csharp/` の置換。旧ミラーより rich＝`Build_net48\`/`Build_netcore100\` 出力や `BusinessRichClient_net48.sln` 等の .sln も実在 |
| `D:\git\local\OpenTouryoProject\OpenTouryoDocuments\documents\` | ドキュメント（`0_Introduction`/`1_User_Guide`/`2_Tutorial`/`document_map.xlsx`） | 旧版は 2016年版で古い（4.1参照） |

**アセットの記述は上記実ソースを正とする。** 推定で書かず、まず grep/ls して実物で確認する。

主要な参照先（`CS` = `C:\otr\OpenTouryo-03-20\root\programs\CS`）：

```
CS\Frameworks\Infrastructure\Framework\      フレームワーク（親クラス1・触らない層）
CS\Frameworks\Infrastructure\Business\       業務フレームワーク（親クラス2・纏め者がカスタマイズ）
CS\Frameworks\Infrastructure\Public\         基盤部品（Db / Log / Util / Str …）
CS\Frameworks\Infrastructure\ServiceInterface\{ASPNETWebService,WCFService}   3層CS の WS ホスト源
CS\Samples4NetCore\Backend\MVC_Sample\       .NET 10.0 系の実例（最重要）
CS\Samples\                                  net48 系の実例（2CS_sample / Bat_sample / CLI_sample / WS_sample / WebApp_sample）
```

※ 設定/ログスキル中の `C:\root\files\resource\…` は**実行時インストールパス**でソースとは無関係（今回の削除と混同しない）。

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

**このリポジトリ側の作業は残っていない。** 全34スキル、`AGENTS.md`（アーキテクチャ節を含む）、
インストーラまで書き終えた。利用ガイド（doc 0〜8・動的クエリ・D層自動生成・設定一覧）も
一通り確認し、整合性の補正と新規スキル（dialog / p-call-business / richclient-async /
common-parts / project-policy ほか）への反映を済ませた。

残る TODO は**導入プロジェクトか作者にしか決められない**（5.2 / 5.3 / 5.4）。
特に 5.2 は**空欄のまま配布するのが正しい**ので、埋めようとしないこと。

再開する場合、着手する前に：

1. **5.1 の「完了済み」を読む。** TODO が陳腐化していた事例が複数ある。
   2CS の差（5.1）は `-winforms` と 4.3 に答えが書いてあるのに TODO が残っていた。
   **書いた本人が忘れるので、まず現物を検索してから調査を始めること**
2. **`opentouryo-auth` は 約4,950トークンで上限に接している**（3 参照）。
   加筆が必要になったら分割とセットで考える
3. **ランタイム差（net48 / .NET 10.0）に注意。** Web Forms とリモート呼び出し（通信制御
   `protocol="2"`）・`Zipper` / `BinarySerialize` / `Win32` は net48 専用（4.3 参照）

作者確認待ちの事項（5.4）は解決済み。現時点で保留中の確認事項は無い。
