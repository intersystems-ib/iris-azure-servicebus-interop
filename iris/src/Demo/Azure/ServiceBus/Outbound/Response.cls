/// Outbound BO response containing the send status returned by the Azure SDK call.
Class Demo.Azure.ServiceBus.Outbound.Response Extends Ens.Response
{

Property Status As %String(MAXLEN = 50);

Property MessageId As %String(MAXLEN = 200);

// RawResponseJSON keeps the minimal BO result returned by the Python sender.
Property RawResponseJSON As %String(MAXLEN = "");

Storage Default
{
<Data name="ResponseDefaultData">
<Subscript>"Response"</Subscript>
<Value name="1">
<Value>Status</Value>
</Value>
<Value name="2">
<Value>MessageId</Value>
</Value>
<Value name="3">
<Value>RawResponseJSON</Value>
</Value>
</Data>
<DefaultData>ResponseDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
