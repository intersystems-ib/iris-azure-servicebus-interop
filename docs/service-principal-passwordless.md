# Azure Service Bus passwordless setup with a service principal

This note captures the setup needed to use `DefaultAzureCredential` from the IRIS container without a Service Bus connection string.

## When to use this

Use a service principal when:

- IRIS runs in Docker outside Azure managed identity
- you want to avoid storing a Service Bus SAS connection string in the production
- you want Azure RBAC-based access instead of SAS keys

If the workload later runs on an Azure host that supports managed identity, managed identity is usually the better option.

## Create the service principal

```bash
az login
az account set --subscription "<your-subscription-id-or-name>"

az ad sp create-for-rbac \
  --name "iris-azure-interop-sp" \
  --skip-assignment
```

The command returns values like:

- `appId`: use as `AZURE_CLIENT_ID`
- `password`: use as `AZURE_CLIENT_SECRET`
- `tenant`: use as `AZURE_TENANT_ID`

Protect that output. The secret is shown when created or reset.

## Assign Service Bus RBAC

Get the Service Bus namespace resource ID:

```bash
az servicebus namespace show \
  --resource-group "<rg>" \
  --name "<namespace>" \
  --query id -o tsv
```

Assign roles at that namespace scope.

Send only:

```bash
az role assignment create \
  --assignee "<appId>" \
  --role "Azure Service Bus Data Sender" \
  --scope "<namespace-resource-id>"
```

Receive only:

```bash
az role assignment create \
  --assignee "<appId>" \
  --role "Azure Service Bus Data Receiver" \
  --scope "<namespace-resource-id>"
```

Send and receive:

```bash
az role assignment create \
  --assignee "<appId>" \
  --role "Azure Service Bus Data Owner" \
  --scope "<namespace-resource-id>"
```

Prefer the narrower sender/receiver roles when possible.

## Docker environment variables

Expose these variables to the IRIS container:

- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`

In `docker-compose.yml`, prefer referencing them from your shell or a local `.env` file instead of hardcoding them:

```yaml
environment:
  - AZURE_TENANT_ID=${AZURE_TENANT_ID}
  - AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
  - AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
```

## Python code shape

With passwordless auth, the code should use `DefaultAzureCredential` and `fully_qualified_namespace` instead of `from_connection_string(...)`:

```python
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient

credential = DefaultAzureCredential()
client = ServiceBusClient(
    fully_qualified_namespace="irisazuredemo.servicebus.windows.net",
    credential=credential,
)
```

## IRIS settings shape

If this is implemented later, the production settings should contain only non-secret values such as:

- `FullyQualifiedNamespace`
- `QueueName`

Secrets should come from the environment, not from production settings.

## Reset the secret later

If a new client secret is needed:

```bash
az ad sp credential reset --id "<appId>"
```
