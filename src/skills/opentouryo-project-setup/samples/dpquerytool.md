# 開発支援ツール：DPQuery_Tool（動的パラメタライズドクエリ 試験ツール）

`opentouryo-project-setup` ④ で取り出す **開発支援 GUI ツール**。SQL 定義ファイル
（静的 `.sql` / 動的 `.xml`）を**試験実行**して、動的 SQL の組み立て結果を確認する。
SQL 定義の書き方（タグ・`@` パラメタ・ユーザパラメタ・`PARAM`）は `opentouryo-query-definition`。

## `PARAM` タグとの関係

`.xml` の `<PARAM>`（`.sql` の `/*PARAM* ... *PARAM*/`）は、**このツールで試験実行するときのテスト値定義**で、
**実行時（アプリ本体）には削除される**（`opentouryo-query-definition` の PARAM タグ節）。動的クエリを書いたら
このツールで PARAM を与えて展開結果を確認する、という使い方。

## 置き場所とランタイム

- ソース：**`Frameworks\Tools\DPQuery_Tool`**（`Samples\` ではない。基盤ツリー配下）。
- WinExe（WinForms の GUI）。`AssemblyName` は `OpenTouryo.DPQuery_Tool`。
- net48：`DPQuery_Tool.csproj` / `.sln`（msbuild）。
- .NET 10.0：`DPQuery_ToolCore.csproj` / `.sln`（`net10.0-windows7.0`＝Windows 専用。`dotnet build`）。

## 取り出しと参照張り替え（⑤ と同じ要領）

1. `DPQuery_Tool` フォルダをリポジトリへコピー（例：`Tools\DPQuery_Tool`）。
2. `.csproj` の `OpenTouryo.*` の `HintPath` をベンダ先へ張り替える（相対 `..\` の数は配置に合わせる）。
   - **net48（要注意）**：`packages.config` が無く、**参照はすべて `..\..\Infrastructure\Build\` の HintPath**。
     `OpenTouryo.Public` / `.DamManagedOdp` / `.DamMySQL` に加え **`MySql.Data.dll` /
     `Oracle.ManagedDataAccess.dll` も張り替える**（NuGet 復元されない。→ `references/reference-rewrite.md`）。
     張替先は `..\..\OpenTouryoAssemblies\Build_net48\`（末尾フォルダ名も `Build\`→`Build_net48\` に変わる）。
   - **core**：`OpenTouryo.*` は `..\..\OpenTouryoAssemblies\Build_netcore100\net10.0\` へ。
     3rd-party は `PackageReference` の NuGet 復元に任せる（触らない）。
3. ビルドして起動確認（WinForms なので Windows で実行）。
