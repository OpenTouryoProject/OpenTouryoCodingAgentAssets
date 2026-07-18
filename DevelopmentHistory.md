# 開発経緯

作業を再開するための記録。**アセットの内容ではなく、アセットを作る側の記録。**
配布されるのは `src/` 配下のみで、このファイルは配布されない。

最終更新: 2026-07-18（全33スキル。利用ガイド doc 0〜8・設定一覧まで確認し、整合性補正と
新規スキル追加、ランタイム差（net48 / .NET 10.0）の反映を実施。project-setup を実走フィードバックで
補正し、③基盤ビルドを project-setup-build へ分離、変形の後工程 project-transform も分離）

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
opentouryo-layer-p-mvc            実効300L tok~3710  完了
opentouryo-layer-p-webforms-screen 実効144L tok~1904  完了（画面の新規作成）
opentouryo-layer-p-webforms-event  実効174L tok~2935  完了（イベント実装）
opentouryo-webforms-dialog         実効165L tok~2193  完了（子画面表示・ダイアログ）
opentouryo-layer-p-winforms-screen 実効116L tok~1812  完了（画面の新規作成）
opentouryo-layer-p-winforms-event  実効104L tok~1877  完了（イベント実装）
opentouryo-p-call-business        実効163L tok~2307  完了（P層→B層呼出し・横断）
opentouryo-richclient-async       実効145L tok~2031  完了（リッチクライアントの非同期呼び出し）
opentouryo-common-parts           実効118L tok~2047  完了（用途→共通部品のインデックス）
opentouryo-project-setup          実効 64L tok~1490  完了（**ファサード**。全体の流れ＝4スキルの呼び出し順のみ／完了後（→transform）・コミット促し／全工程共通の禁止事項。手順は下の4スキルへ委譲）
opentouryo-project-setup-selection 実効 73L tok~1785  完了（①②。起点サンプル選択〔全系列を必ず提示・間引かない〕＋取得元 <ref>〔固定タグ番号はユーザ確認・develop〕。WS依存列は csproj 確定値。次は build/core）
opentouryo-project-setup-build    実効148L tok~3659  完了（③。ZIP取得→ランタイム別バッチ→ベンダ。footgun＋偽の成功＋MAX_PATH短ルート＋PowerShell 既定推奨。短ルート展開ツリーをワークスペース化〔コピーバック廃止〕。Nuget_RichClient は Framework.RichClient まで＝Business.RichClient は別 sln）
                                  └ examples.md 162L         実機で通した as-built スクリプト2本（on-demand。setup-build.ps1 / build-app.ps1。雛形）。任意ブロック：setup-build に base2 overlay 適用〔Copy-Item・BOM 保持〕＋2CS の BusinessRichClient_net48.sln ビルド、build-app に開発支援ツール〔DaoGen/DPQuery〕ビルド〔PackageReference restore で Microsoft.Data.SqlClient 欠落を炙り出し〕
opentouryo-project-setup-core     実効 61L tok~1308  完了（④⑤＝核心。取り出し〔+開発支援ツール〕・HintPath 張替・3層/WS の CS0246 解消〔(A)残す/(B)切離し〕。references/samples を保持）
                                  ├ references/reference-rewrite.md 39L         ⑤の edge case（接頭辞だけでない・Build_* 全 DLL＝MySql/Oracle 非復元・MAX_PATH フラット化・net48 も PackageReference 併用時は restore）
                                  ├ samples/webservices.md 56L tok~1200  WS/3層の共通機構（サンプル横断で共有）：(A)そのまま残す/参照/Build\配置・(B)WS切り離し・core 実用不可・MAX_PATH
                                  ├ samples/webforms.md    38L tok~700   Web Forms 固有（cc 画面の CS0246・(B)画面差し替え・config二段・test*マスタ固有名）。共通は samples/webservices.md
                                  ├ samples/daogentool.md  ~45L         開発支援ツール DaoGen_Tool（墨壺＝D層自動生成。Frameworks\Tools 配下・HintPath＋PackageReference 混在＝net48 も restore 要・Microsoft.Data.SqlClient）→ dao-generated
                                  └ samples/dpquerytool.md ~45L         開発支援ツール DPQuery_Tool（動的クエリ試験＝PARAM タグ。取り出し/張替は daogentool.md と同じ）→ query-definition
opentouryo-project-setup-config   実効 76L tok~1637  完了（⑥⑦。resource 移設・config パス張替〔%OT_RESOURCE_ROOT%〕・.gitignore・接続文字列/InitConfiguration/nuget restore/sessionState=StateServer・ビルド/実行検証。references を保持）
                                  ├ references/resource-config.md   46L tok~900  ⑥の詳細（相対不可＝ResourceLoader・%VAR%展開／FxContainerization と別・パスキー一覧・綴りの罠・config二段）
                                  └ references/run-verify.md        ~30L         ⑦の実行確認（IIS Express：HTTP で SSL 回避・OT_RESOURCE_ROOT の渡し方・Ping/login スモーク・500＝resource/config 失敗）
                                  └ examples.md 162L         実機で通した as-built スクリプト2本（on-demand。setup-build.ps1 / build-app.ps1。雛形）。任意ブロック：setup-build に base2 overlay 適用〔Copy-Item・BOM 保持〕＋2CS の BusinessRichClient_net48.sln ビルド、build-app に開発支援ツール〔DaoGen/DPQuery〕ビルド〔PackageReference restore で Microsoft.Data.SqlClient 欠落を炙り出し〕
opentouryo-project-transform      実効106L tok~2100  完了（セットアップ後の変形＝2層化・サンプル整理・CS0246 解消。実機E2E反映：改行LF/非対話PSガード・2層化のDB DLL付替・test*マスタ警告・csproj剪定手法。実行は任意）
opentouryo-layer-b               実効292L tok~4134  完了
opentouryo-layer-d             実効149L tok~2216  完了（Dao 3系統の使い分け・入口）
opentouryo-dao-custom          実効151L tok~2015  完了
opentouryo-dao-common          実効128L tok~1775  完了
opentouryo-dao-generated       実効144L tok~1885  完了
opentouryo-query-definition    実効278L tok~2895  完了
opentouryo-message             実効127L tok~1585  完了
opentouryo-shared-property     実効 73L tok~ 779  完了
opentouryo-screen-transition   実効116L tok~1473  完了
opentouryo-transaction-control 実効125L tok~1651  完了
opentouryo-transmission        実効120L tok~1572  完了
opentouryo-exception           実効289L tok~4264  完了
opentouryo-logging             実効166L tok~2114  完了
opentouryo-config              実効195L tok~2631  完了
opentouryo-auth                実効309L tok~4953  完了 ★上限に貼り付いている
opentouryo-oauth2-client       実効263L tok~2851  完了
opentouryo-project-policy      実効156L tok~2675  完了（親クラス2 の挙動・運用ルールの確認手順＝読む側）
opentouryo-base2-customize     実効145L tok~3735  完了（親クラス2 のカスタマイズ＝纏め者向け・作る側。オーバーレイ+固定タグ。短ルート展開ツリーをワークスペース化。★2CS=Business.RichClient は別 sln〔BusinessRichClient_*.sln〕要ビルド／overlay 適用は Copy-Item＋UTF-8 BOM 保持／overlay はファイル丸ごと差替＝パッチでない）
```

**全30スキルの本文を書き終えた。** 全て標準準拠、目安（500行 / 5000トークン）内。
「実効」は HTML コメント除去後（Claude Code ではコメントが除去されるため）。
計測は `scratchpad/measure.py` 相当のスクリプトで行う（見積り式：ASCII 1/4字 + 非ASCII 1/1.1字）。

**`opentouryo-auth` は 約4,950トークンで上限 5,000 に接している。**
これ以上の加筆は分割とセットで考えること。外部 IdP 連携を `opentouryo-oauth2-client` として
独立させたのもこれが一因（2.5 参照）。

相互リンクしている（B層 → D層 → クエリ定義、全層 → 例外、P層3種 → auth、
auth → oauth2-client、setup → config / project-policy、など）。
`AGENTS.md` は実効216行（圧縮後）。横断事実（DBMS 差・名前空間・ランタイム差・セットアップ）の
追記で一度229行まで膨らみ、冗長プロースを圧縮して戻した。目安200行はわずかに超えるが、
残りは27スキルの一覧表と非推奨リファレンス表が中心で、これ以上は load-bearing な情報を削ることになる。

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

**このリポジトリ側の作業は残っていない。** 全33スキル、`AGENTS.md`（アーキテクチャ節を含む）、
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
