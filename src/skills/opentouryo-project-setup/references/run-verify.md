# 実行確認（IIS Express での WebForms スモークテスト）

`opentouryo-project-setup` ⑦「ビルドが通り、実行できることを確認する」の具体手順（net48 Web Forms）。
ビルド成功＝動く、ではない。フレームワーク初期化は `%OT_RESOURCE_ROOT%` から XML 定義・log4net を読むので、
**実行して初めて resource/config 張り替え（⑥）の成否が分かる**。

## 手順

1. **プレーン HTTP ポートで起動して SSL 証明書バインドを回避する。** サンプルの既定は
   `IISUrl=https://localhost:44371/`（SSL）で、証明書が無いと詰まる。`http` ポートを指定して起動する：

   ```
   iisexpress.exe /path:"<repo>\WebForms_Sample" /port:8080 /clr:v4.0
   ```

2. **`OT_RESOURCE_ROOT` を iisexpress プロセスへ確実に渡す。** User スコープ環境変数は新規プロセスに
   継承されるが、`SetEnvironmentVariable(...,'User')` の直後は同一セッションにまだ載っていないことがある。
   **起動コマンドで明示する**と確実：

   ```powershell
   $env:OT_RESOURCE_ROOT = "<repo>\resource"
   & $iisexpress /path:"<repo>\WebForms_Sample" /port:8080 /clr:v4.0
   ```

## スモークテスト対象と判定

- `Aspx/Framework/Ping.aspx` … 未認証で **302**（→ login へ）。正常。
- `Aspx/start/login.aspx` … **200** でログインフォームが描画されれば OK。
- **500 が出たら resource パス／config 解決の失敗を疑う**（フレームワーク初期化で XML 定義・log4net を
  `%OT_RESOURCE_ROOT%` から読む＝ここが実行時検証の勘所。⑥ / `references/resource-config.md`）。
