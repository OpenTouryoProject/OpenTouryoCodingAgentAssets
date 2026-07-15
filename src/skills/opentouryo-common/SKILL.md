---
name: opentouryo-common
description: "TODO: このスキルが何をするか + いつ使うかを書く。エージェントはこの description だけを見て起動を判断するため、実際のクラス名・メソッド名・用語をキーワードとして含めること。記述例: OpenTouryo の共通基盤（層をまたぐ横断的関心事）を扱う。ログ出力、認証・認可、構成ファイルを扱う。ログ / 認証 / 認可 / 設定 を伴う作業のときに使う。例外処理は opentouryo-exception を使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

<!--
  ■ スキル執筆の要点
    - 本文は起動時に全文ロードされる。500 行以内、5000 トークン以内が目安。
    - 詳細は references/ へ切り出し、必要になったときだけ読ませる（Progressive Disclosure）。
    - 「TODO:」を検索して埋める。埋まっていない節は削除してよい。
    - 詳細な書き方は docs/authoring.md を参照。

  ■ このスキルの肥大化に注意
    ログ・認証・設定は本来それぞれ独立したトピック。
    分量が増えたら関心事ごとにスキルを分割する
    （例: opentouryo-logging / opentouryo-auth）。
    例外処理は分量と語彙の独立性から opentouryo-exception へ分離済み。
-->

# 共通基盤（横断的関心事）

## このスキルの適用範囲

<!-- TODO: 何を対象とし、何を対象としないかを1〜3行で。境界を明示すると誤起動が減る。 -->

TODO

例外処理はこのスキルでは扱わない。`opentouryo-exception` を参照。

## ログ出力

<!-- TODO: ログの種別、出力先、呼び出し方。 -->

TODO

```csharp
// TODO
```

## 認証・認可

<!-- TODO: 認証方式と、認可チェックの実装箇所。 -->

TODO

## 構成ファイル

<!--
  TODO: 設定の置き場と読み出し方。
  判明している事実（要肉付け）:
    - XML 定義ファイル（SPDefinition.xml / MSGDefinition.xml / TCDefinition.xml /
      SCDefinition.xml / TMInProcessDefinition.xml / TMProtocolDefinition.xml）は
      net48 / .NET 10.0 のどちらでも同じ。
    - app.config は core 系（.NET 10.0）では appsettings.json になる。
      → ランタイム別の差異として書き分ける必要がある。
-->

TODO

## やってはいけないこと

<!-- TODO: 実際に起きた/起きうる誤りを具体的に。理由も添える。 -->

- TODO
