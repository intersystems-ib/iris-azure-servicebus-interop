/// Outbound IRIS request envelope used to send one message to Azure Service Bus.
Class Demo.Azure.ServiceBus.Outbound.Request Extends Ens.Request
{

// Message body sent to the Azure queue.
Property Body As %String(MAXLEN = "");

// Broker properties copied to the outbound Service Bus message.
Property MessageId As %String(MAXLEN = 200);

Property CorrelationId As %String(MAXLEN = 200);

Property Subject As %String(MAXLEN = 200);

// Custom transport headers for Azure Service Bus, encoded as a JSON object string.
Property ApplicationPropertiesJSON As %String(MAXLEN = "");

Storage Default
{
<Data name="RequestDefaultData">
<Subscript>"Request"</Subscript>
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
<Value>ApplicationPropertiesJSON</Value>
</Value>
</Data>
<DefaultData>RequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
