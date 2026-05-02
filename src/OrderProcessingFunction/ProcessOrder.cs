using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace OrderProcessingFunction
{
    /// <summary>
    /// Processes incoming orders from Azure Storage Queue
    /// Demonstrates the MVP approach: Simple, cost-effective, serverless
    /// </summary>
    public class ProcessOrder
    {
        private readonly ILogger<ProcessOrder> _logger;

        public ProcessOrder(ILogger<ProcessOrder> logger)
        {
            _logger = logger;
        }

        /// <summary>
        /// Triggered when a message arrives in the "orders-incoming" queue
        /// </summary>
        /// <param name="orderMessage">JSON string representing the order</param>
        [Function(nameof(ProcessOrder))]
        public async Task Run(
            [QueueTrigger("orders-incoming", Connection = "AzureWebJobsStorage")] 
            string orderMessage)
        {
            try
            {
                _logger.LogInformation("=== Order Processing Started ===");
                _logger.LogInformation($"Message received: {orderMessage}");

                // Deserialize the order
                var order = JsonSerializer.Deserialize<Order>(orderMessage, new JsonSerializerOptions
                {
                    PropertyNameCaseInsensitive = true
                });

                if (order == null)
                {
                    _logger.LogError("Failed to deserialize order message");
                    throw new InvalidOperationException("Invalid order format");
                }

                _logger.LogInformation($"Processing Order ID: {order.OrderId}");
                _logger.LogInformation($"Customer ID: {order.CustomerId}");
                _logger.LogInformation($"Total Amount: ${order.Total:F2}");
                _logger.LogInformation($"Item Count: {order.Items?.Length ?? 0}");

                // Step 1: Validate Order
                await ValidateOrder(order);

                // Step 2: Check Inventory
                await CheckInventory(order);

                // Step 3: Process Payment
                await ProcessPayment(order);

                // Step 4: Update Order Status
                await UpdateOrderStatus(order.OrderId, "Completed");

                // Step 5: Send Confirmation
                await SendConfirmation(order);

                _logger.LogInformation($"✅ Order {order.OrderId} processed successfully");
                _logger.LogInformation("=== Order Processing Completed ===");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"❌ Error processing order: {ex.Message}");
                
                // In production, you might want to:
                // 1. Write to a dead-letter queue
                // 2. Send alert to operations team
                // 3. Store failed message for later retry
                
                throw; // Re-throw to let Azure Functions retry mechanism handle it
            }
        }

        private async Task ValidateOrder(Order order)
        {
            _logger.LogInformation("Validating order...");
            
            // Business validation rules
            if (string.IsNullOrEmpty(order.OrderId))
                throw new ArgumentException("Order ID is required");

            if (string.IsNullOrEmpty(order.CustomerId))
                throw new ArgumentException("Customer ID is required");

            if (order.Items == null || order.Items.Length == 0)
                throw new ArgumentException("Order must contain at least one item");

            if (order.Total <= 0)
                throw new ArgumentException("Order total must be greater than zero");

            // Simulate validation delay
            await Task.Delay(100);
            
            _logger.LogInformation("✓ Order validation passed");
        }

        private async Task CheckInventory(Order order)
        {
            _logger.LogInformation("Checking inventory...");
            
            // TODO: Replace with actual inventory service call
            // For demo purposes, simulate inventory check
            foreach (var item in order.Items)
            {
                _logger.LogInformation($"  Checking stock for Product {item.ProductId}: Quantity {item.Quantity}");
                
                // Simulate inventory database call
                await Task.Delay(50);
            }
            
            _logger.LogInformation("✓ Inventory check passed");
        }

        private async Task ProcessPayment(Order order)
        {
            _logger.LogInformation($"Processing payment for ${order.Total:F2}...");
            
            // TODO: Integrate with payment gateway (Stripe, Square, etc.)
            // For demo purposes, simulate payment processing
            await Task.Delay(200);
            
            _logger.LogInformation("✓ Payment processed successfully");
        }

        private async Task UpdateOrderStatus(string orderId, string status)
        {
            _logger.LogInformation($"Updating order status to: {status}");
            
            // TODO: Update database with order status
            // This would typically be Azure SQL, Cosmos DB, or Table Storage
            await Task.Delay(50);
            
            _logger.LogInformation("✓ Order status updated");
        }

        private async Task SendConfirmation(Order order)
        {
            _logger.LogInformation($"Sending confirmation email to customer {order.CustomerId}...");
            
            // TODO: Send confirmation email via SendGrid, Azure Communication Services, etc.
            await Task.Delay(100);
            
            _logger.LogInformation("✓ Confirmation sent");
        }
    }

    #region Data Models

    /// <summary>
    /// Represents an order from the queue
    /// </summary>
    public class Order
    {
        public string OrderId { get; set; } = string.Empty;
        public string CustomerId { get; set; } = string.Empty;
        public OrderItem[] Items { get; set; } = Array.Empty<OrderItem>();
        public decimal Total { get; set; }
        public DateTime OrderDate { get; set; } = DateTime.UtcNow;
    }

    /// <summary>
    /// Represents a line item in an order
    /// </summary>
    public class OrderItem
    {
        public string ProductId { get; set; } = string.Empty;
        public int Quantity { get; set; }
        public decimal Price { get; set; }
    }

    #endregion
}

/* ============================================================================
 * SAMPLE QUEUE MESSAGE (JSON):
 * ============================================================================
{
  "orderId": "ORD-12345",
  "customerId": "CUST-001",
  "items": [
    {
      "productId": "PROD-100",
      "quantity": 2,
      "price": 29.99
    },
    {
      "productId": "PROD-200",
      "quantity": 1,
      "price": 49.99
    }
  ],
  "total": 109.97,
  "orderDate": "2024-09-29T10:30:00Z"
}
 * ============================================================================
 * RETRY BEHAVIOR:
 * ============================================================================
 * Azure Functions will automatically retry failed messages:
 * - Attempt 1: Immediate
 * - Attempt 2: After ~1 minute
 * - Attempt 3: After ~2 minutes
 * - Attempt 4: After ~4 minutes
 * - Attempt 5: After ~8 minutes (final attempt)
 * 
 * After 5 failed attempts, message moves to poison queue: orders-incoming-poison
 * ============================================================================
 */