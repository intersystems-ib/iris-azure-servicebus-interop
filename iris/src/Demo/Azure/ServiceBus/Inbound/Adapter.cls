/// Polls Azure Service Bus with peek-lock and hands messages to the inbound Business Service.
Class Demo.Azure.ServiceBus.Inbound.Adapter Extends Ens.InboundAdapter
{

Parameter SETTINGS = "ConnectionString:Basic,QueueName:Basic,MaxMessageCount:Basic,MaxWaitTime:Basic";

// Azure Service Bus namespace connection string used to create the SDK client.
Property ConnectionString As %String(MAXLEN = "");

// Queue name used to create the cached receiver.
Property QueueName As %String(MAXLEN = 200);

// Max messages to receive in one poll cycle.
Property MaxMessageCount As %Integer(MAXVAL = 100, MINVAL = 1) [ InitialExpression = 10 ];

// Max seconds to wait for messages before returning from OnTask().
Property MaxWaitTime As %Integer(MAXVAL = 300, MINVAL = 0) [ InitialExpression = 5 ];

// Embedded Python stores the live Azure Service Bus client here after OnInit().
Property ServiceBusClient As %SYS.Python;

// Embedded Python stores the queue receiver here for reuse across polls.
Property QueueReceiver As %SYS.Python;

// Embedded Python keeps the current batch of locked messages here, keyed by settlement token.
Property PendingMessages As %SYS.Python;

// Copy of the normalized queue name used by the initialized receiver.
Property InitializedQueueName As %String(MAXLEN = 200);

/// Create the cached receiver when the adapter job starts.
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

/// Release the cached receiver and client when the adapter job stops.
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

/// Poll a batch with peek-lock, pass each message to the Business Service, then settle by token.
Method OnTask() As %Status
{
    #dim sc As %Status = $$$OK
    #dim batchJSON As %String
    #dim batch As %DynamicArray
    #dim item As %DynamicObject
    #dim request As Demo.Azure.ServiceBus.Inbound.Request
    #dim response As %RegisteredObject
    #dim itemSc As %Status
    #dim token As %String
    #dim i As %Integer

    try {
        set batchJSON = ..PyReceiveBatch(..MaxMessageCount, ..MaxWaitTime)
        if batchJSON = "" {
            return $$$OK
        }

        set batch = [].%FromJSON(batchJSON)
        for i = 0:1:(batch.%Size() - 1) {
            set item = batch.%Get(i)
            set token = item.%Get("settlementToken")

            set request = ##class(Demo.Azure.ServiceBus.Inbound.Request).%New()
            set request.Body = item.%Get("body")
            set request.MessageId = item.%Get("messageId")
            set request.CorrelationId = item.%Get("correlationId")
            set request.Subject = item.%Get("subject")
            set request.ContentType = item.%Get("contentType")
            set request.ApplicationPropertiesJSON = item.%Get("applicationPropertiesJSON")
            set request.SequenceNumber = item.%Get("sequenceNumber")
            set request.DeliveryCount = item.%Get("deliveryCount")
            set request.SettlementToken = token

            set itemSc = ..BusinessHost.ProcessInput(request, .response)
            if $$$ISERR(itemSc) {
                do ..PyAbandonMessageByToken(token)
                if $$$ISOK(sc) {
                    set sc = itemSc
                }
            } else {
                do ..PyCompleteMessageByToken(token)
            }
        }

        do ..PyAbandonAllPendingMessages()
    } catch ex {
        do ..PyAbandonAllPendingMessages()
        set sc = ex.AsStatus()
    }

    quit sc
}

/// Normalize adapter settings and create reusable Azure SDK objects.
Method PyInit(connectionString As %String, queueName As %String) [ Language = python ]
{
    from azure.servicebus import ServiceBusClient, ServiceBusReceiveMode

    connection_string = str(connectionString).strip()
    queue_name = str(queueName).strip()

    if not connection_string:
        raise ValueError("ConnectionString is required")
    if not queue_name:
        raise ValueError("QueueName is required")

    self.ServiceBusClient = ServiceBusClient.from_connection_string(
        conn_str=connection_string
    )
    self.QueueReceiver = self.ServiceBusClient.get_queue_receiver(
        queue_name=queue_name,
        receive_mode=ServiceBusReceiveMode.PEEK_LOCK,
    )
    self.PendingMessages = {}
    self.InitializedQueueName = queue_name
}

/// Receive a batch and return simple JSON-safe fields plus settlement tokens to ObjectScript.
Method PyReceiveBatch(maxMessageCount As %Integer = 10, maxWaitTime As %Integer = 5) As %String [ Language = python ]
{
    import json
    import uuid

    def normalize_value(value):
        if isinstance(value, bytes):
            return value.decode("utf-8")
        if isinstance(value, dict):
            return {str(normalize_value(k)): normalize_value(v) for k, v in value.items()}
        if isinstance(value, (list, tuple)):
            return [normalize_value(item) for item in value]
        return value

    receiver = self.QueueReceiver
    pending_messages = self.PendingMessages or {}

    if receiver is None:
        raise RuntimeError("Azure Service Bus receiver is not initialized")

    max_count = int(maxMessageCount) if maxMessageCount is not None else 10
    wait_time = int(maxWaitTime) if maxWaitTime is not None else 5
    messages = receiver.receive_messages(max_message_count=max_count, max_wait_time=wait_time)
    if not messages:
        self.PendingMessages = pending_messages
        return ""

    result = []
    for message in messages:
        token = str(uuid.uuid4())
        pending_messages[token] = message
        body = "".join(
            part.decode("utf-8") if isinstance(part, bytes) else str(part)
            for part in message.body
        )
        application_properties = normalize_value(message.application_properties or {})
        result.append(
            {
                "settlementToken": token,
                "body": body,
                "messageId": message.message_id,
                "correlationId": message.correlation_id,
                "subject": message.subject,
                "contentType": message.content_type,
                "applicationPropertiesJSON": json.dumps(application_properties),
                "sequenceNumber": str(message.sequence_number),
                "deliveryCount": message.delivery_count,
            }
        )

    self.PendingMessages = pending_messages
    return json.dumps(result)
}

/// Complete one locked message after successful IRIS processing.
Method PyCompleteMessageByToken(settlementToken As %String) [ Language = python ]
{
    pending_messages = self.PendingMessages or {}
    receiver = self.QueueReceiver
    token = str(settlementToken)
    message = pending_messages.pop(token, None)

    if receiver is not None and message is not None:
        receiver.complete_message(message)

    self.PendingMessages = pending_messages
}

/// Abandon one locked message after a processing failure.
Method PyAbandonMessageByToken(settlementToken As %String) [ Language = python ]
{
    pending_messages = self.PendingMessages or {}
    receiver = self.QueueReceiver
    token = str(settlementToken)
    message = pending_messages.pop(token, None)

    if receiver is not None and message is not None:
        receiver.abandon_message(message)

    self.PendingMessages = pending_messages
}

/// Abandon any leftover locked messages from the current batch.
Method PyAbandonAllPendingMessages() [ Language = python ]
{
    pending_messages = self.PendingMessages or {}
    receiver = self.QueueReceiver

    if receiver is not None:
        for message in list(pending_messages.values()):
            receiver.abandon_message(message)

    self.PendingMessages = {}
}

/// Release cached Azure SDK objects held by this adapter job.
Method PyTearDown() [ Language = python ]
{
    receiver = self.QueueReceiver
    client = self.ServiceBusClient

    if receiver is not None:
        for message in list((self.PendingMessages or {}).values()):
            receiver.abandon_message(message)
        receiver.close()
        self.QueueReceiver = None

    if client is not None:
        client.close()
        self.ServiceBusClient = None

    self.PendingMessages = {}
    self.InitializedQueueName = ""
}

}
