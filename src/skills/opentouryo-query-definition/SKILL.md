---
name: opentouryo-query-definition
description: "OpenTouryo の SQL 定義ファイルを書く。静的パラメタライズドクエリ（.sql）と動的パラメタライズドクエリ（.xml）の両方を扱う。@パラメタとユーザパラメタ（静的の %名前% / 動的の VAL タグ）の違い、動的SQLのタグ（ROOT / IF / ELSE / WHERE / DELCMA / INSCOL / VAL / LIST / SELECT / CASE / DEFAULT / JOIN / SUB / PARAM / DIV）の意味と書き方、DPQuery_Tool 用の PARAM タグを扱う。SQL 定義ファイル / .sql / .xml / 静的SQL / 動的SQL / パラメタライズドクエリ / ORDER BY の動的化 / 検索条件の動的化 を伴う作業のときに使う。Dao 側の実装は opentouryo-layer-d を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# SQL 定義ファイル（静的 / 動的パラメタライズドクエリ）

## このスキルの適用範囲

Dao から実行する SQL 定義ファイルの書き方。ファイルの配置と読み込みは Dao 側の責務なので
`opentouryo-layer-d` を参照。

## 2種類の定義ファイル

| 拡張子 | 種類 | 中身 |
| --- | --- | --- |
| `.sql` | 静的パラメタライズドクエリ | SQL 文をそのまま書く |
| `.xml` | 動的パラメタライズドクエリ | タグで囲んだ SQL。実行時に条件で組み立てる |

**拡張子で自動的に切り替わる。** Dao 側で `SQLFileName = "Xxx.sql"` なら静的、`"Xxx.xml"` なら
動的として扱われる。

### 使い分け

- **SQL の形が実行時に変わらない** → `.sql`
- **条件・列・ORDER BY などが実行時に変わる** → `.xml`

「値だけ変わる」なら静的で足りる（値は `@パラメタ` で渡せる）。**SQL の構造そのものが変わる場合に
初めて動的にする。** 動的は読みにくくデバッグしにくいので、必要がなければ使わない。

## パラメタとユーザパラメタ

**両形式に共通する概念だが、構文が違う。** そして安全性がまったく違う。

| | パラメタ | ユーザパラメタ |
| --- | --- | --- |
| 仕組み | パラメタライズドクエリのパラメタ | **SQL 文字列への置換** |
| 静的（`.sql`）の構文 | `@名前` | `%名前%` |
| 動的（`.xml`）の構文 | `@名前` | `<VAL name="名前"/>` |
| 設定する API | `SetParameter("名前", 値)` | `SetUserParameter("名前", 値)` |
| 用途 | 値 | 列名・ソート順など、パラメタにできない箇所 |
| ユーザ入力 | **渡してよい** | **渡してはならない**（SQL インジェクション） |

ユーザパラメタは文字列置換なので、値をそのまま SQL に埋め込む。**入力値はコード側で安全な値に
変換してから渡す**（`opentouryo-layer-d` 参照）。

## 静的パラメタライズドクエリ（.sql）

SQL をそのまま書く。パラメタは `@名前`、ユーザパラメタは `%名前%`。

```sql
-- ShipperSelectOrder.sql
SELECT
  ShipperID, CompanyName, Phone
FROM
  Shippers
WHERE
  CompanyName != @P1
ORDER BY %COLUMN% %SEQUENCE%
```

```csharp
cmnDao.SQLFileName = "ShipperSelectOrder.sql";
cmnDao.SetParameter("P1", "test");                  // @P1 に対応
cmnDao.SetUserParameter("COLUMN", " ShipperID ");   // %COLUMN% に対応
cmnDao.SetUserParameter("SEQUENCE", " ASC ");       // %SEQUENCE% に対応
```

## 動的パラメタライズドクエリ（.xml）

### 基本構造

`<ROOT>` で囲む。中は SQL とタグの混在。

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<ROOT>
  SELECT
    ShipperID, CompanyName, Phone
  FROM
    Shippers
  <WHERE>
    WHERE
      <IF>CompanyName != @P1</IF>
  </WHERE>
  ORDER BY <VAL name="COLUMN"/> <VAL name="SEQUENCE"/>
</ROOT>
```

**タグ名は大文字・小文字を区別する。** すべて大文字で書く。

### タグ一覧

| タグ | 役割 |
| --- | --- |
| `<ROOT>` | ルート要素。必須 |
| `<IF>` | 中のパラメタが設定されていれば有効、未設定なら消える |
| `<ELSE>` | `<IF>` の中に入れ子にする。`IF` が無効のとき代わりに出力される |
| `<WHERE>` | WHERE 句を囲む。中が空になれば WHERE ごと消える。余剰な先頭 AND / OR を除去する |
| `<DELCMA>` | 囲んだ範囲の**前後**のカンマを削除する |
| `<INSCOL name="列名">` | INSERT の列リスト。対応するパラメタが未設定なら消える |
| `<VAL name="名前"/>` | ユーザパラメタ（文字列置換） |
| `<LIST>` | IN 句。1つのパラメタ名に複数値を展開する |
| `<SELECT name="名前">` | 値による分岐。中に `<CASE>` / `<DEFAULT>` を置く |
| `<CASE value="値">` | `SELECT` のパラメタ値が一致したとき有効 |
| `<DEFAULT>` | どの `CASE` にも一致しなかったとき有効 |
| `<JOIN name="名前">` | JOIN 句。Boolean パラメタで有効・無効を切り替える。ネスト可 |
| `<SUB name="名前">` | サブクエリ。Boolean パラメタで有効・無効を切り替える |
| `<PARAM>` | **DPQuery_Tool 用のテスト値定義。実行時には削除される** |
| `<DIV/>` | `<PARAM>` 内の区切り |

### IF / ELSE

`<IF>` は中の `@パラメタ` が設定されていれば有効になる。

```xml
<IF>AND [ts] = @ts<ELSE>AND [ts] IS NULL</ELSE></IF>
```

`@ts` が設定されていれば `AND [ts] = @ts`、未設定なら `AND [ts] IS NULL` になる。

`name` 属性を付けると、Boolean パラメタで明示的に制御できる。

```xml
<IF name="if1">CompanyName IS NOT NULL</IF>
```

### WHERE

**各条件の先頭に `AND` を付けて書く。** WHERE 直後の余剰な `AND` / `OR` は自動で除去される。

```xml
<WHERE>
  WHERE
    <IF>AND [ShipperID] = @ShipperID</IF>
    <IF>AND [CompanyName] = @CompanyName</IF>
    <IF>AND [Phone] = @Phone</IF>
</WHERE>
```

どの `<IF>` も有効にならなければ、`WHERE` 句ごと消える。先頭に付ける `AND` を省くと、
1つ目が無効になったときに `WHERE AND ...` にならず壊れるので、**全条件に付ける**。

### DELCMA / INSCOL

カンマ区切りのリストで、一部の要素が消えたときのカンマを処理する。

```xml
INSERT INTO [Shippers]
  (
    <DELCMA>
      <INSCOL name="ShipperID">[ShipperID],</INSCOL>
      <INSCOL name="CompanyName">[CompanyName],</INSCOL>
      <INSCOL name="Phone">[Phone],</INSCOL>
    </DELCMA>
  )
VALUES
  (
    <DELCMA>
      <IF>@ShipperID,</IF>
      <IF>@CompanyName,</IF>
      <IF>@Phone,</IF>
    </DELCMA>
  )
```

**各要素の末尾にカンマを付けて書く。** `<DELCMA>` が前後のカンマを削除する
（無くなるまで繰り返す）ので、どの要素が残っても正しくなる。

UPDATE の SET 句も同じ。

```xml
SET
  <DELCMA>
    <IF>[CompanyName] = @Set_CompanyName_forUPD,</IF>
    <IF>[Phone] = @Set_Phone_forUPD,</IF>
  </DELCMA>
```

### VAL

ユーザパラメタ。`<VAL name="名前"/>` は空要素タグで書く。

```xml
ORDER BY <VAL name="COLUMN"/> <VAL name="SEQUENCE"/>
```

**前後の空白がつめられることがある。** 必要なら値側で明示的に空白を付ける。

```csharp
cmnDao.SetUserParameter("COLUMN", " " + orderColumn + " ");
```

### LIST

IN 句。1つのパラメタ名に複数の値を展開する。

```xml
<LIST>AND SEX IN (@SEX)</LIST>
```

### SELECT / CASE / DEFAULT

パラメタの値による分岐。

```xml
<SELECT name="sel">
  <CASE value="a1">
    SELECT * FROM Shippers
  </CASE>
  <CASE value="b2">
    SELECT * FROM Products
  </CASE>
  <DEFAULT>
    SELECT * FROM [Order Details]
  </DEFAULT>
</SELECT>
```

`sel` パラメタの値が `a1` なら1つ目、`b2` なら2つ目、いずれでもなければ `<DEFAULT>` が有効。

### JOIN / SUB

JOIN 句・サブクエリを Boolean パラメタで丸ごと有効・無効にする。`<JOIN>` はネストできる。

```xml
<JOIN name="j1">
  INNER JOIN
    (SELECT * FROM shippers
      <WHERE>WHERE
        <IF name="if1">CompanyName IS NOT NULL</IF>
        <SUB name="s1">AND ShipperID IN (SELECT DISTINCT(ShipperID) FROM shippers)</SUB>
      </WHERE>)
    AS s ON o.shipvia = s.shipperid
</JOIN>
```

`j1` に `true` を設定すれば JOIN が有効になる。不要な JOIN を実行時に外せる。

## PARAM タグ（ツール用）

`<PARAM>`（`.xml`）と `/*PARAM* ... *PARAM*/`（`.sql`）は、**DPQuery_Tool でクエリを試験実行する
ためのテスト値定義**。実行時にはフレームワークが削除するので、SQL には影響しない。

```xml
<PARAM>
  JOB, String, CLERK<DIV/>
  COMM, Decimal, 2301.00<DIV/>
  SEX, Char, M, F<DIV/>
  COLUMN, EMPNO<DIV/>
</PARAM>
```

```sql
/*PARAM*FN,String,CHRISTINE*PARAM*/
/*PARAM*COLUMN,EMPNO*PARAM*/
```

書式は `名前, 型, 値`。`<LIST>` 用は値を複数並べる（`SEX, Char, M, F`）。
ユーザパラメタは型を書かない（`COLUMN, EMPNO`）。

アプリケーションのコードから読まれることはない。**残しても消しても実行結果は変わらない。**

## やってはいけないこと

- **コメントに `@名前` を書く** — パラメタとみなされてエラーになる。
  コメントでパラメタに言及するときは `＠P1` のように全角にするなどして避ける
- **`SetUserParameter()`（`%名前%` / `<VAL>`）にユーザ入力を渡す** — 文字列置換のため
  SQL インジェクションになる。コード側で安全な値に変換してから渡す
- **タグを小文字で書く** — 大文字・小文字を区別する。`<if>` は認識されない
- **`<WHERE>` 内の条件の先頭 `AND` を省く** — 前の条件が無効になったときに壊れる。全条件に付ける
- **`<DELCMA>` 内の要素の末尾カンマを省く** — カンマは `<DELCMA>` が消す前提で、必ず付ける
- **構造が変わらないのに `.xml` を使う** — 値だけ変わるなら `.sql` と `@パラメタ` で足りる
- **`<PARAM>` が実行に影響すると考える** — ツール用。実行時には削除される
