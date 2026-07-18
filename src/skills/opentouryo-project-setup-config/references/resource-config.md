# リソース移設と config パス張り替えの詳細

`opentouryo-project-setup-config` ⑥ の詳細。**Fx キー全般・`FxContainerization`（設定値まるごとを環境変数で
上書きする別機構）・`GetConfigParameter` は `opentouryo-config`**。ここは「サンプルの絶対パスを、可搬な
`%OT_RESOURCE_ROOT%\...` に張り替える」やり方に絞る。

## なぜ相対パス不可・環境変数方式か

**相対パス（`resource\...`）は使えない。** フレームワークは設定値を**フルパス前提**でファイル API
（`File.Exists` 等）に渡すため、相対パスは**実行プロセスのカレント ディレクトリ基準**で解決される。
IIS Express / w3wp のカレントはアプリ フォルダではないので、相対パスは原理的に解決できない
（`ResourceLoader.Exists` → `System.ArgumentException: リソースファイル…は見つかりませんでした` で 500）。

代わりに、`ResourceLoader` が**パス解決の直前に展開する `%環境変数%`** を使う
（`StringVariableOperator.BuiltStringIntoEnvironmentVariable`）。マシン固有の絶対パスを config に残さずに済み、
可搬になる。SQL 定義（`MyBaseDao.SetSqlByFile2` → `ResourceLoader`）も同じ経路で効く。

※ これは `opentouryo-config` の `FxContainerization`（キーの**値まるごと**を環境変数で置換）とは別機構。
こちらは**パス文字列の中の `%VAR%` だけ**を展開する。

## パス系キー一覧（`%OT_RESOURCE_ROOT%` へ張り替える対象）

| キー | 参照先 |
| --- | --- |
| `FxLog4NetConfFile` | `%OT_RESOURCE_ROOT%\Log\SampleLogConf.xml` |
| `FxXMLSPDefinition` / `FxXMLMSGDefinition` / `FxXMLSCDefinition` / `FxXMLTCDefinition` / `FxXMLTMProtocolDefinition` / `FxXMLTMInProcessDefinition` | `%OT_RESOURCE_ROOT%\Xml\*.xml`（XML 定義） |
| `SqlTextFilePath` | `%OT_RESOURCE_ROOT%\Sql`（SQL 定義フォルダ） |
| `SpRp_RsaCerFilePath` | `%OT_RESOURCE_ROOT%\X509\*.cer`（OAuth2 用証明書） |

**`OT_RESOURCE_ROOT` はリポジトリ直下の `resource\` を指す環境変数**（変数名は任意。この例に統一）。
**セットアップ スクリプトで設定する**（ユーザ環境変数 `OT_RESOURCE_ROOT = <repo>\resource`）と、
クローンし直しても再実行で張り直せる。設定後は IIS Express / プロセスの再起動で反映する。

## ★ ログ定義（`resource\Log\*.xml`）の中の出力先パスも張り替える（見落とし注意・実測）

`FxLog4NetConfFile` で**ログ定義ファイルのパス**を `%OT_RESOURCE_ROOT%\...` にしても不十分。**ログ定義ファイルの
中身**（例 `SampleLogConf.xml`）の各 appender が**絶対の出力先**を持つ：

```xml
<param name="File" value="C:\root\files\resource\Log\ACCESS" />   <!-- ACCESS / SQLTRACE / OPERATION 各 appender -->
```

**この `File` の値を張り替えないと、ログは旧 `C:\root\files\...` へ出続ける（または出力できない）。**

**注意：ここに `%OT_RESOURCE_ROOT%` をそのまま書いても展開されない。** OpenTouryo が `%VAR%` を展開するのは
**ログ定義ファイルの「パス」だけ**（`LogManager_log4net` はファイルを生ストリームで開いて `XmlConfigurator` に渡す＝
中身は展開しない）。log4net も素の `<param name="File" value="%OT_RESOURCE_ROOT%\...">` は展開しない。
→ **log4net の `PatternString` で環境変数を展開させる**（`<param name="File">` を型付き `<file>` に置き換える）：

```xml
<file type="log4net.Util.PatternString" value="%env{OT_RESOURCE_ROOT}\Log\ACCESS" />
```

`%env{OT_RESOURCE_ROOT}` が実行時に展開される（`OT_RESOURCE_ROOT` はプロセスへ渡す＝`run-verify.md`）。
環境変数方式を使わず**移設先の絶対パスへ直接書き換える**のでも動くが、可搬性は失われる。

## 綴りの罠（`Xml` / `Test`）

config の綴りは実フォルダと一致していないことがある。net48 サンプルの app.config は `resource\XML\...`（大文字）・
`resource\test`（小文字）だが、実フォルダは `Xml` / `Test`。Windows は大文字小文字を区別しないので顕在化しないが、
**Linux で core を動かすなら実フォルダの綴り（`Xml` / `Test` 等）に config を合わせて直す**
（フォルダを config に合わせるのではない）。

## net48 Web Forms は config が二段構成

実効 config は `Web.config` だが、**パス系キーは `<appSettings file="app.config"/>` で読む `app.config` 側**、
接続文字列は `Web.config` 直下。パス系キーの張り替えは `app.config` を開く（詳細は `samples/webforms.md`）。
core はキーが `appsettings.json` に集約される。
