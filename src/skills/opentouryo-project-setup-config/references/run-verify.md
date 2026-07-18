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

## core（.NET 10.0）＝ Kestrel（`dotnet run`）

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

**合否基準**：起動して**数秒生存すれば startup OK**（初期化例外を通過）。即時終了・未処理例外ダイアログは NG＝
resource/config を疑う。ログイン/CRUD など**DB 依存操作の合否は SQL Server 前提**なので、DB 未用意なら「起動生存」までで可。

- 起動：net48＝`bin\Debug\<app>.exe`、core＝`dotnet run --project <proj>`（`net10.0-windows7.0`＝Windows 専用）。
- `OT_RESOURCE_ROOT` をプロセスに渡す（未設定だと起動時に resource 解決失敗）。
- **DB 依存操作は SQL Server 前提**（サンプルの接続文字列は SQL Server / Northwind）。ログイン・CRUD を試すなら DB を用意する。
  起動生存だけの確認なら DB は不要なことが多い。
- **3層リッチクライアント（`WSClient_*`）は WS サーバ側の起動も要る**（構成 (A)。`opentouryo-project-setup-core` /
  その `samples/webservices.md`）。
