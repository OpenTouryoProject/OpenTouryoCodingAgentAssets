# 品質の羅針盤（QUALITY.md）

<!-- 見本：OpenTouryoCodingAgentAssets の src/compass/QUALITY.sample.md（OpenTouryoCodingAgentAssets#21）。
     install.ps1 -IncludeQualityGuard が、導入先に QUALITY.md が無いときだけ置く。以後はこのリポジトリが持つ（入れ直しでも上書きしない）。
     「TODO」を検索して埋める。埋め方は OpenTouryoCodingAgentAssets の src/compass/INSTALL.md（エージェントがリポジトリを調べ、人に聞きながら埋める）。
     「見本の行」は OpenTouryo を使うアプリの例である。このリポジトリに合わせて直すか、消す。 -->

**どこを・何で・どれだけ確かめるか**を、このリポジトリについて決めた文書。人が決め、エージェントが従う。

- **共通の決まりは [`QUALITY.common.md`](QUALITY.common.md)**（配布物。直さない）。**節の番号は同じ**で、本書には各節のこのリポジトリの中身だけを書く
- **エージェントは、変更の前に本書と `QUALITY.common.md` を読む**（[`AGENTS.md`](AGENTS.md) から参照し、`CLAUDE.md` から読み込んでいる）

> **人は個々の変更を細かく見るより、羅針盤を決める役を担う。**
> エージェントは、作業が品質マップのどの単位に当たるかを本書で引き、その重みで確かめ、報告する。

## このリポジトリの値

`QUALITY.common.md` の「このリポジトリの値」は、この表を指す。

| 項目 | 値 |
|---|---|
| 検出器の置き場所 | TODO（`install.ps1 -QualityGuardPath` の値。既定は `tools/ExpectationGuard`） |
| 判定の用例の置き場所 | TODO（既定は `tools/ExpectationGuard/ExpectationGuard.Tests`） |
| 入れ直しのコマンド | TODO（例 `<アセット>\install\install.ps1 -Product claude -TargetRoot <このリポジトリ> -IncludeQualityGuard`） |
| 宛先のブランチ（段 3 で検査する PR の宛先） | TODO（`expectation-change.yml` の `branches`。例 `develop`・`main`） |
| 必須のチェック | TODO（例 `expectation-change`。必須にしていなければ「まだ」と書く） |
| 共有の作業ブランチ | TODO（複数の人・セッションが push するブランチ。メッセージを書き直さない） |
| 変更のレビュー役（4 節） | `opentouryo-change-reviewer` |
| テスト先行のレビュー役 | `opentouryo-test-reviewer`（[`TESTING.md`](TESTING.md) 5） |
| 回帰テストの名前 | TODO（例 テストのメソッド名かコメントに Issue の番号） |

### 一次情報

**本書には方針と表だけを置く。** 手順は各文書が一次情報である。

| 内容 | 一次情報 |
|---|---|
| テスト先行の進め方・テストの保護 | [`TESTING.md`](TESTING.md) |
| 検証の手順・回す範囲 | TODO（ビルド・テストの回し方の文書） |
| 仕様（根拠の ID の出典） | TODO（画面定義書・イベント仕様書・テーブル定義書の場所と版） |
| コーディング規約 | TODO |

---

## 1. 品質マップ

**単位**：TODO（例 層と業務。名前空間で分けるなら、接頭辞の省略を書く）

| 単位 | リスク | 正の根拠 | 検証の手段 | 人が必ず見る箇所 |
|---|---|---|---|---|
| （見本の行）B層の業務ロジック（`DoBusinessLogic` の `UOC_*`。トランザクション境界） | **高** | イベント仕様書（`EV-*`・`VAL-*`・`ERR-*`） | B層の単体テスト（NUnit。`opentouryo-test-layer-b`） | 業務エラーの判定（`ErrorFlag`・メッセージ ID）、分離レベル、更新の件数 |
| （見本の行）認証・権限（サインイン・ロールによる画面・操作の制限） | **高** | 方式の設計 | 画面の E2E | 権限の確かめを飛ばせる経路、既定値の変更 |
| （見本の行）D層（SQL・Dao） | **中〜高** | 各 DBMS の文法、テーブル定義書 | B層の単体テスト（DB の状態） | SQL の組み立て（パラメタ化）、排他、DDL の変更 |
| （見本の行）P層（画面・Controller） | 中 | 画面定義書・イベント仕様書 | 画面の E2E（`opentouryo-test-e2e-web`） | 入力の検証、遷移、エラーの表示 |
| （見本の行）ツール・サンプル・テストの補助 | 低 | — | ビルド | 原則として見ない |
| TODO | | | | |

- TODO（このリポジトリ固有の注。例：OpenTouryo の版を上げるときは、全テストを通す）

---

## 2. 正の定義

- **根拠**：TODO（例 イベント仕様書の ID。付けられないケースは仕様の決定として人に上げる。`TESTING.md` 2）
- **観測の扱い**：TODO（観測を残すか。残すなら、落とすか・差分を報告するか）
- **外部の基準**：TODO（例 CodeQL。無ければ「無し」）

---

## 3. 期待値の変更と、その承認

- **期待値の変更に当たるもの**：[`TESTING.md`](TESTING.md) 3 と、検出器の `rules.psd1`（`Paths`・規則）。テストの場所が違えば `rules.psd1` を合わせる
- TODO（このリポジトリで足した規則・生成物の確認があれば書く。無ければこの行を消す）

---

## 4. レビューの観点

**単位に応じて、次を確かめる。** どの単位でも見る観点は `QUALITY.common.md` 4 節にある。

### （見本）Web のセキュリティ（P層）

- [ ] 状態を変える要求で、CSRF の対策（MVC の `ValidateAntiForgeryToken` など）を外していないか
- [ ] リダイレクトの行き先に、利用者の入力が素通しで入らないか（オープン リダイレクト）
- [ ] 例外の画面・ログに、利用者に見せてはいけない内容（スタック トレース・接続文字列）を出していないか
- [ ] 読めない入力（NUL 文字など）で 500 にしないか。net48 と net10.0 で振る舞いが分かれないか

### （見本）DB（D層）

- [ ] パラメタ化できる値を、パラメタにしているか。リテラル・識別子を文字列で組み立てていないか
- [ ] 使う DBMS のすべてで、同じ意味になるか
- [ ] 読んだ値で書き戻していないか（並行した要求の更新が消える）
- [ ] DDL を変えたなら、配備済みの DB への手順を書いたか

### TODO（このリポジトリの単位ごとの観点）

- [ ] TODO

---

## 5. フィードバックの輪

- TODO（このリポジトリ固有の戻し方があれば書く。無ければ `QUALITY.common.md` 5 節のとおり、と書く）

---

## 6. 計測

- TODO（このリポジトリ固有の指標と、初回の基準の値。例：B層のテストの根拠の種類の内訳、画面の E2E の数）

---

## 7. 期待値の根拠の書き方

- **書き方**：TODO（例 `[Basis("EV-ORD-101")]`。`TESTING.md` 2・3）

```csharp
[Test]
[Basis("EV-ORD-101")]    // TODO：このリポジトリの書き方に合わせる
public void OrdListSearch_顧客で絞る() { ... }
```

---

## 8. エージェント向けチェックリスト

共通の項目は `QUALITY.common.md` 8 節。このリポジトリでは、次も確かめる。

- [ ] TODO（例：テスト仕様の先頭の仕様の版を書き換えたか）
