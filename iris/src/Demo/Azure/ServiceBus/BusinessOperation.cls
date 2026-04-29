Class Demo.Azure.ServiceBus.BusinessOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "";

Parameter INVOCATION = "Queue";

Parameter SETTINGS = "ConnectionString:Basic,QueueName:Basic";

// Azure Service Bus namespace connection string used to create the SDK client.
Property ConnectionString As %String(MAXLEN = "");

// Queue name used to create the cached sender.
Property QueueName As %String(MAXLEN = 200);

// Embedded Python stores the live Azure Service Bus client here after OnInit().
Property ServiceBusClient As %SYS.Python;

// Embedded Python stores the queue sender here for reuse across messages.
Property QueueSender As %SYS.Python;

// Copy of the normalized queue name used by the initialized sender.
Property InitializedQueueName As %String(MAXLEN = 200);

// Build the Azure client and sender once when the BO job starts.
Method OnInit() As %Status
{
    #dim sc As %Status = $$$OK

    try {
        do ..PyInit(..ConnectionString, ..QueueName)
    } catch ex {
        set sc = ex.AsStatus()
    }

    quit sc
}

// Close the cached Azure client and sender when the BO job stops.
Method OnTearDown() As %Status
{
    #dim sc As %Status = $$$OK

    try {
        do ..PyTearDown()
    } catch ex {
        set sc = ex.AsStatus()
    }

    quit sc
}

// Serialize the request payload and delegate the actual send to Python.
Method OnMessage(
    request As Demo.Azure.ServiceBus.Request,
    Output response As Demo.Azure.ServiceBus.Response) As %Status
{
    #dim sc As %Status = $$$OK
    #dim body As %String

    try {
        if '$isobject(request.Message) {
            set sc = $$$ERROR($$$GeneralError, "Request.Message is required")
            quit
        }
        // Serialize the payload object to the JSON body sent to Service Bus.
        set sc = request.Message.%JSONExportToString(.body)
        quit:$$$ISERR(sc)
        set response = ##class(Demo.Azure.ServiceBus.Response).%New()
        set response.RawResponseJSON = ..PySendMessage(
            body,
            request.Message.MessageId,
            request.Message.CorrelationId,
            request.Message.Subject,
            request.ApplicationPropertiesJSON)
        set response.Status = "sent"
        set response.MessageId = request.Message.MessageId
    } catch ex {
        set sc = ex.AsStatus()
    }

    quit sc
}

// Normalize BO settings and create reusable Azure SDK objects.
Method PyInit(connectionString As %String, queueName As %String) [ Language = python ]
{
    from azure.servicebus import ServiceBusClient

    # Normalize ObjectScript values before handing them to the Azure SDK.
    connection_string = str(connectionString).strip()
    queue_name = str(queueName).strip()

    if not connection_string:
        raise ValueError("ConnectionString is required")
    if not queue_name:
        raise ValueError("QueueName is required")

    self.ServiceBusClient = ServiceBusClient.from_connection_string(
        conn_str=connection_string
    )
    self.QueueSender = self.ServiceBusClient.get_queue_sender(
        queue_name=queue_name
    )
    self.InitializedQueueName = queue_name
}

// Send one JSON message using the sender cached during OnInit().
Method PySendMessage(
    body As %String,
    messageId As %String,
    correlationId As %String,
    subject As %String,
    applicationPropertiesJSON As %String) As %String [ Language = python ]
{
    import json
    from azure.servicebus import ServiceBusMessage

    # Reuse the sender created during OnInit() instead of reconnecting per message.
    sender = self.QueueSender
    queue_name = self.InitializedQueueName

    if sender is None or not queue_name:
        raise RuntimeError("Azure Service Bus sender is not initialized")

    kwargs = {"content_type": "application/json"}
    if messageId:
        kwargs["message_id"] = str(messageId).strip()
    if correlationId:
        kwargs["correlation_id"] = str(correlationId).strip()
    if subject:
        kwargs["subject"] = str(subject).strip()
    # ApplicationPropertiesJSON is mapped to Azure application_properties.
    if applicationPropertiesJSON:
        kwargs["application_properties"] = json.loads(
            str(applicationPropertiesJSON).strip()
        )

    sender.send_messages(ServiceBusMessage(body, **kwargs))

    return json.dumps({"status": "sent", "queue": queue_name})
}

// Release cached Azure SDK objects held by this BO job.
Method PyTearDown() [ Language = python ]
{
    sender = self.QueueSender
    client = self.ServiceBusClient

    if sender is not None:
        sender.close()
        self.QueueSender = None

    if client is not None:
        client.close()
        self.ServiceBusClient = None
    self.InitializedQueueName = ""
}

}
