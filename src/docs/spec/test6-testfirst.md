# 基本的な処理の内容
受注一覧画面の検索を、**テスト先行**（`TESTING.md`）で実装する。いきなり実装しない。

## 仕様の出どころ（段 0 で読む）
NorthwindDbSampleSpec（<https://github.com/OpenTouryoProject/NorthwindDbSampleSpec>）の受注管理。

- イベント仕様書：`LLD/EventSpec/Orders.md` の **`EV-ORD-101`（ページ読み込み）・`EV-ORD-102`（受注の検索）**、同じ文書の「共通の処理」（受注検索クエリ・状況の判定）
- 画面定義書：`LLD/UI_ElementsAndEventList/Orders.md` の **`SC-ORD-01`**（`SC-ORD-01-I01`〜`I08`、`I06` の列）
- テーブル定義書：`LLD/TableSchema/Orders.md` の業務ルール（**`ORD-T2`・`ORD-T7`** など）
- 共通仕様：`HLD/Common.md` の `PRE-*`・`VAL-*`・`ERR-*`

## 作るもの
- B層：受注の検索（`EV-ORD-102` の抽出条件・並べ替え・ページ 20 件・総件数・状況の判定）を、**新しい業務コードクラス**に書く（D層は CmnDao）。
- 画面：`SC-ORD-01` の検索条件と一覧（`EV-ORD-101`・`EV-ORD-102` の範囲）。詳細への遷移・新規登録・出荷更新（`EV-ORD-106`〜`108`）は作らない。
- テスト：B層のルート メソッドの単体テスト（スキル `opentouryo-test-layer-b`）。

## 名前（固定）
ProgramID は **`OrdTf`**（テスト先行。トランザクション2 の `Ord` と衝突させない）。

| 対象 | 名前 |
| --- | --- |
| 業務コードクラス | `OrdTfBusiness`（`MyFcBaseLogic` を継承） |
| B層のルート メソッド | `MethodName` = `OrdTfSearch`（`UOC_OrdTfSearch`） |
| 引数クラス・戻り値クラス | `OrdTfParameterValue`・`OrdTfReturnValue` |
| テスト仕様 | `docs/spec/test6-testfirst-<フレームワーク>-tests.md`（例 `test6-testfirst-mvc-tests.md`） |
| テストのプロジェクト・クラス | `<Webプロジェクト名>.Tests`・`OrdTfBusinessTests` |

## 決まり
- テストケースの根拠の ID は、上の仕様の ID（`EV-ORD-*`・`ORD-T*`・`VAL-*`・`ERR-*`）。**仕様に無い期待値は書かない**（漏れは人に返す）。
- テストのデータは、テストが自分で入れて消す（テスト用の顧客を作り、その顧客の受注だけで確かめる）。Northwind の元の行は書き換えない。
- 入力の検証（`VAL-DATE` の「開始 <= 終了」）を B層と画面のどちらで行うかは、テスト仕様に書いて人の承認を受ける。

# 続き：選択肢の構築（2 回目）
受注一覧の検索（1 回目）を Green まで通した後に、**検索条件の顧客・担当者の選択肢**を同じ手順（テスト先行）で足す。

## 仕様の出どころ（段 0 で読む）
- イベント仕様書：`EV-ORD-101` の処理内容 1・2、「共通の処理」の **選択肢の構築**
- 画面定義書：`SC-ORD-01-I01`（顧客）・`I02`（担当者）・`I05`（出荷状況）の種類・値／表示・備考

## 作るもの
- B層：顧客・担当者の選択肢の取得を、1 回目と同じ業務コードクラスに **別の `MethodName`** で書く。
- 画面：`I01`・`I02` をドロップダウンにする。ページ読み込み（`EV-ORD-101`）で選択肢を取得してから、1 回目の検索で既定条件の一覧を出す。
- テスト：1 回目と同じテストのクラスに足す（`opentouryo-test-layer-b`：B層のクラスごとに 1 つのテスト クラス）。

## 名前（固定）

| 対象 | 名前 |
| --- | --- |
| B層のルート メソッド | `MethodName` = `OrdTfInit`（`UOC_OrdTfInit`） |
| 引数クラス・戻り値クラス | 1 回目の `OrdTfParameterValue`・`OrdTfReturnValue` に項目を足す |
| テスト仕様 | 1 回目のテスト仕様に節を足す（先頭の仕様の版は、2 回目に読んだ版に合わせて書き直し、1 回目の版も残す） |

## 決まり
- 1 回目の決まりに従う。**1 回目のテスト（`OrdTfSearch`）は変えない。**
- 先頭の空白の選択肢（＝すべて）を B層と画面のどちらで置くかは、テスト仕様に書いて人の承認を受ける。
- 出荷状況（`I05`）の選択肢は固定値（DB を使わない）。B層のテストの対象にするかも、テスト仕様に書いて承認を受ける。
