---
name: opentouryo-mvc-crud-screens
description: "OpenTouryo の ASP.NET Core MVC（net10.0。net48 MVC も同型）でテーブル保守（マスタメンテ）の CRUD 画面を実装する。2方式＝(1) 一覧→詳細（行選択で詳細画面へ遷移し単一レコードの追加・更新・削除）、(2) 一覧＆更新（一覧でその場に複数行を追加・編集・削除＝RowState バッチ、［更新］でまとめて反映）。MVC 固有＝UOC 無しのアクションメソッド、`<form asp-action>`＋`@Html.AntiForgeryToken()`＋`[ValidateAntiForgeryToken]`、複数ボタンは formaction で送信先を分岐、フッタのメイン5ボタンは @section（＝<form> の外に出る）に置いて form=\"ID\" で紐付け、一覧は table を自前生成し tr をループ、各行に hidden の RowIndex＋input を出して List<行VM> にモデルバインド、ダイアログは JavaScript（window.confirm/alert）。複数リクエストに跨る編集中 DataTable の Session 保持は net48＝binary で直接・net10.0（Core）＝DTTables JSON。RowState バッチ（AddRow=Added・DeleteRow=dr.Delete()=Deleted・セル読み戻し=Modified・IDENTITY は負値仮採番・成功後 AcceptChanges・採番後に一覧再取得）、PK＋timestamp の楽観排他を扱う。MVC の CRUD 画面 / 一覧＆更新 / テーブルメンテナンス / マスタメンテ / Razor で一覧更新 / DataTable を Session に持つ を伴うときに使う。バッチ更新の中核は opentouryo-batch-update、コントローラ基礎は opentouryo-layer-p-mvc。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# テーブル・メンテナンス画面（一覧・詳細・更新）の P層パターン（MVC）

**ASP.NET MVC のテーブル保守 CRUD 画面**の型。**主対象は ASP.NET Core MVC（net10.0）**（net48 MVC も実装は同型＝差は Session 直列化だけ・後述）。
コントローラ／アクションの基礎は `opentouryo-layer-p-mvc`、RowState バッチの中核は `opentouryo-batch-update`、
動的検索は `opentouryo-query-definition`（DPQ）、一覧ページングの SQL は `opentouryo-app-design/references/list-paging.md`。

> 📋 **コピー元スニペット（コントローラ骨格・ビュー骨格）は `references/snippets.md`。**

> **★ Web Forms と違い MVC には自動生成の CRUD 足場（`_3TierEngine`/`ObjectDataSource`/`GridView`）が無い。** アクションメソッド＋Razor で自前に組む
> （`opentouryo-layer-p-mvc`＋本スキル＋`opentouryo-batch-update`）。Web Forms 版は `opentouryo-webforms-crud-screens`。

## 2方式（どちらで作るか）

| 方式 | 画面構成 | 追加/更新/削除 | 使いどころ |
| --- | --- | --- | --- |
| **(1) 一覧→詳細** | 検索一覧 → 詳細（別アクション/画面） | すべて詳細で（単一レコード CRUD） | **オーソドックス。基本はこちら** |
| **(2) 一覧＆更新** | 一覧でその場に複数行を編集 | UPDATE/DELETE は一覧で（複数行＝RowState バッチ）・追加は空行 | 一覧で直接編集したいとき |

## MVC 固有の要点（Web Forms との違い）

- **UOC は無い＝アクションメソッド。** `[HttpGet] Index` で表示、`[HttpPost] SelectAll`/`AddRow`/`DeleteRow`/`BatchUpdate` で操作。
  B層の振り分けは引数クラスの `MethodName`（サンプルに倣い `this.ActionName` を渡す）＝`opentouryo-layer-p-mvc`。P→B は `new LayerB().DoBusinessLogicAsync(pv, iso)`。
- **フォームと CSRF**＝`<form method="post" asp-action="…">`＋`@Html.AntiForgeryToken()`／**POST アクションに `[ValidateAntiForgeryToken]`**。
- **1フォームから複数アクションへ**＝ボタンの `formaction="@Url.Action("<action>","<ctrl>")"` で送信先を分岐（`SelectAll`/`AddRow`/`DeleteRow`/`BatchUpdate`）。
- **★ 行ボタンの配置3パターンは Web Forms と同型**（`opentouryo-webforms-crud-screens`／`opentouryo-batch-update`）＝**[削除]のみ／[更新][削除]／[編集][削除]**。ただし **MVC に `ButtonField`/`RowCommand`/`EditIndex` は無い**＝各行ボタンを **`formaction` で per-row アクションに飛ばし当該行の `RowIndex` を送る**：**[更新]**（例 `UpdateRow(rowIndex)`）・**[編集]**＝その行の input だけ編集可にして（他行は `readonly`／編集中行 index を hidden で持つ）編集後 [更新]・**[削除]**＝`DeleteRow(rowIndex)`＝`dr.Delete()`。**実 CUD はグリッド外 [バッチ更新]（`BatchUpdate`）で一括**（下記）。**★ 読み戻しは「追加行は常に／既存行はその行の [更新] のときだけ／削除行は対象外」**——追加行は DB に戻す値が無く、落とすと再バインドで空行に戻る〔要保護〕・既存行は取得時値が `DataTable` に残る＝読み戻さず「未確定」で可（無駄 `Modified`・過敏な楽観排他も減る）。読み戻しメソッドに「確定する行 index」を渡し、判定1行＝`if (dr.RowState != DataRowState.Added && row.RowIndex != targetRowIndex) continue;`（`UpdateRow`＝当該 index・`AddRow`/`DeleteRow`/`BatchUpdate`＝-1＝追加行のみ）。**※ 行 [更新] を置かない（[削除]のみ）パターンは、既存行を per-row 確定する手段が無いので `BatchUpdate` で全レコードを読み戻す**（この節の骨格スニペットは行 [更新] あり版）。
- **★ フッタのメイン5ボタンは `@section` に置く→ `form="<フォームID>"` で紐付ける。** `@section` の中身は `@RenderBody()`＝`<form>` の外に描画されるので、
  付けないと押しても送信されない（`opentouryo-layer-p-mvc` の `@section` 罠）。キャプションは画面ごと・不要は `disabled`。
- **一覧は `<table>` を自前生成し `<tr>` をループ**（`for` はコード文脈なので `@` を付けない＝付けると Razor パースエラー）。各行に **hidden `Rows[i].RowIndex`＋各列の
  `input name="Rows[i].<列>"`** を出し、ポストバックで **`List<行VM>`（`RowIndex`＋編集列）にモデルバインド**する。
  **★ `Deleted` 行は描画しない＝表示連番でなく DataTable の行インデックスを `RowIndex` で持ち回る**（連番だと Deleted でズレる）。
  **★ 添字 `i` が 0 起点の連番でない〔Deleted を飛ばす〕とき、各行に `<input type="hidden" name="Rows.Index" value="@i" />` も出す**——ASP.NET (Core) MVC のコレクション モデルバインドは**非連番の添字は `Rows.Index` が無いとバインドしない**＝`model.Rows` が空のまま `BatchUpdate` が走り**編集が静かに捨てられる**（実測：追加行が `NULL` で INSERT→`SqlException 515`。ビルドも 200 も通る）。スニペット＝`references/snippets.md`。
- **ダイアログは JavaScript**（確認＝`onclick="return window.confirm('…')"`、通知＝`window.alert(@Json.Serialize(Model.Message))` を `@section` のスクリプトで）。

## 編集中 DataTable を複数リクエストに跨って持つ（保持の置き場を選ぶ）

一覧取得〜行追加/削除/編集〜更新は複数リクエストに跨るので、**編集中の `DataTable`（`RowState` 付き）をどこかに保つ**（画面を開き直したら破棄）。
**★ `DTTables` JSON は本来 WebAPI の転送 DTO**（クライアントへ送って戻す＝`opentouryo-webapi-server`/`-client`）。MVC ではこの DTO の**置き場が2通り**ある：

- **(a) サーバの Session に置く**（クラシックな MVC ポストバック UI）。簡単だが**件数が Session のメモリを圧迫**・スケールアウトは out-of-proc Session が要る・**使用後の後始末（明示削除）も要る**。→ 後始末を避けたいなら (b)（**MVC に ViewState は無い**が、hidden 保持が Web Forms の ViewState に相当＝NW は増えるがサーバ資源も後始末も不要。`opentouryo-app-design/references/state-management.md`）。
- **(b) クライアントに持たせて往復させる**（hidden フィールド／SPA が保持）＝**サーバはステートレス**。**これは WebAPI クライアントと同じ機構**（DTTables JSON が HTTP を往復）。UI を API 駆動にするなら、
  **バッチ更新を Web API として公開し（`opentouryo-webapi-server`）ページ/SPA をそのクライアントに（`opentouryo-webapi-client`）するのが本来の形**。ただし**全表が毎回転送される**＝大きい結果セットでは (a) より重い。
- **★ (a)/(b) いずれも「編集対象の全結果セットを丸ごと持つ」＝レコード件数に上限を設けるかページング前提**（`opentouryo-app-design/references/list-paging.md`）。
  **ページングするなら編集（バッチ更新）開始後は結果セットを固定**する——ページ切替で再取得すると `RowState` が消えるため（`opentouryo-webforms-crud-screens` の「一覧＆更新」と同じ）。

**net48 MVC** は `DataTable` を Session に直接置ける（binary＝`RowState`/`Original` とも保つ・手当て不要）。**net10.0（Core）MVC で (a) を採る**なら `ISession` は `byte[]`/`string` のみ＝**`DTTables` JSON で往復**させる
（**(b) も同じ API**＝Session の代わりに hidden フィールド等へ入れるだけ）：`session.SetString(key, DTTables.DTTablesToJson(DTTables.FromDataSet(ds)))` ／復元 `DTTables.JsonToDTTables(json).ToDataSet()`（`Touryo.Infrastructure.Public.Dto`）。

- **`RowState`〔Added/Modified/Deleted〕は保持**＝復元後もバッチ CUD を振り分けられる。
- **列の属性は落ちる**（`AutoIncrement`/`Seed`/`PrimaryKey`/`AllowDBNull`。JSON は列名・型・値・`RowState` だけ）が**実害は小さい**：そもそも `ExecSelectFill_DT` は制約を取り込まない（`Fill` は `FillSchema` せず＝往復前から `PrimaryKey`/NOT NULL 無し）・IDENTITY 主キーは `D1_Insert` が INSERT しない。
  **★ 真の罠は「DB 側 NOT NULL 列を `DBNull` で INSERT→`SqlException 515`」＝アプリ側で担保する**（Added 行の NOT NULL 列に値を入れ、読み戻しは NULL 可否で `""`/`DBNull`。`opentouryo-batch-update`）。**追加行の仮主キーを使うとき〔`Rows.Find`／自前 `PrimaryKey`〕だけ**負値仮採番（`LoadEditingTable` スニペット・`references/snippets.md`）。
- **`Original`〔変更前値〕は既定 非保持**（`DTTable.FromDataTable(dt, keepOriginal:true)` で保持可＝全列 Original 排他も往復で成立。`FromDataSet` は引数無し＝表ごとに組む）。使わないなら **PK＋timestamp で排他**（`opentouryo-batch-update`）。

## RowState バッチ（一覧＆更新の核）

`opentouryo-batch-update` の RowState 振り分けをそのまま使う。MVC 側のアクションの流れ（コード＝`references/snippets.md`）：

1. **［一覧取得］**（`SelectAll`）→ B層で `DataTable` を取得し Session へ。
2. **［行追加］**（`AddRow`）→ 画面の編集を読み戻してから `dt.NewRow()`＋`Rows.Add()`＝**Added**。IDENTITY 主キーは**負値で仮採番**（`opentouryo-batch-update`）。
3. **［削除］**（`DeleteRow`, `rowIndex`）→ `dt.Rows[rowIndex].Delete()`＝**Deleted**（`Rows.Remove` にしない）。
4. **セル読み戻し**＝各行 VM を DataRow に代入し **Modified**。**現在値と一致なら代入しない**（無駄 Modified 回避）・**空文字は `DBNull` に戻す**。
5. **［更新］**（`BatchUpdate`）→ 読み戻し後 `parameterValue.<表>=dt` で B層へ。**業務例外は `ErrorFlag`（ロールバック済み）＝`RowState` を残してやり直せる**。
   成功後 **`dt.AcceptChanges()`**。**IDENTITY 採番値は戻らないので一覧を再取得**して返す。
- **楽観排他**＝PK＋timestamp（件数0検知＝`opentouryo-layer-d`／`opentouryo-dao-generated`）。全列 Original を Core Session 跨ぎで使うときの注意は `opentouryo-batch-update`。

## やってはいけないこと

- **フッタの submit を `@section` に置いて `form=` を付けない** — `<form>` の外に出て無反応（`opentouryo-layer-p-mvc`）。
- **表示連番を DataTable の行インデックスに使う** — `Deleted` は描画されずズレる。**hidden `RowIndex` を持ち回る**。
- **Core Session に `DataTable`／オブジェクトを直接置こうとする** — `byte[]`/`string` のみ。`DTTables` JSON にする（net48 は直接置ける）。
- **削除を `Rows.Remove()` でやる** — `Deleted` にならず DELETE が出ない。`dr.Delete()`。
- **POST アクションに `[ValidateAntiForgeryToken]` を付け忘れる／業務例外を `catch` する** — 前者は改ざん防御が抜ける、後者は `ErrorFlag` で戻る（飛んでこない）。

> ※ 配布サンプル（`MVC_Sample_Core` 等）に本パターンそのままの画面が無いこともある＝**本パターンを正**とし、`opentouryo-layer-p-mvc`＋`opentouryo-batch-update` で組む。
