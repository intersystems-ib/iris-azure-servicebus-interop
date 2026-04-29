# InterSystems IRIS + Azure Service Bus Interoperability Demo

This repository is a small, focused example that shows how to connect **InterSystems IRIS interoperability productions** to **Azure Service Bus queues** by using **embedded Python**.

It is intended for customers who want to understand:

- how to send messages from an IRIS Business Operation to Azure Service Bus
- how to receive messages from Azure Service Bus through an IRIS inbound adapter and Business Service
- how to structure inbound and outbound interoperability components in a simple IRIS production

The current implementation is deliberately compact. It favors clarity over completeness so the integration pattern is easy to inspect and reuse.

* * *

## What this repo demonstrates

The demo production contains two main integration paths:

### Outbound path

IRIS message -> `Demo.Azure.ServiceBus.Outbound.BusinessOperation` -> Azure Service Bus queue

The outbound Business Operation:

- initializes the Azure SDK client and sender in `OnInit()`
- reuses them while the BO job is running
- sends one message body plus optional broker/application properties

### Inbound path

Azure Service Bus queue -> `Demo.Azure.ServiceBus.Inbound.Adapter` -> `Demo.Azure.ServiceBus.Inbound.BusinessService`

The inbound adapter:

- receives messages using `PEEK_LOCK`
- keeps locked messages in memory until IRIS processing finishes
- completes messages on success
- abandons messages on failure
- can receive messages in batches

The inbound Business Service currently keeps the logic simple:

- logs the received message
- forwards it to a dummy target so the end-to-end IRIS flow can be inspected

* * *

## Repository structure

```text
iris/src/Demo/Production.cls
iris/src/Demo/Azure/ServiceBus/Outbound/BusinessOperation.cls
iris/src/Demo/Azure/ServiceBus/Outbound/Request.cls
iris/src/Demo/Azure/ServiceBus/Outbound/Response.cls
iris/src/Demo/Azure/ServiceBus/Inbound/Adapter.cls
iris/src/Demo/Azure/ServiceBus/Inbound/BusinessService.cls
iris/src/Demo/Azure/ServiceBus/Inbound/Request.cls
docs/service-principal-passwordless.md
```

Main points:

- `Demo.Production` is the top-level IRIS production
- `Outbound/*` contains the send-to-Service-Bus flow
- `Inbound/*` contains the receive-from-Service-Bus flow
- `docs/service-principal-passwordless.md` captures a future passwordless setup using a service principal

* * *

## Requirements

Before starting, make sure you have:

- [Git](https://git-scm.com/)
- [Docker and Docker Compose](https://docs.docker.com/)
- optionally [Visual Studio Code](https://code.visualstudio.com/) with the InterSystems ObjectScript extension
- an Azure subscription
- an Azure Service Bus namespace and queue

The container installs the required Python package for embedded Python:

- `azure-servicebus`

* * *

## Getting started

Clone the repository and start the IRIS container:

```bash
git clone <your-fork-or-repo-url>
cd iris-azure-interop
docker compose build
docker compose up -d
```

Once the container is running:

- Management Portal: `http://localhost:52776/csp/sys/UtilHome.csp`
- Username: `superuser`
- Password: `SYS`

The source code is loaded during image build from:

- `iris/src`

* * *

## Azure Service Bus setup

If you do not already have a queue, start with Microsoft’s quickstart:

- Azure Service Bus queue quickstart: https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-python-how-to-use-queues

For the current version of this repo, the simplest way to test is:

- create a Service Bus queue
- obtain a namespace connection string with send/receive permissions
- configure the queue name in the IRIS production components

Important:

- `QueueName` is only the queue name, for example `myqueue`
- it is not a URL and not the full namespace

* * *

## Open the production

In the Management Portal:

1. Go to **Interoperability** > **Configure** > **Production**
2. Open `Demo.Production`

You should see at least these components:

- `Azure ServiceBus Sender`
- `Azure ServiceBus Receiver`

The production is intentionally small so it is easy to explore.

* * *

## Scenario 1: Send a message to Azure Service Bus

Open the component:

- `Azure ServiceBus Sender`

This component is backed by:

- `Demo.Azure.ServiceBus.Outbound.BusinessOperation`

Configure:

- `ConnectionString`
- `QueueName`

What this component does:

- accepts an IRIS outbound request
- uses embedded Python with the Azure SDK
- sends the request `Body` to the Azure queue
- optionally maps:
  - `MessageId`
  - `CorrelationId`
  - `Subject`
  - `ApplicationPropertiesJSON`

### What to inspect in the code

- [BusinessOperation.cls](/Users/afuentes/Documents/ISC/workspace/iris-azure-interop/iris/src/Demo/Azure/ServiceBus/Outbound/BusinessOperation.cls:1)
- [Request.cls](/Users/afuentes/Documents/ISC/workspace/iris-azure-interop/iris/src/Demo/Azure/ServiceBus/Outbound/Request.cls:1)
- [Response.cls](/Users/afuentes/Documents/ISC/workspace/iris-azure-interop/iris/src/Demo/Azure/ServiceBus/Outbound/Response.cls:1)

Focus on:

- `OnInit()`
- `OnMessage()`
- `PySendMessage()`

### What to test

Use the component test tool in the production to send an instance of:

- `Demo.Azure.ServiceBus.Outbound.Request`

Suggested values:

- `Body`: a JSON string such as `{"hello":"from iris"}`
- `MessageId`: a unique string
- `Subject`: something like `demo`

Then check the queue in Azure Portal using Service Bus Explorer.

* * *

## Scenario 2: Read a message from Azure Service Bus

Open the component:

- `Azure ServiceBus Receiver`

This receiver is backed by:

- Business Service: `Demo.Azure.ServiceBus.Inbound.BusinessService`
- Adapter: `Demo.Azure.ServiceBus.Inbound.Adapter`

Configure on the receiver:

- `ConnectionString`
- `QueueName`
- `MaxMessageCount`
- `MaxWaitTime`

### How the inbound flow works

1. The adapter polls Azure Service Bus using `PEEK_LOCK`
2. It receives up to `MaxMessageCount` messages in one cycle
3. It converts the Azure message data into `Demo.Azure.ServiceBus.Inbound.Request`
4. It calls the Business Service
5. If processing succeeds, the adapter completes the Azure message
6. If processing fails, the adapter abandons the Azure message

This keeps the example reliable while still showing a more realistic batched adapter design.

### What to inspect in the code

- [Adapter.cls](/Users/afuentes/Documents/ISC/workspace/iris-azure-interop/iris/src/Demo/Azure/ServiceBus/Inbound/Adapter.cls:1)
- [BusinessService.cls](/Users/afuentes/Documents/ISC/workspace/iris-azure-interop/iris/src/Demo/Azure/ServiceBus/Inbound/BusinessService.cls:1)
- [Request.cls](/Users/afuentes/Documents/ISC/workspace/iris-azure-interop/iris/src/Demo/Azure/ServiceBus/Inbound/Request.cls:1)

Focus on:

- `OnTask()`
- `PyReceiveBatch()`
- `PyCompleteMessageByToken()`
- `PyAbandonMessageByToken()`

### What to test

1. Send one or more messages into the Azure queue
2. Start the production
3. Open the Message Viewer in IRIS
4. Verify that the inbound service logs the body and message ID

* * *

## Why embedded Python is used this way

InterSystems IRIS requires interoperability callback methods such as:

- `OnInit()`
- `OnTearDown()`
- `OnMessage()`
- `OnTask()`

to remain in ObjectScript.

The Azure SDK logic is therefore placed in helper methods marked:

- `[ Language = python ]`

This repo shows that pattern directly in both inbound and outbound components.

* * *

## Authentication options

### Current example

The current example uses a Service Bus connection string in the production settings because it is the fastest way to get a first working demo.

### Better next step

A better production-ready direction is to avoid exposing the full connection string directly in the production.

Two common options are:

1. IRIS credentials + reconstructed SAS connection string
2. passwordless auth with `DefaultAzureCredential`

For the passwordless service principal option, see:

- [docs/service-principal-passwordless.md](/Users/afuentes/Documents/ISC/workspace/iris-azure-interop/docs/service-principal-passwordless.md:1)

* * *

## Useful links

- Azure Service Bus Python quickstart:
  https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-python-how-to-use-queues
- Embedded Python in IRIS interoperability productions:
  https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GEPYTHON_productions
- Run Python from IRIS:
  https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GEPYTHON_runpython

* * *

## Notes

- This repo is meant to be read and explored, not only executed
- the classes intentionally stay small so the integration pattern is easy to follow
- once the simple version is understood, the same approach can be extended to:
  - credentials objects
  - passwordless auth
  - dead-letter handling
  - richer payload validation
  - routing to real IRIS targets instead of a dummy passthrough operation
