# minimize — サンプル/テスト画面を除いて最小骨格へ

`opentouryo-project-transform` の subcommand。**セットアップ済みの WebForms サンプルから、動作確認用のテスト/デモ画面を
除いて「業務画面を足していける最小骨格」に落とす。** 出典：as-built（セットアップ済み `WebForms_Sample` を最小化した実測構成）。

## ゴールの姿（最小骨格に残るもの＝実測）

最小化後も**残す**のは「枠組み」だけ。実測の as-built では csproj に次だけが残った：

- **Framework ダイアログ**：`Aspx\Framework\`＝`DialogFrame.htm` / `DialogLoader.htm` / `myOKMessageDialog.aspx` /
  `myYesNoMessageDialog.aspx` / `Ping.aspx`（画面遷移・ダイアログ機構。`opentouryo-webforms-dialog` / `-screen-transition`）。
- **共通画面**：`Aspx\Common\ErrorScreen.aspx`（エラー画面）。
- **開始画面**：`Aspx\start\`＝`login.aspx` / `logout.aspx` / `menu.aspx`。
- **マスタ2枚**：`Aspx\Common\Master\sampleScreen.master`（＝menu の実シェル）と `testBlankScreen.master`（＝login 等の blank）。**下記★トラップ参照＝どちらも残す**。
- **認証系**：`Aspx\OAuth2\OAuth2AuthorizationCodeGrantClient.aspx`（**認証方式次第で残す/削る**。使わないなら削ってよい＝`opentouryo-auth` / `-oauth2-client`）。
- **土台**：`App_Start\{BundleConfig,RouteConfig}.cs`、`Global.asax(.cs)`、`Properties\AssemblyInfo.cs`、
  `Content\` / `Scripts\` / `images\`（bootstrap・jQuery・touryo・WebForms スクリプト等）、`Web.config` / `app.config` / `Bundle.config`、`packages.config`。
- **空フォルダ**：`AppCode\`（業務コードを足す場所）、`App_Data\`。

## 削る対象

- **テスト/デモの content 画面**：`testScreen*`、`sampleScreen.aspx`（＝マスタでなく画面本体）等の動作確認画面。
- **3層（3Tier）画面**とその専用周辺：`Aspx\sample\3Tier\`、`AppCode\sample\3TierTableAdapter\*`、3層専用 B層（`AppCode\sample\Business\GetMasterData.cs` 等）。※WS 依存を含むので、3層を消すときは `ws-decouple` も参照。
- 上記からのみ参照される型・using。

## ★トラップ（名前の接頭辞で機械削除しない＝最優先の注意）

**`test*` / `sample*` という名前でも「実使用」のものがある。** 削除前に、**残す画面の `MasterPageFile` を必ず確認する**。実測：

| マスタ | 名前の印象 | 実態（実測） | 判断 |
| --- | --- | --- | --- |
| `sampleScreen.master` | sample＝消したくなる | **`menu.aspx` の実シェル**（ロゴ・Sign-out・メニュー一覧・`ContentPlaceHolder_A`＋Fx の hidden 群〔`SubmitFlag`/`ChildScreenType` 等〕）。**この版に MButton 系サーバコントロールは無い**（サンプルボタンは既に除去済み） | **残す**（自アプリのメニュー・シェルとして流用／改名） |
| `testBlankScreen.master` | test＝消したくなる | **`login` / `logout` / `ErrorScreen` / `OAuth2` の実マスタ**（blank 系） | **残す** |

- `sampleScreen.master` を単純削除すると **`menu.aspx` が壊れる**（消すなら menu を別マスタへ張り替えるが、shell〔ロゴ・サインアウト・メニュー〕を失う＝通常は残す方が良い）。
- マスタを**改名**したら、`MasterPageFile` 参照と、次項のハンドラ命名（`UOC_<マスタ名>_…`）も揃える。

## MyBaseController の master ハンドラ（DLL 参照時の現実＝重要）

master 上のボタンのハンドラは、命名契約 **`UOC_<マスタ名(拡張子なし)>_<control>_<event>`** で `MyBaseController`（親クラス2）に束ねられる
（例 `UOC_sampleScreen_btnMButton101_Click`。`opentouryo-layer-p-webforms-screen`）。**最小化での扱いは構成で変わる：**

- **基盤を DLL 参照している構成**（例：`OpenTouryoAssemblies\Build_net48\OpenTouryo.Business.dll` を参照）では、
  **`MyBaseController` はプロジェクト外＝アプリ側から編集できない。** master のボタンを消しても、
  **対応ハンドラが基盤 DLL に残るだけ＝対応コントロールが無ければ休眠（呼ばれず実害なし）**。＝**そのままでよい**。
- **どうしても消すなら本体ソース**（`Frameworks\Infrastructure\Business\Presentation\MyBaseController.cs`）を編集して DLL 再ビルド
  ＝**本体（全 WebForms サンプル共有）の変更**。しかも `UOC_TestScreen1/2_*` 等は**他サンプルが使う**ため、
  安易に消すと他サンプルが壊れる。**アプリ最小化の範囲では触らない**（`opentouryo-project-policy`）。
- `MyBaseController` を**自アプリで所有・カスタマイズ**したいなら別作業＝`opentouryo-base2-customize` の領分。

## csproj の剪定（大量エントリ）

**「実在しない `Include` を消す」方式が堅牢**（実測）。ファイルを先に削除し、csproj の `Content` / `Compile` / `None` /
`EmbeddedResource` のうち **`Include` 先が実在しないエントリ**を XML DOM で剪定する（`PreserveWhitespace=true` ＋直前の空白ノード
除去で差分最小。**ワイルドカードと `Reference` 系は除外**）。名前マッチで消すより安全・高速。剪定後も段階ビルドで確認する。

## 進め方（段階ビルド）

1. **まずビルドして現状把握**（何が何に依存するかはビルドエラーが教える）。
2. テスト/デモ画面を削る → **再ビルド** → `CS0246`（型・名前空間が見つからない）を上から潰す。
   - 同名クラスが同梱ソースにある → `using` を差し替える（`ws-decouple` の「罠」参照）。
   - そのコードが 3層専用だった → 削る（`ws-decouple` へ）。
3. csproj を剪定（上記）→ 再ビルド。
4. `MasterPageFile` を確認し、**実使用マスタは残す**（★トラップ）。
5. 認証（OAuth2 等）を使わないなら削る（`opentouryo-auth`）。
