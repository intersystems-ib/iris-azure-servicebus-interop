Class Demo.Azure.ServiceBus.Message Extends (%SerialObject, %XML.Adaptor, %JSON.Adaptor)
{

// This object models the JSON body placed on the Service Bus message.
Property MessageId As %String(MAXLEN = 200, %JSONFIELDNAME = "messageId");

Property CorrelationId As %String(MAXLEN = 200, %JSONFIELDNAME = "correlationId");

Property Subject As %String(MAXLEN = 200, %JSONFIELDNAME = "subject");

Property Body As %String(MAXLEN = "", %JSONFIELDNAME = "body");

Storage Default
{
<Data name="MessageState">
<Value name="1">
<Value>MessageId</Value>
</Value>
<Value name="2">
<Value>CorrelationId</Value>
</Value>
<Value name="3">
<Value>Subject</Value>
</Value>
<Value name="4">
<Value>Body</Value>
</Value>
</Data>
<State>MessageState</State>
<StreamLocation>^Demo.Azure.ServiceBus.MessageS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
