Class Demo.Azure.ServiceBus.Request Extends Ens.Request
{

// Message is serialized as the JSON body sent to the Azure queue.
Property Message As Demo.Azure.ServiceBus.Message;

// Custom transport headers for Azure Service Bus, encoded as a JSON object string.
Property ApplicationPropertiesJSON As %String(MAXLEN = "");

Storage Default
{
<Data name="RequestDefaultData">
<Subscript>"Request"</Subscript>
<Value name="1">
<Value>Message</Value>
</Value>
<Value name="2">
<Value>ApplicationPropertiesJSON</Value>
</Value>
</Data>
<DefaultData>RequestDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
