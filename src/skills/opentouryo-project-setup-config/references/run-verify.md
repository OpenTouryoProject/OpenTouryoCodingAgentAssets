# 実行確認（IIS Express での WebForms スモークテスト）

`opentouryo-project-setup-config` ⑦「ビルドが通り、実行できることを確認する」の具体手順（net48 Web Forms）。
ビルド成功＝動く、ではない。フレームワーク初期化は `%OT_RESOURCE_ROOT%` から XML 定義・log4net を読むので、
**実行して初めて resource/config 張り替え（⑥）の成否が分かる**。

## 手順

1. **プレーン HTTP ポートで起動して SSL 証明書バインドを回避する。** サンプルの既定は
   `IISUrl=https://localhost:44371/`（SSL）で、証明書が無いと詰まる。`http` ポートを指定して起動する：

   ```
   iisexpress.exe /path:"<repo>\WebForms_Sample\WebForms_Sample" /port:8080 /clr:v4.0
   ```

   **`/path` は Web ルート＝`Web.config` があるフォルダを指す**（実測で 1 階層ずれやすい）。WebForms サンプルは
   `.sln` が外側 `WebForms_Sample\`、**`Web.config` は内側 `WebForms_Sample\WebForms_Sample\`** にある
   （`build-app.ps1` の sln パス `…\WebForms_Sample\WebForms_Sample.sln` は外側＝別階層）。外側を `/path` にすると
   `Web.config` の無い階層を配信して詰まる。

2. **`OT_RESOURCE_ROOT` を iisexpress プロセスへ確実に渡す。** User スコープ環境変数は新規プロセスに
   継承されるが、`SetEnvironmentVariable(...,'User')` の直後は同一セッションにまだ載っていないことがある。
   **起動コマンドで明示する**と確実：

   ```powershell
   $env:OT_RESOURCE_ROOT = "<repo>\resource"
   & $iisexpress /path:"<repo>\WebForms_Sample\WebForms_Sample" /port:8080 /clr:v4.0   # Web.config のある内側
   ```

## スモークテスト対象と判定

- `Aspx/Framework/Ping.aspx` … 未認証で **302**（→ login へ）。正常。
- `Aspx/start/login.aspx` … **200** でログインフォームが描画されれば OK。
- **500 が出たら resource パス／config 解決の失敗を疑う**（フレームワーク初期化で XML 定義・log4net を
  `%OT_RESOURCE_ROOT%` から読む＝ここが実行時検証の勘所。⑥ / `references/resource-config.md`）。

## core（net10.0）＝ Kestrel（`dotnet run`）

core は IIS Express ではなく Kestrel。**`dotnet run` は `Properties\launchSettings.json` の `applicationUrl` を優先する**ため、
`ASPNETCORE_URLS` を環境変数で与えても**無視される**ことがある（実測：`5080` を渡したが profile の `5219` で起動）。
ポートを固定するには：

- `dotnet run --urls http://localhost:5080`（または `--launch-profile <名>` でプロファイルを明示）
- あるいは **launchSettings のポート（`http` プロファイルの `applicationUrl`）をそのまま使う**（そこに出るポートで開く）

```powershell
$env:OT_RESOURCE_ROOT = "<repo>\resource"   # dotnet run を起こすシェルで設定してから実行
dotnet run --project "<repo>\MVC_Sample_Core\MVC_Sample" --urls http://localhost:5080
```

スモークは net48 と同様（未認証で 302→login、login 200、500＝resource/config 解決失敗）。**core は `InitConfiguration()` 必須**（⑦）。

## デスクトップ（WinForms / WPF・2CS・リッチクライアント）＝ exe

Web ではないので HTTP スモークは無い。**exe を起動してプロセスが生存する（起動時クラッシュしない）ことを確認**する
（初期化で resource/config・log4net を読むため、設定ミスは起動時例外として出る＝ここが検証点）。

**合格基準**：exe を **`OT_RESOURCE_ROOT` を渡して起動**し、**数秒（目安 5–7s）プロセスが生存**して初期画面
（ログイン等）が出れば **startup OK**（初期化＝resource/config 解決を通過）。起動直後に異常終了・未処理例外ダイアログは
**NG**＝resource/config・参照解決の失敗を疑う（stderr / イベントログ）。
**DB 依存操作は条件付き**（`SqlTextFilePath` の SQL 実行・接続文字列先の SQL Server(Northwind) 等）：**DB があれば
結果（件数など）まで確認する**／**無ければ対象外**（未起動の失敗は Web の `/Ping`・Crud の DB 前提タイムアウトと同扱いで、
セットアップの不備ではない）。DB は選択式 `opentouryo-project-setup-db` で立てられる（既定が SQL Server/Northwind と一致）。

- exe の場所：net48＝`bin\Debug\<app>.exe`、core＝`bin\Debug\net10.0-windows7.0\<app>.exe`（`dotnet run --project <proj>` でも可）。
- **非対話チェック**（起動生存を機械判定）：

  ```powershell
  $env:OT_RESOURCE_ROOT = "<repo>\resource"
  $p = Start-Process "<exe>" -PassThru
  Start-Sleep -Seconds 6
  if ($p.HasExited) { throw "起動直後に終了（startup NG）＝resource/config を確認" }
  $p.Kill()   # 生存＝startup OK
  ```

- **3層リッチクライアント（`WSClient_*`）は WS ホスト側の起動も要る**：WS ホスト＝`WS_sample\ServiceInterface`
  （既定 `ASPNETWebService`＝クライアントが `TMProtocolDefinition2` を使用）を **IIS Express で起動**
  してからクライアント exe を起動し、WS 越し（`protocol="2"`）に呼べることを確認する。ホストの引き込み・張替は
  `opentouryo-project-setup-core` の `samples/webservices.md`（③ WS ホスト節）。ホスト未起動ならインプロセス兼用で開ける。

## バッチ / CLI（コンソール）＝ exe（引数あり）

- **実行前にサンプルの `readme.txt` で必要なコマンド引数を確認する。** バッチ/CLI は**引数必須**のことがあり、
  無引数だと `Program.cs` の `argsDic["/DAP"]` 等で **`KeyNotFoundException`**（一見「実行失敗」だが実体は引数不足）。
  例：`SimpleBatch_sample` は `readme.txt` に `/Dap SQL /Mode1 individual /Mode2 static /EXROLLBACK -`
  （`RerunnableBatch_sample` は引数不要）。
- **DB スキーマ前提も確認する（サンプル同梱の `CREATE *.sql` を探して適用）。** 例：`RerunnableBatch_sample` は
  Northwind に **`ORDERS2` テーブルが必要**（同梱 `CREATE ORDERS2.sql`）。`opentouryo-project-setup-db` が立てる
  Northwind に**サンプル固有の追加テーブルは含まれない**＝同梱 SQL を別途流す。
- **合格基準**：引数を与えて起動し、**framework 初期化（log4net 等）＋業務ロジック到達＝OK**（標準出力に処理結果、
  例「3件のデータがあります」）。**DB があれば結果（件数）まで確認**／無ければ初期化＋到達まで（上の「DB 依存は条件付き」）。
- **★ exit code で判定しない。** サンプルは末尾で `Console.ReadKey()` を呼ぶため、**非対話（stdin リダイレクト）だと
  成功分岐でも `InvalidOperationException` で exit code が非ゼロ**（`0xE0434352` / -532462766）になる（業務処理は
  成功済み＝サンプルコード都合。`SimpleBatch`/`RerunnableBatch` 系共通・**net48/net10.0 両ランタイムで実測**）。
  **成否は標準出力で判定**する（`< nul` で stdin を与えても ReadKey 例外は避けられない。出力で見る）。
- **★ 認証付き CLI（`DAG_Login_CLI`/`LIR_Login_CLI`）の非対話スモークは `--help`（exit 0）で見る。** 引数無しの既定
  （RootCommand）ハンドラは `Prompt.Confirm(...)`（Sharprompt）で**対話待ちにブロック**し、`login` サブコマンドは
  **IdP（`MultiPurposeAuthSite:44300`）稼働が前提**。よって実 OAuth フローはセットアップ範囲外＝到達点は「ビルド＋`--help` OK」まで。

