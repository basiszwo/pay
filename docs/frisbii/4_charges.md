# Frisbii Charges & Payments

## Creating Charges

### Basic Charge

```ruby
# Create a one-time charge (amount in cents)
charge = user.payment_processor.charge(1000, {
  currency: "USD",
  description: "Product purchase"
})
```

### Charge with Payment Method

```ruby
# Use a specific payment method
charge = user.payment_processor.charge(1000, {
  payment_method: "pm_xxxxx",
  currency: "USD"
})
```

### Charge with Metadata

```ruby
charge = user.payment_processor.charge(2500, {
  currency: "USD",
  description: "Premium subscription",
  metadata: {
    order_id: "12345",
    product: "premium_plan",
    campaign: "summer_sale"
  }
})
```

## Authorization & Capture

### Authorize Only

```ruby
# Authorize payment without capturing
charge = user.payment_processor.charge(1000, {
  capture: false  # Authorization only
})
```

### Capture Authorization

```ruby
# Capture the full amount
charge.capture

# Capture partial amount (800 cents of 1000)
charge.capture(800)
```

### Cancel Authorization

```ruby
# Cancel an authorized charge
charge.cancel
```

**Note**: Authorizations typically expire after 7 days if not captured.

## Refunds

### Full Refund

```ruby
# Refund the entire charge
charge.refund!
```

### Partial Refund

```ruby
# Refund 500 cents of the original charge
charge.refund!(500)
```

### Refund with Reason

```ruby
charge.refund!(500, reason: "Customer request")
```

## Charge States

Charges can have the following states:

- `pending` - Payment initiated
- `authorized` - Authorized, awaiting capture
- `succeeded` - Payment successful
- `failed` - Payment failed
- `canceled` - Payment cancelled
- `refunded` - Payment refunded (full or partial)

## Accessing Charge Data

```ruby
# Get charge details
charge.amount           # Amount in cents
charge.currency         # Currency code
charge.status          # Current status
charge.amount_refunded # Refunded amount
charge.created_at      # Creation timestamp
charge.metadata        # Custom metadata

# Check refund status
charge.refunded?       # True if any refund
charge.full_refund?    # True if fully refunded
charge.partial_refund? # True if partially refunded

# Payment method details
charge.payment_method_type # "card", "bank_account", etc.
charge.brand              # Card brand (Visa, Mastercard, etc.)
charge.last4              # Last 4 digits
charge.exp_month          # Expiration month
charge.exp_year           # Expiration year
```

## Idempotency

Prevent duplicate charges with idempotency keys:

```ruby
charge = user.payment_processor.charge(1000, {
  idempotency_key: "order_12345_attempt_1",
  currency: "USD"
})

# Subsequent calls with same key return the same charge
# without creating a duplicate
```

## Checkout Sessions

Create hosted checkout pages:

```ruby
session = user.payment_processor.checkout(
  mode: "payment",
  line_items: [{
    price: "price_xxxxx",
    quantity: 1
  }],
  success_url: payment_success_url,
  cancel_url: pricing_url
)

redirect_to session["url"]
```

## Invoice Generation

Generate invoices for charges:

```ruby
# Create and pay an invoice
user.payment_processor.invoice!

# Preview invoice before charging
preview = user.payment_processor.preview_invoice
```

## Handling Failures

```ruby
begin
  charge = user.payment_processor.charge(1000)
  # Handle success
rescue Pay::Frisbii::Error => e
  # Log the error
  Rails.logger.error "Payment failed: #{e.message}"

  # Check error code if available
  if e.code == "insufficient_funds"
    # Handle specific error
  end

  # Show user-friendly message
  redirect_to checkout_path, alert: "Payment failed. Please try again."
end
```

## Syncing Charges

Sync charge data from Frisbii:

```ruby
# Sync a specific charge
Pay::Frisbii::Charge.sync("charge_id_xxxxx")

# Sync from webhook event
charge = Pay::Frisbii::Charge.sync(
  event["invoice"]["id"],
  object: event["invoice"]
)
```

## Best Practices

1. **Always handle errors** - Payments can fail for many reasons
2. **Use idempotency keys** - Prevent duplicate charges
3. **Store charge IDs** - For reconciliation and support
4. **Log payment events** - For auditing and debugging
5. **Send receipts** - Automatically via Pay or custom
6. **Test edge cases** - Failures, timeouts, invalid cards
