Class Demo.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="Demo.Production" TestingEnabled="true" LogGeneralTraceEvents="true">
  <Description></Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="Azure ServiceBus Sender" Category="" ClassName="Demo.Azure.ServiceBus.BusinessOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="Send messages to an Azure Service Bus queue using embedded Python" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="ConnectionString"></Setting>
    <Setting Target="Host" Name="QueueName"></Setting>
  </Item>
</Production>
}

}
