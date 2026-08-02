# トランザクション・テーブル・テスト

## ケース1：WebForms_Sample
WebForms_Sample に opentouryo-* スキルを使用して、以下の基本的な処理を実装する。

## ケース2：MVC_Sample
MVC_Sample に opentouryo-* スキルを使用して、以下の基本的な処理を実装する。

## ケース3：MVC_Sample_Core
MVC_Sample_Core に opentouryo-* スキルを使用して、以下の基本的な処理を実装する。

## ケース4：...
...

## フレームワーク別の実装方式

### WebForms
- フッタのボタン実装は、
  - Master Page（`.master`）にレイアウトを配置する。
  - 画面ごとのボタン制御（表示/非表示やテキスト設定）は、各ページの コードビハインド（基本は初期処理）で動的に行う。

- ダイアログ表示には、基本的にOpen棟梁のフレームワーク機能を使用する。

### MVC
- フッタのボタン実装は、
  - `_Layout.cshtml` に共通レイアウトを配置する。
  - 画面ごとのボタン配置や差し替えは、`@RenderSection` を使用して動的に切替・定義する。

- ダイアログ表示には、基本的にJavaScript機能を使用する。

## 基本的な処理の内容
