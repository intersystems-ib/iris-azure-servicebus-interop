/// Inbound IRIS request envelope built from one locked Azure Service Bus message.
Class Demo.Azure.ServiceBus.Inbound.Request Extends Ens.Request
{

// Raw message body returned by Azure Service Bus.
Property Body As %String(MAXLEN = "");

// Broker properties copied from the received Service Bus message.
Property MessageId As %String(MAXLEN = 200);

Property CorrelationId As %String(MAXLEN = 200);

Property Subject As %String(MAXLEN = 200);

Property ContentType As %String(MAXLEN = 200);

// Custom Azure application properties serialized as JSON.
Property ApplicationPropertiesJSON As %String(MAXLEN = "");

Property SequenceNumber As %String(MAXLEN = 50);

Property DeliveryCount As %Integer;

// Token used by the adapter to settle the locked Azure message.
Property SettlementToken As %String(MAXLEN = 100);

Storage Default
{
<Data name="InboundRequestDefaultData">
<Subscript>"InboundRequest"</Subscript>
<Value name="1">
<Value>Body</Value>
</Value>
<Value name="2">
<Value>MessageId</Value>
</Value>
<Value name="3">
<Value>CorrelationId</Value>
</Value>
<Value name="4">
<Value>Subject</Value>
</Value>
<Value name="5">
<Value>ContentType</Value>
</Value>
<Value name="6">
<Value>ApplicationPropertiesJSON</Value>
</Value>
<Value name="7">
<Value>SequenceNumber</Value>
</Value>
<Value name="8">
<Value>DeliveryCount</Value>
</Value>
<Value name="9">
<Value>SettlementToken</Value>
</Value>
</Data>
<DefaultData>InboundRequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
