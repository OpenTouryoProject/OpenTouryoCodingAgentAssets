# 開発支援ツール：DaoGen_Tool（墨壺 ＝ D層自動生成ツール）

`opentouryo-project-setup` ④ で取り出す **開発支援 GUI ツール**。テーブル定義から
**自動生成Dao**（`DaoXxx : MyBaseDao`。`DaoShippers` 等）を生成する。生成物の使い方は
`opentouryo-dao-generated`、系統の選び方は `opentouryo-layer-d`。**手書きせず、テーブル定義が
変わったらこのツールで再生成する**のが前提なので、プロジェクトに取り出しておく。

## 置き場所とランタイム

- ソース：**`Frameworks\Tools\DaoGen_Tool`**（`Samples\` ではない。基盤ツリー配下）。
- WinExe（WinForms の GUI）。`AssemblyName` は `OpenTouryo.DaoGen_Tool`。
- net48：`DaoGen_Tool.csproj` / `.sln`（msbuild）。
- .NET 10.0：`DaoGen_ToolCore.csproj` / `.sln`（`net10.0-windows7.0`＝Windows 専用。`dotnet build`）。

標的サンプルのランタイムに合わせてどちらかを使えばよい（DAO 生成が目的なので net48 版だけでも足りる）。

## 取り出しと参照張り替え（⑤ と同じ要領）

1. `DaoGen_Tool` フォルダをリポジトリへコピー（例：`Tools\DaoGen_Tool`）。
2. `.csproj` の `OpenTouryo.*` の `HintPath` をベンダ先へ張り替える（相対 `..\` の数は配置に合わせる）。
   - **net48（要注意）**：`packages.config` が無く、**参照はすべて `..\..\Infrastructure\Build\` の HintPath**。
     `OpenTouryo.Public` に加え **`MySql.Data.dll` / `Oracle.ManagedDataAccess.dll` も張り替える**
     （NuGet 復元されない。→ `references/reference-rewrite.md` の「Build_* の DLL 全部が対象」）。
     張替先は `..\..\OpenTouryoAssemblies\Build_net48\`（末尾フォルダ名も `Build\`→`Build_net48\` に変わる）。
   - **core**：`OpenTouryo.*`（`Public` / `DamManagedOdp` / `DamMySQL` / `DamPstGrS`）は
     `..\..\OpenTouryoAssemblies\Build_netcore100\net10.0\` へ。3rd-party は `PackageReference` の NuGet 復元に任せる（触らない）。
3. ビルドして起動確認（WinForms なので Windows で実行）。

## 使い方の要点

- DB に接続してテーブルを選び、**自動生成Dao のソースを出力**する（出力したソースをプロジェクトの D層へ入れる）。
- 生成物の命名体系（`S1_Insert`/`D2_Select` 等、`PK_列名`/`Set_列名_forUPD` 等）と楽観排他は `opentouryo-dao-generated`。
- SELECT を含む INSERT/UPDATE は自動生成の対象外（個別Dao ＝ `opentouryo-dao-custom`）。
