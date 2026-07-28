---
name: opentouryo-app-design
description: "OpenTouryo でアプリを設計するとき（spec→plan の設計段）に「何を決めるか」の地図・チェックリスト。レイヤ分割（P/B/D の責務と呼び出し経路）、例外・エラー方式（業務例外/システム例外/閉塞・メッセージ）、トランザクション境界（B層）、データアクセス方式（Dao 3系統の選択・SQL定義・楽観排他・明細一括）、共有情報と設定、画面設計（マスタ/ボタン共通化・一覧・入力チェック・遷移・ダイアログ）、セッション/セキュリティ、認証・認可（Forms/OAuth2/OIDC/JWT）、ログ、国際化、非同期/呼出方式、コメント規約を、実装スキルへ割り付ける。処理方式（画面/バッチ/非同期/組込/ワークフロー）の選択も扱う。各実装の詳細は個別スキルを使う。アプリケーション設計 / 設計のポイント / 設計方針 / どう設計するか / 設計チェックリスト を伴う作業のときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# アプリケーション設計のポイント（設計フェーズの地図・チェックリスト）

> このスキルは**設計段（spec→plan）で「何を決めるか」の地図**。実装の詳細は各スキルにある。
> `AGENTS.md` の「開発の進め方（spec→plan→実装）」に沿い、`docs/spec` / `docs/plan` を書くときの**漏れ防止**に使う。
> 📋 **設計 references**（`references/`・個別課題ごとに追加）：`timeout-values.md`（各種タイムアウト値の設計）／`file-upload-download.md`（ファイルのアップロード・ダウンロード）／`cache-control.md`（キャッシュ制御）／`illegal-operation-prevention.md`（不正操作防止＝二重送信/戻る再送/リロード）／`list-paging.md`（一覧ページ制御方式）／`state-management.md`（ASP.NET 状態管理方式）。

## 使いどころ

新機能・新画面の設計時に、OpenTouryo が前提とする**設計上の決定事項**を漏れなく押さえるためのチェックリスト。
**各項目の実装ルールは割り付け先スキルにある**（このスキルは判断の地図であって、ここで実装を始めない）。

## まず処理方式を決める

**画面（Web Forms / MVC / WinForms）／バッチ／非同期／組込／ワークフロー** のどれか。**P層の実装モデルが根本的に変わる**（`AGENTS.md` アーキテクチャ）。
起点サンプルの選択と立ち上げは `opentouryo-project-setup`。

## 設計チェックリスト（決めること → 割り付け先スキル）

| 設計事項 | 決めること | 割り付け先 |
| --- | --- | --- |
| レイヤ分割 | P/B/D の責務境界・呼び出し経路（P→B は論理名、B→D は `GetDam()` 渡し。**P→D 直呼び禁止**） | `AGENTS.md`・`opentouryo-layer-b`/`-d`/`-p-*`/`-p-call-business` |
| 例外・エラー | 業務例外（やり直し可）／システム例外（不可）／閉塞の切り分け、メッセージ採番 | `opentouryo-exception`・`opentouryo-message` |
| トランザクション | 境界は **B層**。TC パターン・分離レベル・複数 DB | `opentouryo-transaction-control`・`opentouryo-layer-b` |
| データアクセス | Dao 3系統の選択、SQL 定義（静的/動的）、楽観排他（ts 有無）、明細一括更新、複数行 DML の順序 | `opentouryo-layer-d`・`opentouryo-dao-*`・`opentouryo-query-definition`・`opentouryo-batch-update` |
| 一覧ページ制御 | 最大表示/取得件数、ページ制御方式（アプリ/ストアド/**SQL＝`ROW_NUMBER`/`TOP`/`ROWNUM`**）、大量データは SQL でページング（UI ページャと役割分担） | **`references/list-paging.md`**（本スキル）＋`opentouryo-query-definition`・`opentouryo-layer-d`・`opentouryo-layer-p-webforms-event` |
| 共有情報・設定・状態管理 | 持ち回り（**状態のスコープ・寿命で方式選択**：ViewState/Hidden/Cookie/Session/Cache…）、共有情報（定数）、外部パラメタ／接続文字列／パス。**★ ViewState・Server.Transfer は Web Forms 専用** | **`references/state-management.md`**（本スキル）＋`opentouryo-shared-property`・`opentouryo-config`・`opentouryo-layer-p-winforms-event`・`opentouryo-webforms-dialog` |
| 画面設計 | マスタ／フッタ ボタン共通化、一覧（グリッド）、入力チェック、画面遷移、ダイアログ | `opentouryo-base2-customize`・`opentouryo-layer-p-webforms-screen`/`-event`・`opentouryo-screen-transition`・`opentouryo-webforms-dialog` |
| ファイル入出力 | アップロード/ダウンロードの制限・保存先・**セキュリティ**（拡張子＋中身検証・パストラバーサル・認可）・日本語ファイル名 | **`references/file-upload-download.md`**（本スキル）＋`opentouryo-layer-p-webforms-event`/`-mvc`・`opentouryo-config`・`opentouryo-auth` |
| キャッシュ制御 | 動的/認証画面は**キャッシュ無効**（`FxCacheControl=on`。**Web Forms・MVC 両対応**）、静的は積極キャッシュ、参照データは Memory/Distributed | **`references/cache-control.md`**（本スキル）＋`opentouryo-config`・`opentouryo-screen-transition` |
| セッション/セキュリティ | タイムアウト検出、二重送信／不正操作防止（Request Ticket・戻る再送/リロード/キャッシュ参照）のスイッチ、**キャッシュ制御と三点セット**。**★ これらは Web Forms 専用（MVC には無い）** | **`references/illegal-operation-prevention.md`**（本スキル）＋`opentouryo-auth`・`opentouryo-config`・`opentouryo-screen-transition` |
| タイムアウト設計 | 各種タイムアウトを**呼び出し元（外側）ほど長く**整合（HTTP／`executionTimeout`／DB／ロック／セッション） | **`references/timeout-values.md`**（本スキル）＋`opentouryo-config`・`opentouryo-auth` |
| 認証・認可 | Forms（net48）／Cookie（core）、外部 IdP（OAuth2/OIDC/JWT） | `opentouryo-auth`・`opentouryo-oauth2-client` |
| ログ | 出力（log4net/NLog）・ロガー名、分析（性能/エラー） | `opentouryo-logging`・`opentouryo-log-analysis` |
| 国際化・文字コード | メッセージの多言語、エンコード | `opentouryo-message`・`opentouryo-config` |
| 呼出/非同期 | インプロセス⇄WS（net48 のみリモート）、非同期呼出 | `opentouryo-transmission`・`opentouryo-richclient-async`・`opentouryo-p-call-business` |
| コーディング規約 | ファイルヘッダ・UOC 節区切り | `opentouryo-comment-convention` |

## まだ専用スキルが無い設計領域（このスキルの配下として順次整備）

フレームワークにあるが**実装スキル未整備**（作者が個別課題を提示 → 子スキル／`references`／`snippets` で追加）：

- **出力層**：帳票出力・印刷・メール送信
- **バッチ処理方式**（`RerunnableBatch` 等。立ち上げのみ `opentouryo-project-setup`）
- **WebAPI 設計**（RESTful・非同期 API）
- **性能設計／高信頼性設計**（性能の「分析側」は `opentouryo-log-analysis`）
- **組込系／ヒューマン・ワークフロー／モバイルバックエンド**

出典：公式「アプリケーション設計のポイント」（設計トピックの目次）。**各領域の実装規則は該当サブページを取得して裏取りの上で整備**する。

## やってはいけないこと

- **このスキルで実装を始める** — ここは設計の地図。実装ルールは割り付け先スキルにある。
- **処理方式を決めずに実装に入る** — P層モデル（Web Forms/MVC/WinForms/バッチ…）で書き方が根本的に違う。
- **未整備領域を推測で実装する** — 該当サブページを裏取りしてから（`opentouryo-project-policy` の姿勢）。
