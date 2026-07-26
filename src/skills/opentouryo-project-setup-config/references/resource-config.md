# リソース移設と config パス張り替え（詳細）

`opentouryo-project-setup-config` ⑥ の詳細。Fx キー全般・`FxContainerization`（値まるごとを環境変数で上書きする別機構）・
`GetConfigParameter` は `opentouryo-config`。

## 原則（3つ）

1. **Resource を指す絶対パスは環境変数に張り替える。** 対象は .NET 設定ファイル（`*.config` / `appsettings.json`）と
   **LOG 系設定ファイル（`*.xml`）の中の絶対パス**。マシン固有パスを config に残さず可搬にする。
2. **`OT_RESOURCE_ROOT` が既設（別プロジェクトが使用中）なら奪い合わず番号を付ける**（`%OT_RESOURCE_ROOTn%`。例 `%OT_RESOURCE_ROOT1%`）。
   ユーザ環境変数はマシンで1つなので、別リポジトリの `resource\` を指したまま上書きすると相手が壊れる。
3. **一部の設定は正しくなくても（空値でも）アプリは起動する。** 「起動した＝設定が正しい」ではない。起動可否と設定の正しさは分けて確認する
   （例：ログ出力先が旧パスのままでも起動する＝下記）。

`OT_RESOURCE_ROOT`（またはその番号付き）＝リポジトリ直下の `resource\`。**ユーザ環境変数はマシン/ユーザ全体に残る＝`SETUP-CHANGES.md` に記録。**
**検証だけなら User 変数を変えず、プロセス限定上書き**（`$env:OT_RESOURCE_ROOT="<repo>\resource"` を起動コマンドで＝`run-verify.md`）で足り、記録も不要。

## パス系キー（張り替える対象）

| キー | 参照先 |
| --- | --- |
| `FxLog4NetConfFile` | `%OT_RESOURCE_ROOT%\Log\SampleLogConf.xml`（ログ定義ファイルの**場所**） |
| `FxXMLSPDefinition` / `FxXMLMSGDefinition` / `FxXMLSCDefinition` / `FxXMLTCDefinition` / `FxXMLTMProtocolDefinition` / `FxXMLTMInProcessDefinition` | `%OT_RESOURCE_ROOT%\Xml\*.xml` |
| `SqlTextFilePath` | `%OT_RESOURCE_ROOT%\Sql`（**※同梱型は例外＝下記**） |
| `SpRp_RsaCerFilePath` | `%OT_RESOURCE_ROOT%\X509\*.cer` |

## 相対パスは不可

フレームワークは設定値を**フルパス前提**でファイル API に渡す。相対パス（`resource\...`）は実行プロセスの CWD 基準で解決され、
IIS Express / w3wp の CWD はアプリ フォルダでないため 500 になる。`ResourceLoader` が**パス解決直前に展開する `%環境変数%`** を使う。

## ★ 例外：SQL 同梱の自己完結型サンプル（`.\Dao`）は張り替えない

`SqlTextFilePath` が `.` 始まりの相対（net48 `.\Dao`／core `./Dao`）で、csproj が `Dao\*.sql/.xml` を `CopyToOutputDirectory`
しているなら**意図的な自己完結型＝そのまま残す**（`%OT_RESOURCE_ROOT%\Sql` に書き換えると SQL が無く逆に壊れる。例 `RerunnableBatch_sample`）。
コンソール exe を出力フォルダから実行する前提。

## ログ出力先（`SampleLogConf.xml` の中身）— 原則1だが起動は妨げない（原則3）

各 appender の出力先 `<param name="File" value="C:\root\files\resource\Log\ACCESS"/>` を `%OT_RESOURCE_ROOT%\Log` へ揃えるのが原則1。
ただし**張り替えなくても起動する**（ログが旧パスへ出る／無ければ log4net が黙って出さないだけ。as-built：`WORKSPACE` も既定のまま稼働）＝原則3。
**注意：ここでは `%OT_RESOURCE_ROOT%` は展開されない**（中身は生のまま `XmlConfigurator` へ渡る）。log4net の `PatternString` を使う：

```xml
<file type="log4net.Util.PatternString" value="%env{OT_RESOURCE_ROOT}\Log\ACCESS" />
```

## その他の罠

- **綴り（`Xml` / `Test`）**：net48 app.config は `XML`／`test` だが実フォルダは `Xml`／`Test`。Windows は無視するが、
  **Linux で core を動かすなら config を実フォルダの綴りに合わせる**。
- **net48 Web Forms は config 二段**：パス系キーは `<appSettings file="app.config"/>` の **`app.config` 側**、
  接続文字列は `Web.config` 直下（`samples/webforms.md`）。core は `appsettings.json` に集約。
