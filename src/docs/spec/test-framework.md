# フレームワーク毎の共通仕様

## 画面共通
- すべての画面のメインボタンはフッタ部に5つ配置し、動的にボタンのキャプションを適切な名称に変更し、不要なボタンはdisableにする。

## WebForms
- フッタのボタン実装は、
  - Master Page（`.master`）にレイアウトを配置する。
  - 画面ごとのボタン制御（表示/非表示やテキスト設定）は、各ページの コードビハインド（基本は初期処理）で動的に行う。

- ダイアログ表示には、基本的にOpen棟梁のフレームワーク機能を使用する。

## MVC
- フッタのボタン実装は、
  - `_Layout.cshtml` に共通レイアウトを配置する。
  - 画面ごとのボタン配置や差し替えは、`@RenderSection` を使用して動的に切替・定義する。

- ダイアログ表示には、基本的にJavaScript機能を使用する。

## WindowsForms（2CSClientWin_sample / WSClientWin_sample）
- 画面は OpenTouryo のリッチクライアント基底フォーム `MyBaseControllerWin`（画面コード親クラス２）を継承する。
- フッタのボタン実装は、
  - 共通レイアウト（フッタのボタン等の共通UI）は `MyBaseControllerWin` に実装する（WebForms の Master Page／MVC の `_Layout.cshtml` に相当。フッタ用の集約イベント機構を持つ）。
  - ただし `MyBaseControllerWin` への共通UI実装はベース２カスタマイズが必要になるので、**Formのコンストラクタなどに共通関数を使用して実装する**。
  - 画面ごとのボタン制御（キャプション変更や活性/非活性）は、各フォームのコードビハインド（基本は初期処理 `UOC_FormInit`）で動的に行う。
  - ボタンのクリックは、フレームワークがコントロールを検索して結線し、`UOC_○○_Click(RcFxEventArgs rcFxEventArgs)` の UOC メソッドで受ける（`rcFxEventArgs.ControlName` で発火元を判別）。
- ダイアログ表示には、標準の `MessageBox.Show`（OK は `MessageBoxButtons.OK`、YES/NO は `MessageBoxButtons.YesNo`）を使用する。
- 一覧表示は `DataGridView`（`DataSource` にバインド）を使用する。
