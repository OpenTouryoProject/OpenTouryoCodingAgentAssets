---
name: opentouryo-auth
description: "OpenTouryo で認証済みユーザの情報を保持する。ユーザ情報クラス（UserInfo / MyUserInfo）、UserInfoHandle によるセッションへの格納・取得（SetUserInformation / GetUserInformation / DeleteUserInformation）、.NET の認証との組み合わせ方、ログインから P層・B層へユーザ情報が流れる経路を扱う。P層フレームワークごとの差異（Web Forms と MVC は Forms 認証、ASP.NET Core MVC は Cookie 認証 + ClaimsPrincipal + Startup での構成）と、net48 / .NET 10.0 の API 差も扱う。認証 / ログイン / ログアウト / ユーザ情報 / MyUserInfo / UserInfoHandle / セッション / Forms認証 / Cookie認証 / ClaimsPrincipal / FormsAuthentication を伴う作業のときに使う。"
license: MIT
metadata:
  author: OpenTouryoProject
  version: "0.1.0"
---

# 認証とユーザ情報

## このスキルの適用範囲

**OpenTouryo の認証実装の主眼は「認証済みユーザの情報をどう保持するか」。** 認証そのものの
仕組みは提供せず、Web では **.NET の認証・セッション維持の仕組みと組み合わせて使う**。

このスキルは、その「ユーザ情報の保持」と「.NET の認証との組み合わせ方」を扱う。
OpenTouryo を使う全アプリケーションが対象。

- 認可（権限チェック）→ P層 の親クラス2 に実装箇所がある（P層のスキルを参照）
- 設定値の読み方 → `opentouryo-config`

## ユーザ情報クラス

| 階層 | クラス | 担当 | 中身 |
| --- | --- | --- | --- |
| ユーザ情報親クラス1 | `UserInfo`（`Touryo.Infrastructure.Framework.Util`） | フレームワーク | **空のクラス**。マーカーとしてのみ存在 |
| ユーザ情報親クラス2 | `MyUserInfo`（`Touryo.Infrastructure.Business.Util`） | 纏め者 | `UserName` / `IPAddress` + プロジェクト固有の項目 |

`UserInfo` は本当に `public class UserInfo { }` で中身がない。実体は `MyUserInfo` にある。

```csharp
public class MyUserInfo : UserInfo
{
    public MyUserInfo(string userName, string ipAddress)
    public string UserName { get; }
    public string IPAddress { get; }
}
```

### 項目は提供済み。増やせない

`MyUserInfo` はプロジェクト固有の項目（所属、権限、ロールなど）を持てる設計だが、
**親クラス2 はビルド後のバイナリで提供されるため、ユーザプログラム開発プロジェクトでは
項目を足せない。** 既に定義されている項目を使う。

`MyUserInfo` が持つ項目は P層・B層のどこからでも参照できる。

<!--
  TODO: このプロジェクトに提供されている MyUserInfo が持つ項目を列挙する。
  エージェントはバイナリの中身を読めないため、ここに書いておかないと
  UserName / IPAddress しか無いものとして扱う。
-->

新しい項目が必要に見える場合は、引数クラス（`MyParameterValue` の派生）で渡せないかを
先に検討し、それでも必要なら人に相談すること。

## UserInfoHandle（セッションへの出し入れ）

`UserInfoHandle`（`Touryo.Infrastructure.Framework.Util`）が**セッション**に読み書きする。
セッション キーは `AuthenticationUserInformation`。

| メソッド | 用途 |
| --- | --- |
| `SetUserInformation(userInfo)` | セッションへ格納（ログイン時） |
| `GetUserInformation<T>()` | セッションから取得（**.NET 10.0 専用**） |
| `GetUserInformation()` | セッションから取得（**net48 専用**） |
| `DeleteUserInformation()` | セッションから削除（ログアウト時） |

### 取得 API がランタイムで違う

**同名だがシグネチャが違い、`#if` で切り替わる。** 両対応のコードを書くときの罠。

```csharp
// .NET 10.0（core 系）: ジェネリック版のみ
MyUserInfo ui = UserInfoHandle.GetUserInformation<MyUserInfo>();

// .NET Framework 4.8: 非ジェネリック版のみ。キャストする
MyUserInfo ui = (MyUserInfo)UserInfoHandle.GetUserInformation();
```

内部の保存方式も違う。

| | net48 | .NET 10.0 |
| --- | --- | --- |
| 保存 | `Session[key]` にオブジェクトのまま | **JSON にシリアライズ** |
| 取得 | キャスト | JSON からデシリアライズ |

## ユーザ情報の流れ

```
【ログイン時】アプリケーションのログイン処理
    new MyUserInfo(userName, ipAddress)
    UserInfoHandle.SetUserInformation(ui)      → セッションへ

【リクエストごと】P層の親クラス2（フレームワーク）
    this.UserInfo = UserInfoHandle.GetUserInformation<MyUserInfo>()
                                               → コントローラの UserInfo プロパティへ

【B層呼び出し時】開発者が書く
    new TestParameterValue(..., this.UserInfo) → 引数クラスへ

【B層】
    myPV.User.UserName                         → アクセスログ等で使われる
```

**P層でのセッションからの取り出しはフレームワークが行う。** 開発者は
`this.UserInfo`（コントローラのプロパティ）を引数クラスへ渡すだけ。

## .NET の認証と組み合わせる

**ログインでは2つのことを両方やる。** 片方だけでは動かない。

| | 何をするか | 仕組み |
| --- | --- | --- |
| ① .NET 側 | 認証状態を維持する | ASP.NET Core の Cookie 認証（`ClaimsPrincipal` + `SignInAsync`） |
| ② OpenTouryo 側 | ユーザ情報を保持する | `MyUserInfo` + `UserInfoHandle`（セッション） |

**この2つは別物。** ① は「認証済みかどうか」、② は「フレームワークが使うユーザ情報」。
OpenTouryo は ① を提供しないので、.NET の仕組みを使う。

- ① だけ → 認証は通り、`this.UserInfo` も**認証チケットから復元される**。ただし
  **`UserName` と `IPAddress` しか埋まらない**（後述）
- ② だけ → 認証状態が維持されない

### ユーザ情報は認証チケットから復元される

P層の親クラス2 は、リクエストごとに以下を行う。**3方式とも同じ。**

```
Session が無効 → 何もしない
Session が有効
  UserInfoHandle.GetUserInformation() を試みる
    取れた   → それを使う
    null だった
      認証チケットからユーザ名を取る
        net48 : System.Threading.Thread.CurrentPrincipal.Identity.Name
        Core   : AuthenticateAsync(...).Principal?.Identity?.Name
      ユーザ名が空 → new MyUserInfo("未認証", IP)   ※セッションには入れない
      ユーザ名あり → new MyUserInfo(ユーザ名, IP) + SetUserInformation() で復元
```

**したがって `this.UserInfo` が null になることはない**（セッションが有効なら）。
未認証なら `UserName` が `"未認証"` になる。

**それでもログイン時に `SetUserInformation()` を呼ぶ理由は、復元では `UserName` と
`IPAddress` しか埋まらないため。** プロジェクト固有の項目（所属、権限など）を持たせるには、
ログイン時に完全な `MyUserInfo` を作ってセッションへ入れる必要がある。

親クラス2 の復元処理には「★ 必要であれば、他の業務共通引継ぎ情報などをロードする」という
拡張ポイントがあるが、既定のテンプレートでは実装されていない。**ここを実装するかは
親クラス2 を整備する側の判断**で、ユーザプログラム開発プロジェクトからは変えられない。

### P層フレームワークごとの差異

<!--
  ■ 執筆者向け：この節は P層スキルへ分配する予定（現在このスキルは約5,800トークンで目安5,000を超過）

  分配先:
    「① Web Forms（net48）」の詳細            → opentouryo-layer-p-webforms
    「② MVC（net48）」「③ ASP.NET Core MVC」の詳細 → opentouryo-layer-p-mvc
                                                  （net48 / .NET 10.0 のランタイム差として1スキルに収める）
    ※ リッチクライアント（opentouryo-layer-p-winforms）は未調査。
      MyBaseControllerWin / BaseLogic2CS 系。認証の扱いを別途確認すること。

  このスキルに残すもの:
    - MyUserInfo / UserInfoHandle（3方式で共通・全アプリが対象）
    - ユーザ情報の流れ
    - 「.NET 側の認証」と「OpenTouryo のユーザ情報」の両方が必要という原則
    - 下の比較表（どのスキルを読めばよいかの地図として）
  分配後、各方式の実装例は P層スキル側へ移し、ここからはリンクする。
-->

**② の `MyUserInfo` + `UserInfoHandle` は3方式で共通。① の .NET 側だけが違う。**

| | ① Web Forms（net48） | ② MVC（net48） | ③ ASP.NET Core MVC（.NET 10.0） |
| --- | --- | --- | --- |
| コントローラの基底 | `MyBaseController` | `MyBaseMVController` | `MyBaseMVControllerCore` |
| .NET 側の認証 | **Forms 認証** | **Forms 認証**（①と同じ） | **Cookie 認証** |
| 認証の構成 | `web.config` の `<authentication mode="Forms">` | **①と同じ**（`loginUrl` / `defaultUrl` の値のみ違う） | `Startup.cs` の `AddAuthentication()` + `AddCookie()` |
| サインイン | `FormsAuthentication.RedirectFromLoginPage(userName, false)` | ①と同じ | `ClaimsPrincipal` を作り `SignInAsync()` |
| サインアウト | `FormsAuthentication.SignOut()` | ①と同じ | `SignOutAsync()` |
| 認可（サイト全体） | `web.config` の `<authorization>` に `<deny users="?" />` | **①と同じ** | — （`web.config` が無い） |
| 認可（個別） | `<location path="...">` で**パス単位** | `[Authorize]` / `[AllowAnonymous]` で**コントローラ・アクション単位** | ②と同じ（ただし `AuthenticationSchemes` の指定が要る） |
| IP アドレスの取得 | `Request.UserHostAddress` | ①と同じ | `(new GetClientIpAddress()).GetAddress()` |
| ログイン画面の実装単位 | `login.aspx.cs` の `UOC_btnXXX_Click` | `HomeController.Login` アクション | ②と同じ |

**① と ② は .NET 側の認証がまったく同じ**（Forms 認証、`web.config` の設定も同一）。
違うのは**実装をどこに書くか**（`UOC_btnXXX_Click` かコントローラのアクションか）と、
**個別の認可をどう指定するか**（`<location>` か属性か）。

断層は **net48 と Core の間**にある。Core には Forms 認証も `web.config` も無い。

### ① Web Forms（net48）

**詳細は `opentouryo-layer-p-webforms` を参照。** ログイン画面の実装例、`web.config` の構成を
そちらに記述している。

要点だけ再掲する。

- **Forms 認証**。`web.config` の `<authentication mode="Forms">` + `<authorization>` で設定する
- ログイン画面は `IsNoSession = true` をコンストラクタで設定し、`UOC_FormInit` で
  `FxSessionAbandon()` を呼ぶ
- サインインは `FormsAuthentication.RedirectFromLoginPage(userName, false)`
- 認可はサイト全体が `<authorization><deny users="?" /></authorization>`、
  パス単位の例外は `<location path="...">`

### ② MVC（net48）／③ ASP.NET Core MVC（.NET 10.0）

**詳細は `opentouryo-layer-p-mvc` を参照。** 実装例、`web.config` と `Startup.cs` の構成、
net48 と .NET 10.0 の差をそちらに記述している。

要点だけ再掲する。

- **net48 MVC は Forms 認証**。`web.config` の記述は Web Forms と同一。認可は
  `<authorization>` と `[Authorize]` の二段構え
- **Core MVC は Cookie 認証**。`FormsAuthentication` は存在しない。`ClaimsPrincipal` を作って
  `SignInAsync()` する。`web.config` が無いので認可は属性のみ
- **Core だけ `Startup.cs` での構成が必須**。`services._AddHttpContextAccessor()` /
  `app._UseHttpContextAccessor()` を呼ばないと `UserInfoHandle` が動かない（コンパイルは通る）
- **Core に `Request.UserHostAddress` は無い**。`GetClientIpAddress` を使う


### 認証方式そのものは問わない

パスワード照合でも、外部 IdP から受け取った情報でも、最後に `MyUserInfo` を作って
セッションへ入れれば、以降のフレームワークの仕組みは同じように動く。

<!--
  TODO: ログアウト時のユーザ情報の破棄を確認して確定する。
  3方式とも、Logout は .NET 側のサインアウト（FormsAuthentication.SignOut() /
  SignOutAsync()）のみで、UserInfoHandle.DeleteUserInformation() を呼んでいない。
  - Web Forms の login.aspx 側は UOC_FormInit で FxSessionAbandon() を呼んでおり、
    「ログイン画面に来た時点でセッションを消す」設計に見える。
  - MVC / Core MVC には該当する処理が見当たらない。
  セッションを別途破棄しているのか、サンプルの漏れなのかが読み取れなかった。
-->

## OAuth2 / OIDC / SAML2 について

`Touryo.Infrastructure.Framework.Authentication` に OAuth2 / OIDC / SAML2 のクライアント・
サーバ実装（`OAuth2AndOIDCClient` / `SAML2Client` など）がある。

**これらはサブプロダクトの汎用認証サイト（MultiPurposeAuthSite）用に開発されたもので、
OpenTouryo でアプリケーションを作る際の標準的な認証手段ではない。**

アプリケーション側で外部 IdP と連携する場合も、最後にやることは同じ
（`MyUserInfo` を作ってセッションへ入れる）。

<!-- TODO: 外部 IdP と連携する方針のプロジェクトでは、その手順をここに追記する。 -->

## セッションが前提（Web のみ）

`UserInfoHandle` はセッションに依存する。**セッションを使わない構成では成立しない。**
Web の P層フレームワーク（Web Forms / MVC / ASP.NET Core MVC）を使う場合、セッションは必須。

### リッチクライアントは別（このスキルの対象外）

**Windows Forms（リッチクライアント）は `UserInfoHandle` もセッションも使わない。**
`MyBaseControllerWin.UserInfo`（`static` フィールド）でユーザ情報を保持し、
.NET の認証機構も使わない。詳細は `opentouryo-layer-p-winforms` を参照。

WPF は P層フレームワークを持たないため、ユーザ情報の保持方法もアプリケーション側で決める。

このスキルの記述は **Web 系（Web Forms / MVC / ASP.NET Core MVC）が対象**。

## やってはいけないこと

- **セッションから直接ユーザ情報を読む** — `UserInfoHandle` を経由する。
  ランタイム差（JSON シリアライズの有無）を吸収している
- **`MyUserInfo` に項目を足そうとする** — 親クラス2 はバイナリで提供される。
  既存の項目を使うか、引数クラスで渡す
- **net48 向けコードで `GetUserInformation<T>()` を使う** — core 系専用。逆も同様
- **B層で `UserInfoHandle` からユーザ情報を取る** — 引数クラス経由で受け取る。
  B層がセッション（＝ P層の関心事）に依存してはならない
- **P層で毎回 `UserInfoHandle.GetUserInformation()` を呼ぶ** — 親クラス2 が取得済み。
  コントローラの `this.UserInfo` を使う
- **`UserInfo` / `MyUserInfo` を編集しようとする** — どちらもバイナリで提供される親クラス。
  ソースが無い
- **ログインで .NET 側のサインインだけ、または `SetUserInformation` だけを書く** — 両方必要。
  サインインだけだと `UserName` / `IPAddress` しか復元されず、プロジェクト固有の項目が欠ける。
  `SetUserInformation` だけだと認証状態が維持されない
- **`this.UserInfo` の null チェックを書く** — 親クラス2 が必ず埋める。
  未認証時は `UserName` が `"未認証"` になる（null ではない）
- **P層フレームワークを取り違える** — Web Forms / MVC（net48）は **Forms 認証**、
  ASP.NET Core MVC は **Cookie 認証**。`FormsAuthentication` は Core に存在しない
- **net48 MVC で `web.config` の `<authorization>` を消して `[Authorize]` だけにする** —
  両方使う二段構え。`<authorization>` は Web Forms と同一の設定で、サイト全体に効く
- **Core MVC で `Request.UserHostAddress` を使う** — 存在しない。`GetClientIpAddress` を使う
- **Core MVC で `_AddHttpContextAccessor()` / `_UseHttpContextAccessor()` を呼び忘れる** —
  `UserInfoHandle` が `MyHttpContext.Current.Session` に依存しているため動かない
- **OpenTouryo が認証機構そのものを提供すると考える** — 認証状態の維持は .NET の仕組みを使う。
  OpenTouryo が持つのは認証済みユーザ情報の保持
