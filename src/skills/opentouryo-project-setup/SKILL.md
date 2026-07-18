---
name: opentouryo-project-setup
description: "OpenTouryo を使う新規プロジェクトをゼロから立ち上げる（セットアップ）ときの入口＝ファサード。手順を順序で4スキルに分け、全体の流れと呼び出し順だけをここで示す：①②サンプル選択・取得元＝opentouryo-project-setup-selection、③基盤ビルドとベンダ＝opentouryo-project-setup-build、④⑤取り出しと参照張り替え＝opentouryo-project-setup-core、⑥⑦resource 移設・config・検証＝opentouryo-project-setup-config。net48 / .NET 10.0 の両対応。プロジェクト作成 / セットアップ / 新規立ち上げ / サンプルから始める / 参照設定 / DLL 参照 / OpenTouryoAssemblies を伴う作業の入口に使う。既存プロジェクトでコードを書くのは各層スキル、構成キーの詳細は opentouryo-config を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.2.0"
---

# 新規プロジェクトのセットアップ（ファサード）

## このスキルの役割

**ゼロから新規に OpenTouryo アプリを立ち上げる**ときの**入口**。OpenTouryo のサンプルを起点に、
基盤 DLL を参照する標準構成のプロジェクトを作る。**このスキル自体は全体の流れと呼び出し順を示すだけ**で、
各工程の手順は下の順序別サブスキルが担う。

- 既存プロジェクトでコードを書く → 各層スキル（`opentouryo-layer-*` / `opentouryo-p-*` ほか）
- 構成ファイル・設定キーの詳細 → `opentouryo-config`

**両ランタイム対応**（.NET Framework 4.8 / .NET 10.0）。エージェントが全工程を実行する。

## 全体の流れ（7ステップ ＝ 4スキル）

**上から順に、各サブスキルを呼んで進める。**

```
①② 作りたいサンプルを選ぶ／取得元（固定タグ・develop）を選ぶ  → opentouryo-project-setup-selection
③  基盤 DLL をビルドして OpenTouryoAssemblies\ へベンダ         → opentouryo-project-setup-build
④⑤ サンプルを取り出し、.csproj の OpenTouryo.* HintPath を張替  → opentouryo-project-setup-core
⑥⑦ resource 移設・config パス張替・.gitignore・ビルド／実行検証 → opentouryo-project-setup-config
```

- **①② `opentouryo-project-setup-selection`** — 起点サンプル（全系列を提示）と `<ref>`（固定タグ/develop）を決める。
- **③ `opentouryo-project-setup-build`** — ②の `<ref>` と標的ランタイムで基盤をビルド→ベンダ。1回で再利用可。
- **④⑤ `opentouryo-project-setup-core`** — サンプル（＋開発支援ツール）を取り出し、参照をベンダ先へ張り替える。核心。
- **⑥⑦ `opentouryo-project-setup-config`** — resource を移設し config を環境変数方式へ、`.gitignore`、ビルド／実行で検証。

**基盤（OpenTouryo フレームワーク）はバイナリ提供が前提。** ビルドした DLL を参照する
（`opentouryo-common-parts` / `AGENTS.md` の「クラスの階層と修正可否」）。**親クラス2 をカスタマイズする**なら
`opentouryo-base2-customize`（③のビルドに関わる）。

## 完了後（任意）：構成変更へ進むか選ぶ

セットアップ（①〜⑦）が済んだら、**続けて構成変更（`opentouryo-project-transform`）を行うかをユーザに選ばせる**。
早くフィードバックを得たいなら、セットアップ直後にその場で実行してよい（**任意**）。

- 進む → `opentouryo-project-transform`（例：WS 依存の切り離し・サンプル固有コードの整理・`CS0246` 解消）
- 後回し → 何もしない。利用者がソリューションを俯瞰してから別途依頼する

**セットアップの途中に構成変更の判断を割り込ませない**（選ばせるのは「開ける状態」の後）。
**セットアップ成果はコミットを促す**（未コミットのままだと作業ツリーから失われうる＝実測。ビルド確認まで済んだ
節目でユーザに提案する。git 操作はしない方針は保つ）。

## やってはいけないこと（全工程共通の原則）

- **`OpenTouryo.*` を `ProjectReference` にする** — 基盤はバイナリ提供が前提。DLL 参照にする
- **基盤（`Frameworks/Infrastructure/*`）を導入リポジトリに取り込んで改造する** — 纏め者の領分
  （`opentouryo-project-policy` / `opentouryo-base2-customize`）。導入プロジェクトはビルド済み DLL を参照するだけ
- **作業ツリー `Temp/`（基盤ソース＝親クラス2 を含む）をコミットする** — `.gitignore` で除外する（⑦）
- **Download→Build→ベンダをアドホックなコマンド羅列で済ませる** — スクリプト化して残す（③）
- **net48 サンプルを .NET 10.0 で、または Web Forms を core で使おうとする** — ランタイム対象外

各工程固有の禁止事項は、それぞれのサブスキルに置く。
