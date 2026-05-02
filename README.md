# Async Order Processing — Azure Functions Backend

Azure Functions backend for the async order processing demo. Queue-triggered .NET 8 function processes incoming orders through a multi-step pipeline. Infrastructure defined in Bicep.

[![Frontend Demo](https://img.shields.io/badge/frontend%20demo-→-brightgreen)](https://michnbruno.github.io/async-order-processing/)
[![Frontend Repo](https://img.shields.io/badge/frontend%20repo-async--order--processing-blue)](https://github.com/michnbruno/async-order-processing)

---

**Stack:** `.NET 8 Isolated` `·` `Azure Functions` `·` `Azure Storage Queues` `·` `Azure WebPubSub` `·` `Bicep IaC` `·` `Application Insights`

---

### Feature status

| Feature | Status | Notes |
|---|---|---|
| **Deployment** | ⚠️ local only | Azure deployment in progress |
| Queue-triggered function | ✔ implemented | Triggers on `orders-incoming` queue |
| Order validation | ✔ implemented | Field and business rule checks |
| Inventory check | ✔ implemented | Per-item stock verification |
| Payment processing | ✔ implemented | TODO: wire to payment gateway |
| Order status update | ✔ implemented | TODO: wire to database |
| Customer confirmation | ✔ implemented | TODO: wire to email service |
| Bicep IaC | ✔ implemented | Full Azure resource definitions |
| WebPubSub event emission | ⚠️ in progress | Real-time frontend updates |
| Azure deployment | ⚠️ in progress | Local run verified |

---

### How it works

Orders submitted via the React SPA are placed on an Azure Storage Queue. A queue-triggered Azure Function picks them up and runs each order through a five-step pipeline — validate, inventory check, payment, status update, confirmation. WebPubSub emits real-time events back to the frontend as each step completes.

---

### Repository structure

```
infrastructure/
  main.bicep                    # Azure resource definitions
  azuredeploy.parameters.json   # Deployment parameters

src/
  OrderProcessingFunction/
    ProcessOrder.cs             # Queue-triggered function — order pipeline
    OrderProcessingFunction.csproj
```

---

*[← michnbruno](https://github.com/michnbruno)*
