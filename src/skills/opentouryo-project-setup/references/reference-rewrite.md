# 参照（HintPath）張り替えの注意点

`opentouryo-project-setup` ⑤ の詳細。核心（`Reference Include="OpenTouryo.*"` の `HintPath` を
ベンダ先へ書き換える）は SKILL.md ⑤、ここは**間違えやすい edge case**をまとめる。

## 接頭辞だけでは済まない（末尾フォルダ名も変わる）

net48 サンプルの元 HintPath は `…\Frameworks\Infrastructure\Build\`（サフィックス無し）だが、
ベンダ先は `…\OpenTouryoAssemblies\Build_net48\`。**単純な接頭辞置換ではなく、末尾フォルダ名も変わる**
（`…\Build\` → `…\OpenTouryoAssemblies\Build_net48\`）。core は `…\Build_netcore100\net10.0\`。

## 張り替え対象は「ベンダ先 `Build_*\` に含まれる DLL すべて」（`OpenTouryo.*` だけではない）

例：net48 サンプルの `MySql.Data` / `Oracle.ManagedDataAccess` は **`packages.config` に無く**、
HintPath が他サンプルのビルド出力（`..\..\..\WS_sample\Build\...`）を指すため **NuGet では復元されない**。
これらは基盤のビルド出力 `Build_net48\` に同梱される（`OpenTouryo.DamMySQL` / `.DamManagedOdp` が依存）ので、
`OpenTouryo.*` と同様にベンダ先へ張り替える。**触らないのは NuGet 復元される 3rd-party だけ**
（net48＝`packages.config`、core＝`PackageReference`）。

## 深いリポは MAX_PATH(260)

`Samples\WebApp_sample\...` の相対配置を保つと、`nuget restore` がパッケージ内部の深いパス
（`packages\...\analyzers\...\pt-BR\...`）で超過して失敗する（実測）。**取り出したプロジェクトをリポ直下へ
フラット化**し、相対 `HintPath`（`OpenTouryo.*`・WS 参照とも）を新配置に合わせて張り替える
（`long path` 有効化でも可）。WS 参照を含む3層サンプルのフラット化は `samples/webservices.md`。
