# フレームワーク毎の共通仕様

## 画面共通
- すべての画面のメインボタンはフッタ部に5つ配置し、動的にボタンのキャプションを適切な名称に変更し、不要なボタンはdisableにする。

## WebForms
- フッタのボタン実装は、
  - Master Page（`.master`）にレイアウトを配置する。
  - 画面ごとのボタン制御（表示/非表示やテキスト設定）は、各ページの コードビハインド（基本は初期処理）で動的に行う。

- ダイアログ表示には、基本的にOpen棟梁のフレームワーク機能を使用する。
- 一覧表示は `GridView`（`DataSource` にバインド）を使用する。

## MVC
- フッタのボタン実装は、
  - `_Layout.cshtml` に共通レイアウトを配置する。
  - 画面ごとのボタン配置や差し替えは、`@RenderSection` を使用して動的に切替・定義する。

- ダイアログ表示には、基本的にJavaScript機能を使用する。
- 一覧表示は tableタグを自前で生成し、trタグをループで実装する。

## WindowsForms（2CSClientWin_sample / WSClientWin_sample）
- Form画面は OpenTouryo のリッチクライアント基底フォーム `MyBaseControllerWin`（画面コード親クラス２）を継承する。
- フッタのボタン実装は、
  - `MyBaseControllerWin` を継承したBaseFormに共通レイアウトとして実装する。各Form(画面）は、このBaseFormを継承する。
  - 画面ごとのボタン制御（表示/非表示やテキスト設定）は、各ページの コードビハインド（基本は初期処理）で動的に行う。

- ダイアログ表示には、標準の `MessageBox.Show`（OK は `MessageBoxButtons.OK`、YES/NO は `MessageBoxButtons.YesNo`）を使用する。
- 一覧表示は `DataGridView`（`DataSource` にバインド）を使用する。
