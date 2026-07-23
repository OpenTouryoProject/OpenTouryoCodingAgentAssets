# トランザクション制御 コードスニペット（コピー元）

出典：UserGuide 各機能編 §5、`Framework/Business/BaseLogic.cs`・`TransactionControl.cs`（実ソース）で裏取り。**on-demand 参照**（SKILL 予算外）。

## パターンで Dam を初期化

```csharp
// Dam 生成 → パターンIDで初期化 → フレームワーク管理下へ
BaseDam damWork = new DamSqlSvr();
BaseLogic.InitDam("SQL_RC", damWork);   // TCDefinition.xml の SQL_RC（connkey＋isolevel）で初期化
this.SetDam(damWork);
```

## トランザクショングループで複数 Dam

```csharp
string[] patterns;
BaseLogic.GetTransactionPatterns("SQLSvr", out patterns);
foreach (string pattern in patterns)
{
    BaseDam damWork = new DamSqlSvr();
    BaseLogic.InitDam(pattern, damWork);
    this.SetDam(pattern, damWork);   // キー付きで管理下へ
}
```

## XML 定義（TCDefinition.xml）

`isolevel`：`nc`(接続しない)/`nt`(ノーTx)/`uc`(ReadUncommitted)/`rc`(ReadCommitted)/`rr`(RepeatableRead)/`sz`(Serializable)/`ss`(Snapshot)/`df`(Default)。

```xml
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE TCD[
 <!ELEMENT TCD (TransactionPattern*, TransactionGroup*)>
 <!ELEMENT TransactionPattern EMPTY><!ELEMENT TransactionGroup EMPTY>
 <!ATTLIST TransactionPattern id ID #REQUIRED connkey CDATA #IMPLIED
   isolevel (nc|nt|uc|rc|rr|sz|ss|df) "rc">
 <!ATTLIST TransactionGroup id ID #REQUIRED value CDATA #REQUIRED>
]>
<TCD>
  <TransactionPattern id="SQL_RC" connkey="ConnectionString_SQL" isolevel="rc"/>
  <TransactionPattern id="SQL_SZ" connkey="ConnectionString_SQL" isolevel="sz"/>
  <TransactionGroup id="SQLSvr" value="SQL_RC,SQL_SZ"/>
</TCD>
```

config パス：`<add key="FxXMLTCDefinition" value="...\TCDefinition.xml"/>`。

## 属性ベース（サービス化時に業務クラスへパターンを付与）

```csharp
[MyAttribute(TransactionPatternID = "SQL_RC")]
public class LayerB : MyBaseLogic
{
    public MyAttribute GetAttr() => MyAttribute.GetCustomAttributes(this);
}
```

> B層の分離レベル指定（`DoBusinessLogic(pv, iso)`・`SelectIsolationLevel`）は `opentouryo-layer-b` / `-p-call-business`。
