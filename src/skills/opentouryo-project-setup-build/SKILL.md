---
name: opentouryo-project-setup-build
description: "OpenTouryo の基盤（フレームワーク）DLL をローカルでビルドし、導入リポジトリの OpenTouryoAssemblies\\ へベンダするための手順。GitHub から指定 <ref>（固定タグ または develop）の ZIP を取得し、root/programs/CS の 2_/3_Build_* バッチを標的ランタイム分だけ実行して、Build_net48 / Build_netcore100 をベンダする。この Download→Build→ベンダを1本のセットアップ スクリプトに生成して実行する（.bat より PowerShell ラッパを推奨。非対話実行の落とし穴を回避）。net48 / .NET 10.0 両対応。基盤ビルド / DLL 生成 / アセンブリのベンダ / OpenTouryoAssemblies / タグ更新で焼き直し / 再ビルド を伴う作業のときに使う。新規立ち上げ全体は opentouryo-project-setup（このスキルはその ③ の実装）、親クラス2 のカスタマイズは opentouryo-base2-customize。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 基盤 DLL のビルドとベンダ

## このスキルの適用範囲

**OpenTouryo の基盤（フレームワーク）DLL をローカルでビルドし、導入リポジトリの
`OpenTouryoAssemblies\` へベンダする**とき。`opentouryo-project-setup` の ③（新規立ち上げの一工程）
として呼ばれるほか、**タグ更新時の焼き直し**にも単独で使える。**1回実行すれば DLL は再利用でき**、
毎回ビルドする必要はない。

**ZIP 取得 → 基盤ビルド → `OpenTouryoAssemblies\` へベンダ**の3段を、**1本のセットアップ スクリプトに
生成して実行する**（その場限りのコマンド羅列にしない。再現・レビュー可能にし、リポジトリに残して
再セットアップに使う）。模範：MultiPurposeAuthSite の `root/programs/3_BuildLibsAtOtherRepos.bat`
（固定タグ）/ `3_BuildLibsAtOtherReposInTimeOfDev.bat`（develop）。

### 入力

| 入力 | 意味 |
| --- | --- |
| `<ref>` | 取得元。**固定タグ**（例 `03-20`＝安定運用）または **`develop`**（最新追従）。呼び出し元／ユーザが決める |
| 標的ランタイム | net48 / .NET 10.0 / 両方。**選んだサンプルが対象とするランタイムだけ**をビルドする |
| `base2-overlay/` の有無 | 親クラス2 をカスタマイズしているか（あれば固定タグ必須。後述） |

## 1. ZIP 取得（`git clone` ではない）

PowerShell の `WebClient.DownloadFile()` で
`https://github.com/OpenTouryoProject/OpenTouryo/archive/<ref>.zip` を取得し、
**リポジトリ直下の作業ツリー `Temp\OpenTouryo-<ref>\`** に展開する
（この `Temp\` は基盤ソースを含むビルド用の作業場。`.gitignore` で除外する ← `opentouryo-project-setup` ⑦）。

## 2. 基盤ビルド

展開先の `...\root\programs\CS\` で `2_/3_Build_*` バッチを順に実行する。
**標的サンプルのランタイムのバッチだけ**を回す（無駄なビルドと失敗面を増やさない）：

```
# net48 標的（例：Web Forms / net48 MVC / net48 2CS）はこの2本だけ
call .\2_Build_NuGet_net48.bat    < nul
call .\3_Build_Business_net48.bat < nul

# .NET 10.0 標的はこの2本だけ
call .\2_Build_NuGet_netcore100.bat    < nul
call .\3_Build_Business_netcore100.bat < nul
```

**両ランタイムに対応させる標的のときだけ4本すべて**を回す。前提ツール：**VS Build Tools**
（net48 は非 SDK csproj で msbuild が要る）と **.NET SDK**（core は `dotnet build`）。
**このバッチ名（net48 / netcore100）が正**。本体の `99_BuildLibsAtOtherRepos*.bat` は陳腐化して
`net45`〜`netcore30` を呼ぶので**参考にしない**。

### エージェント/CI では PowerShell ラッパを既定にする（推奨）

スクリプトは `.bat` でも PowerShell でもよいが、**非対話実行では PowerShell ラッパを既定に推奨**する
（子の基盤ビルド `.bat` は `cmd /c` で呼ぶ）。下記の落とし穴（`pause` / ASCII / `.\` / 括弧 / MSYS パス変換）を
一括で避けられる。**Bash/MSYS から `cmd //c ".\x.bat"` で叩くのは避ける**（次項）。

### 生成スクリプトの実環境での注意（非対話実行で顕在化。実機検証済み）

- **末尾 `pause`** — バッチ末尾に `pause` があり、非対話だと入力待ちで止まる → `< nul` で標準入力を塞ぐ。
- **`.\` を明示** — `NoDefaultCurrentDirectoryInExePath=1` の環境では `.\` 無しの `call` が「認識されない」で失敗。
- **.bat のコメント／`echo` は ASCII 限定** — UTF-8（`chcp 65001`）だと全角コメント行を `cmd` が破損させ、`%変数%` 展開ごと壊す。
- **`if(...)` ブロック内 `echo` の未エスケープ `)`** — ブロックが早期に閉じ、後続の `goto :error` が無条件実行される
  （＝ビルド成功でも Step 3 で必ず失敗して見える）。`echo` 内の `)` は `^)` にエスケープする。
- **Bash/MSYS 経由の `cmd //c ".\x.bat"`** — Windows 絶対パス引数が MSYS に変換され、`cmd` の `if exist "D:\..."` が
  実在フォルダを MISSING と誤判定する。**PowerShell の `cmd /c` から実行する**と正常（上の推奨）。

### VS のエディション・バージョンによる msbuild 解決（利用側で対処する）

本体の `z_Common.bat` は msbuild 検出で **VS18 系は `18\Community` しか見ない**（VS2022 までは
Community/Professional/Enterprise を網羅）。VS18 の BuildTools/Professional/Enterprise だけの環境だと
`BUILDFILEPATH` が空になり基盤ビルドが失敗する。**本体はエージェント/CI や新しい VS エディションでの
非対話ビルドまでは想定していない**ので、これは本体の不具合ではなく**利用側（このセットアップ）で対処する前提**：
ビルド前に msbuild が解決できることを確かめ、解決できなければ Community を入れる／msbuild のパスを通す
／`z_Common.bat` に自環境のパスを補う、などで通す。

### 親クラス2 をカスタマイズしている場合

リポジトリに `base2-overlay/` があるなら、`3_Build_Business_*` の**前に**オーバーレイを展開ツリーへ上書きする
（`xcopy /Y /E base2-overlay\* <extract>\root\programs\CS\`）。この場合、取得元 `<ref>` は**固定タグ**にする
（`develop` は土台が動いて再現性を失う。`opentouryo-base2-customize`）。カスタマイズが無ければ不要。

## 3. ベンダ

生成物を導入リポジトリへコピーする（`xcopy /Y /E`）。**コピー元の起点は展開先の `root\programs\CS\` 配下**
（`Build_*` はここに生成される。起点を省くと存在しないパスになる）。

```
<extract>\root\programs\CS\Frameworks\Infrastructure\Build_net48      → <repo>\OpenTouryoAssemblies\Build_net48\
<extract>\root\programs\CS\Frameworks\Infrastructure\Build_netcore100 → <repo>\OpenTouryoAssemblies\Build_netcore100\
```

（`<extract>` は手順1の `Temp\OpenTouryo-<ref>`。）**1回実行すれば DLL は再利用できる**（毎回ビルドしない）。

## やってはいけないこと

- **`git clone` で取ってくる** — ZIP 取得（`archive/<ref>.zip`）にする。作業ツリーはコミットしない
- **標的でないランタイムまでビルドする** — 標的サンプルのランタイム分だけ回す（両対応が要るときだけ4本）
- **アドホックなコマンド羅列で済ませる** — スクリプト化してリポジトリに残す
- **作業ツリー `Temp/`（基盤ソース＝親クラス2 を含む）をコミットする** — `.gitignore` で除外
- **`base2-overlay` があるのに `develop` で焼く** — 固定タグにする（再現性）
