# セットアップ スクリプトの詳細（③ の実装リファレンス）

`opentouryo-project-setup` ③「セットアップ スクリプトを生成して実行」の詳細。
**ZIP 取得 → 基盤ビルド → `OpenTouryoAssemblies\` へベンダ**の3段を、1本のスクリプト
（`.bat` か PowerShell）にまとめて生成し、実行する。生成物はリポジトリに残し、再セットアップに使う。

模範：MultiPurposeAuthSite の `root/programs/3_BuildLibsAtOtherRepos.bat`（固定タグ）/
`3_BuildLibsAtOtherReposInTimeOfDev.bat`（develop）。`<ref>` は②でユーザが選んだ取得元。

## 1. ZIP 取得（`git clone` ではない）

PowerShell の `WebClient.DownloadFile()` で
`https://github.com/OpenTouryoProject/OpenTouryo/archive/<ref>.zip` を取得し、
**リポジトリ直下の作業ツリー `Temp\OpenTouryo-<ref>\`** に展開する
（この `Temp\` は基盤ソースを含むビルド用の作業場。⑦の `.gitignore` で除外する）。

## 2. 基盤ビルド

展開先の `...\root\programs\CS\` で、**4つのバッチを順に実行する**。
非対話（エージェント/CI）で嵌らないよう、呼び出しは **`call .\<bat> < nul` の形**にする（後述の注意）：

```
call .\2_Build_NuGet_net48.bat        < nul
call .\3_Build_Business_net48.bat     < nul
call .\2_Build_NuGet_netcore100.bat   < nul
call .\3_Build_Business_netcore100.bat < nul
```

前提ツール：**VS Build Tools**（net48 は非 SDK csproj で msbuild が要る）と
**.NET SDK**（core は `dotnet build`）。**このバッチ名（net48 / netcore100）が正**。
本体の `99_BuildLibsAtOtherRepos*.bat` は陳腐化して `net45`〜`netcore30` を呼ぶので**参考にしない**。

### 生成スクリプトの実環境での注意（非対話実行で顕在化。実機検証済み）

- **末尾 `pause`** — 4バッチとも末尾に `pause` があり、非対話だと入力待ちで止まる → `< nul` で標準入力を塞ぐ。
- **`.\` を明示** — `NoDefaultCurrentDirectoryInExePath=1` の環境では `.\` 無しの `call` が「認識されない」で失敗。
- **.bat のコメント／`echo` は ASCII 限定** — UTF-8（`chcp 65001`）だと全角コメント行を `cmd` が破損させ、`%変数%` 展開ごと壊す。

### VS のエディション・バージョンによる msbuild 解決（利用側で対処する）

本体の `z_Common.bat` は msbuild 検出で **VS18 系は `18\Community` しか見ない**（VS2022 までは
Community/Professional/Enterprise を網羅）。VS18 の BuildTools/Professional/Enterprise だけの環境だと
`BUILDFILEPATH` が空になり基盤ビルドが失敗する。**本体はエージェント/CI や新しい VS エディションでの
非対話ビルドまでは想定していない**ので、これは本体の不具合ではなく**利用側（このセットアップ）で対処する前提**：
ビルド前に msbuild が解決できることを確かめ、解決できなければ Community を入れる／msbuild のパスを通す
／`z_Common.bat` に自環境のパスを補う、などで通す。

### 親クラス2 をカスタマイズしている場合

リポジトリに `base2-overlay/` があるなら、`3_Build_Business_*` の**前に**オーバーレイを展開ツリーへ上書きする
（`xcopy /Y /E base2-overlay\* <extract>\root\programs\CS\`）。この場合、取得元は**固定タグ**にする
（`opentouryo-base2-customize`）。カスタマイズが無ければ不要。

## 3. ベンダ

生成物を導入リポジトリへコピーする（`xcopy /Y /E`）。**コピー元の起点は展開先の `root\programs\CS\` 配下**
（`Build_*` はここに生成される。起点を省くと存在しないパスになる）。

```
<extract>\root\programs\CS\Frameworks\Infrastructure\Build_net48      → <repo>\OpenTouryoAssemblies\Build_net48\
<extract>\root\programs\CS\Frameworks\Infrastructure\Build_netcore100 → <repo>\OpenTouryoAssemblies\Build_netcore100\
```

（`<extract>` は手順1の `Temp\OpenTouryo-<ref>`。）

**1回実行すれば DLL は再利用できる**（毎回ビルドしない）。
