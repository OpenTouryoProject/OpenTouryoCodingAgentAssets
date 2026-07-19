---
name: opentouryo-project-setup-db
description: "OpenTouryo アプリのローカル開発用データストア（SQL Server / MySQL / PostgreSQL / Redis / MongoDB）を Docker で立てる、opentouryo-project-setup の選択式（任意）の環境構築ステップ。LocalServicesOnDocker（NetDevInfraWGinOSSConsortium）を clone し Start-Services で起動・Stop-Services で停止する。既定（SQL Server 1433/sa/Northwind 等）が OpenTouryo サンプルの接続文字列と一致するので、多くは無改変で繋がる。⑦ config の接続確認・実行検証（run-verify）の DB 依存操作の前提を満たす。DB 構築 / データストア / Docker / ローカル環境 / SQL Server / Northwind / MySQL / PostgreSQL / 接続先 を伴う作業のときに使う。既存 DB があれば不要。接続キーの一般解説は opentouryo-config、DBMS 選択は opentouryo-p-call-business。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 環境（データストア）の構築 — 選択式（任意）

新規立ち上げ（`opentouryo-project-setup`）の**任意の環境構築ステップ**。OpenTouryo アプリが接続する
**ローカルのデータストアを Docker で用意**する。⑦ `opentouryo-project-setup-config` の接続確認や、
実行検証（`opentouryo-project-setup-config` の `references/run-verify.md`）の **DB 依存操作の前提**を満たす。

- **選択式**：**既に接続先 DB があるなら不要**（このスキルはスキップ）。ローカルにサッと一式を立てたいときに使う。
- 接続キーの一般解説は `opentouryo-config`、DBMS の選び方は `opentouryo-p-call-business`。

## 使うもの

**LocalServicesOnDocker**（NetDevInfraWGinOSSConsortium）：`SQL Server / MySQL / PostgreSQL / Redis / MongoDB` を
Docker でまとめて立てる構成。<https://github.com/NetDevInfraWGinOSSConsortium/LocalServicesOnDocker>

- **前提**：Docker（**Rancher Desktop** か **WSL2** のいずれか）。

## 取得と起動・停止

リポジトリを clone し、**用途に合う起動スクリプトを実行**する。

```powershell
# Windows（Rancher Desktop）— DB 初期化の完了を待つ .ps1 を推奨（.bat は待たない）
.\Start-Services.ps1        # 起動（初期化待ち）
.\Stop-Services.ps1         # 停止
```

```bash
# WSL2 — 共有ネットワークを作ってから compose
docker network create --driver bridge common_link
docker compose up -d        # 起動
docker compose down         # 停止（-v でボリュームも削除＝データ全消し）
```

WSL2 向けは `Start-Services_wsl2.ps1` / `Stop-Services_wsl2.ps1` もある。状態確認は `docker compose ps` / `logs`。

## OpenTouryo との噛み合わせ（既定が一致）

**既定値が OpenTouryo サンプルの接続文字列とほぼ一致**する（同系プロジェクト。多くは無改変で繋がる）。

| サービス | ポート | ユーザ / パスワード | DB | OpenTouryo 側 |
| --- | --- | --- | --- | --- |
| SQL Server | 1433 | `sa` / `seigi@123` | `Northwind` | `ConnectionString_SQL`（サンプル既定と一致） |
| MySQL | 3306 | `root` / `seigi@123` | `test` | `ConnectionString_MCN`（一致）・`DamMySQL` |
| PostgreSQL | 5432 | `postgres` / `seigi@123` | `postgres` | `DamPstGrS`（接続文字列は用途に合わせ追加） |
| Redis | 6379 | — | — | キャッシュ等 |
| MongoDB | 27017 | `seigi` / `seigi@123` | — | — |

- **DBMS の選択は `actionType` の先頭**（`SQL%...` 等）＋対応する `ConnectionString_<code>`（`opentouryo-config` /
  `opentouryo-p-call-business`）。既定サンプルは SQL Server（`ConnectionString_SQL`）で動く。
- **Oracle は本 Docker に含まれない**（サンプルの `ConnectionString_ODP`＝SCOTT/tiger は別途 Oracle を用意する）。
- **サンプル固有の追加テーブルは Northwind に含まれない**：サンプル同梱の `CREATE *.sql` を別途流す
  （例：`RerunnableBatch_sample` の `ORDERS2`＝同梱 `CREATE ORDERS2.sql`。`run-verify.md` のバッチ/CLI 節）。
- 接続文字列を変える場合、機微情報の直書きを避ける方針は ⑥（`opentouryo-project-setup-config`）に従う。

## ★ グローバル変更として記録する

Docker の**コンテナ・ボリューム・ネットワーク（`common_link`）はマシン全体に残る変更**。**`SETUP-CHANGES.md` に記録**する
（AGENTS.md ポリシー）。例：`docker network common_link = 作成 ／ docker network rm common_link`、
`docker compose (LocalServicesOnDocker) = 起動 ／ docker compose down（-v でデータも削除）`。

## やってはいけないこと

- **`seigi@123` 等の既定資格情報を本番で使う** — これは**ローカル開発用**。本番は別の資格情報にする
- **接続文字列に機微情報を平文で残す** — 環境変数方式など（⑥ `opentouryo-project-setup-config`）
- **この Docker に Oracle を期待する** — 含まれない。Oracle が要るなら別途用意する
- **既存 DB があるのに重ねて立てる** — 選択式。接続先がある環境ではスキップする
