# ASP.NET の状態管理方式（設計・実装の基本）

`opentouryo-app-design` の設計事項の1つ。**on-demand 参照**。
出典：「ASP.NET の状態管理方式」（Microsoft 技術情報）＋実ソース／既存スキル。**どこに何を持たせるか**の地図。

> **★ ViewState と Server.Transfer＋HTTP Context は Web Forms 専用**（MVC には無い）。Session／Application／Cache はサーバ側技術で **ASP.NET 全般（Web Forms・MVC）で使える**。

## クライアント側（サーバ ステートレス）

| 方式 | 用途／スコープ・寿命 | 注意 | Web Forms 専用 |
| --- | --- | --- | --- |
| **ViewState** | Web コントロール状態の復元・ポストバックのイベント振り分け。`__VIEWSTATE` Hidden に Base64＋ハッシュ。同一画面・ポストバック単位 | HTML 肥大＝トラフィック増。既定で暗号化なし（`EnableViewState`／`EnableViewStateMac`／`ViewStateEncryptionMode`） | **★ 専用** |
| Hidden / Form / Query String | リクエスト単位で値を持ち回る。サーバ資源不要 | 改ざんリスク（サーバで検証） | 共通 |
| Cookie | SessionID・認証チケット・個人化。複数ページ | クライアント保持＝改ざん・容量 | 共通 |
| **Server.Transfer ＋ HTTP Context 領域** | サーバ処理内（単一リクエスト）で状態を持ち回る（`HttpContext.Items` 等） | 遷移をまたがない | **★ 専用** |

## サーバ側（サーバ ステートフル）

| 方式 | 用途／スコープ・寿命 | 注意 |
| --- | --- | --- |
| **Session** | ユーザ単位の状態・複数ページ。既定タイムアウト約20分 | 資源消費・拡張性。**負荷分散は StateServer/SQLServer**（直列化要）。容量＝1人分×同時ユーザ数 |
| **Application** | アプリ全体でユーザ横断共有（採番プール等） | 排他制御要・**負荷分散で共有不可** |
| **Cache** | キャッシング・マスタ保持。自動破棄（メモリ不足／期限／ファイル・依存変更） | 排他・**取得時 null チェック必須** |
| 静的変数 | アプリ全体のグローバル | 排他が難しい |

## 負荷分散（Web ファーム）

- **`machineKey` を全ノードで統一**する。ViewState・Session（暗号化）・Cookie 認証チケットの暗号化／検証がノード間で相互運用可能になる（`opentouryo-config`／`opentouryo-auth`）。

## OpenTouryo での対応（どれをどのスキルで）

| 持たせたいもの | OpenTouryo での置き場 | スキル |
| --- | --- | --- |
| フレームの隠しフィールド（`RequestTicketGuid`／`ScreenGuid`／`WindowGuid` 等） | マスタの Hidden。不正操作防止・画面遷移で使用 | `references/illegal-operation-prevention.md`・`opentouryo-layer-p-webforms-screen` |
| ユーザ単位の状態（Session） | **ブラウザ・ウィンドウ別／親画面別 Session 領域**（入れ子2層）・モーダル受け渡し | `opentouryo-webforms-dialog`・`opentouryo-config` |
| レスポンス／データのキャッシュ（Cache） | `FxCacheControl`（レスポンス無効化）／`FxSqlCacheSwitch`（SQL）／`IMemoryCache`・`IDistributedCache`（Core） | `references/cache-control.md` |
| アプリ共通の**定数**（Application 的な固定値） | **共有情報**（`SPDefinition.xml`＋`GetSharedProperty`）＝ユーザ状態でなく設定値 | `opentouryo-shared-property` |
| 認証チケット（Cookie）・`machineKey` | Forms 認証（net48）／Cookie 認証（Core） | `opentouryo-auth`・`opentouryo-config` |
| 複数ポストバックに跨る編集（`DataTable`） | Session 保持（StateServer/SQLServer なら直列化可能に） | `opentouryo-batch-update` |

## 設計時に決めること（チェック）

- その状態の**スコープと寿命**（1リクエスト／画面／ユーザ／アプリ）で方式を選ぶ。
- **MVC なら ViewState・Server.Transfer は使えない**（Hidden／TempData／Session 等で代替）。
- ユーザ状態を Session に置くなら**負荷分散（StateServer/SQLServer・直列化・`machineKey`）**を設計。
- Cache は **null チェック・破棄戦略（TTL）** を決める（`references/cache-control.md`）。
