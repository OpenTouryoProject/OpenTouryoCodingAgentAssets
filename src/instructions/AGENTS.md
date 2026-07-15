<!--
  このファイルは OpenTouryo を利用するアプリ開発リポジトリへ配布される
  「概要」インストラクションの原本（Single Source of Truth）です。

  ■ 位置づけ
    - 概要・規約・地図 → このファイル（常時コンテキストに載る）
    - 具体的なコードの書き方 → src/skills/ 配下のスキル（必要時のみロードされる）
    手順や特定領域だけの話はスキルへ。ここには毎回必要な事実だけを書く。

  ■ 制約
    - 目安 200 行以内。長いほど追従率が下がる。
    - このような HTML コメントは Claude Code では読み込み時に除去される。
      執筆者向けメモの置き場として使える（他プロダクトでは除去されない点に注意）。

  ■ TODO の埋め方
    「TODO:」を検索して各節を埋めてください。空欄のまま配布しないこと。
-->

# OpenTouryo アプリケーション開発

このリポジトリは **OpenTouryo**（.NET 用アプリケーションフレームワーク）を利用している。
以下の規約に従って実装すること。

## 対象バージョン

<!-- TODO: OpenTouryo 本体のバージョンと IDE を埋める。ランタイムは確定済み。 -->

- OpenTouryo: TODO
- ランタイム: .NET Framework 4.8（net48）/ .NET 10.0
- IDE: TODO

ランタイムによって書き方が変わる箇所がある。差異は各スキルに記述する。
判明している主な差異：構成ファイルは XML 定義ファイルが共通、`app.config` は core 系で
`appsettings.json` になる。

## アーキテクチャ

OpenTouryo は **P層 / B層 / D層** の3層構造をとる。各層の責務は厳格に分離されており、
層をまたぐ呼び出しは規定の経路以外を通してはならない。

| 層 | 責務 | 主な基底クラス | スキル |
| --- | --- | --- | --- |
| P層（画面 / API） | TODO | TODO | `opentouryo-layer-p` |
| B層（業務ロジック） | TODO | TODO | `opentouryo-layer-b` |
| D層（データアクセス） | TODO | TODO | `opentouryo-layer-d` |

<!-- TODO: 層間の呼び出し経路を1〜2文で。「P層はB層をXX経由で呼ぶ」「D層は必ずB層から呼ぶ」等。 -->

TODO: 層間の呼び出し規約

## ディレクトリ構成

<!-- TODO: このリポジトリでの実際の配置。エージェントが「どこに何を書くか」を即断できる粒度で。 -->

```
TODO
```

## 命名規約

<!-- TODO: 検証可能な形で書く。「適切に命名する」ではなく「Dao クラスは <テーブル名>Dao とする」。 -->

- TODO

## 実装時の必須ルール

<!--
  TODO: 毎回守らせたい「常にXXする / 絶対にXXしない」だけをここに。手順はスキルへ。
  以下1件は検証済み。.NET の一般的な作法と逆で、知らないと必ず間違えるためここに置く。
-->

- **業務例外（`BusinessApplicationException`）はリスローされない。** B層でスローすると
  フレームワークが捕捉し、正常系の戻り値（`ErrorFlag = true`）に変換する。呼び出し側で
  `catch` してはならない（飛んでこない）。詳細は `opentouryo-exception` を参照。
- TODO

## ビルドと実行

<!-- TODO: 具体的なコマンド。「テストする」ではなく「`XXX` を実行する」。 -->

- ビルド: TODO
- テスト: TODO
- 実行: TODO

## スキル

具体的な実装手順は以下のスキルに記述されている。該当する作業に着手する前に読むこと。

| スキル | 使いどころ |
| --- | --- |
| `opentouryo-layer-p` | TODO（処理方式別に `-winforms` / `-webforms` / `-mvc` へ分割予定） |
| `opentouryo-layer-b` | TODO |
| `opentouryo-layer-d` | TODO |
| `opentouryo-exception` | 例外を扱うとき。層を問わず参照する |
| `opentouryo-common` | TODO（ログ・認証・構成ファイル） |

## 参考資料

- OpenTouryo 本体: https://github.com/OpenTouryoProject/OpenTouryo
- ドキュメント: https://github.com/OpenTouryoProject/OpenTouryoDocuments
- Wiki: https://opentouryo.osscons.jp/
