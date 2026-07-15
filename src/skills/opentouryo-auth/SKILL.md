---
name: opentouryo-auth
description: "OpenTouryo で認証済みユーザの情報を保持する。ユーザ情報クラス（UserInfo / MyUserInfo）の定義とカスタマイズ、UserInfoHandle によるセッションへの格納・取得（SetUserInformation / GetUserInformation / DeleteUserInformation）、.NET の認証（ASP.NET Core の Cookie 認証・ClaimsPrincipal）との組み合わせ方、ログインから P層・B層へユーザ情報が流れる経路、net48 と .NET 10.0 での API 差を扱う。認証 / ログイン / ログアウト / ユーザ情報 / MyUserInfo / UserInfoHandle / セッション / Cookie認証 / ClaimsPrincipal を伴う作業のときに使う。"
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

- ① だけ → `[Authorize]` は通るが `this.UserInfo` が null になり、B層へ渡すユーザ情報がない
- ② だけ → 認証状態が維持されない

### ログイン処理

```csharp
// ① .NET 側：認証状態を維持する
List<Claim> claims = new List<Claim>();
claims.Add(new Claim(ClaimTypes.Name, model.UserName));

ClaimsIdentity userIdentity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);
ClaimsPrincipal userPrincipal = new ClaimsPrincipal(userIdentity);

await AuthenticationHttpContextExtensions.SignInAsync(
    this.HttpContext, CookieAuthenticationDefaults.AuthenticationScheme, userPrincipal);

// ② OpenTouryo 側：ユーザ情報を保持する
MyUserInfo ui = new MyUserInfo(model.UserName, (new GetClientIpAddress()).GetAddress());
UserInfoHandle.SetUserInformation(ui);
```

IP アドレスの取得には `GetClientIpAddress`（`Touryo.Infrastructure.Framework.Util`）を使う。

**認証方式そのものは問わない。** パスワード照合でも、外部 IdP から受け取った情報でも、
最後に `MyUserInfo` を作ってセッションへ入れれば、以降のフレームワークの仕組みは同じように動く。

### ログアウト処理

```csharp
await AuthenticationHttpContextExtensions.SignOutAsync(
    this.HttpContext, CookieAuthenticationDefaults.AuthenticationScheme);
```

<!--
  TODO: ログアウト時のユーザ情報の破棄を確認して確定する。
  - UserInfoHandle.DeleteUserInformation() が用意されているが、
    MVC_Sample の Logout は SignOutAsync のみで、これを呼んでいない。
    セッションを別途破棄しているのか、サンプルの漏れなのかが読み取れなかった。
  - 旧版の利用ガイドには「BaseController.FxSessionAbandon() を使い、
    Sessionタイムアウト検出用Cookieを削除したうえでセッションを解放する。
    解放後は Get画面へ遷移する（同一画面のポストバックは不正操作防止機能でエラーになる）」
    とあるが、これは Web Forms 前提。MVC / .NET 10.0 での手順は要確認。
-->

## OAuth2 / OIDC / SAML2 について

`Touryo.Infrastructure.Framework.Authentication` に OAuth2 / OIDC / SAML2 のクライアント・
サーバ実装（`OAuth2AndOIDCClient` / `SAML2Client` など）がある。

**これらはサブプロダクトの汎用認証サイト（MultiPurposeAuthSite）用に開発されたもので、
OpenTouryo でアプリケーションを作る際の標準的な認証手段ではない。**

アプリケーション側で外部 IdP と連携する場合も、最後にやることは同じ
（`MyUserInfo` を作ってセッションへ入れる）。

<!-- TODO: 外部 IdP と連携する方針のプロジェクトでは、その手順をここに追記する。 -->

## セッションが前提

`UserInfoHandle` はセッションに依存する。**セッションを使わない構成では成立しない。**
P層フレームワークを使う場合、セッションは必須。

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
- **ログインで `SignInAsync` だけ、または `SetUserInformation` だけを書く** — 両方必要。
  片方だけだと、認証は通るがユーザ情報が無い（または逆）状態になる
- **OpenTouryo が認証機構そのものを提供すると考える** — 認証状態の維持は .NET の仕組みを使う。
  OpenTouryo が持つのは認証済みユーザ情報の保持
