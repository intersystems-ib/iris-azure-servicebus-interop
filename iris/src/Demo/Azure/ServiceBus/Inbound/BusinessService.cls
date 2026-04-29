/// Receives queue messages from the inbound adapter and handles IRIS-side processing.
Class Demo.Azure.ServiceBus.Inbound.BusinessService Extends Ens.BusinessService
{

Parameter ADAPTER = "Demo.Azure.ServiceBus.Inbound.Adapter";

/// Log one received message so the inbound queue flow can be verified first.
Method OnProcessInput(
    request As Demo.Azure.ServiceBus.Inbound.Request,
    Output response As %RegisteredObject) As %Status
{
    $$$LOGINFO("Received Azure Service Bus message "_request.MessageId)
    $$$LOGINFO("Azure Service Bus body: "_request.Body)
    $$$ThrowOnError(..SendRequestAsync("Dummy", request))

    quit $$$OK
}

}
