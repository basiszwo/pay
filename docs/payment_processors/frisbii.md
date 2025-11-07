# Frisbii Payment Processor

Frisbii integration for the Pay gem enables you to process payments, manage subscriptions, and handle webhooks through the Frisbii payment platform.

## Configuration

Add your Frisbii API credentials to your Rails credentials file:

```yaml
frisbii:
  private_key: priv_your_private_api_key_here
  public_key: pub_your_public_api_key_here  # Optional, for frontend integrations
  signing_secret: your_webhook_signing_secret_here
```

Or configure via environment variables:

```ruby
# config/initializers/pay.rb
Pay.setup do |config|
  config.enabled_processors = [:frisbii]

  # Configure Frisbii
  Pay::Frisbii.configure do |frisbii|
    frisbii.private_key = ENV["FRISBII_PRIVATE_KEY"]
    frisbii.signing_secret = ENV["FRISBII_SIGNING_SECRET"]
  end
end
```

## Usage

### Setting up a Customer

```ruby
# Create or retrieve a Frisbii customer
user = User.find(1)
user.set_payment_processor :frisbii
```

### Creating One-time Charges

```ruby
# Create a charge (amount in cents)
charge = user.payment_processor.charge(1000, {
  currency: "USD",
  description: "One-time payment",
  metadata: {
    order_id: "12345"
  }
})

# With a specific payment method
charge = user.payment_processor.charge(1000, {
  payment_method: "pm_xxxxx"
})
```

### Managing Subscriptions

```ruby
# Create a subscription
subscription = user.payment_processor.subscribe(
  plan: "monthly_plan",
  trial_period_days: 7
)

# Cancel a subscription (at period end)
subscription.cancel

# Cancel immediately
subscription.cancel_now!

# Resume a canceled subscription (during grace period)
subscription.resume

# Pause subscription
subscription.pause

# Resume paused subscription
subscription.unpause

# Change subscription plan
subscription.swap("new_plan")

# Update quantity
subscription.change_quantity(2)
```

### Payment Methods

```ruby
# Add a payment method (using token from Frisbii.js)
payment_method = user.payment_processor.add_payment_method("pm_token_xxxxx")

# Set as default
payment_method.make_default!

# Remove payment method
payment_method.detach
```

### Webhooks

Configure your webhook endpoint in your Frisbii dashboard:

```
https://yourdomain.com/pay/webhooks/frisbii
```

The gem automatically handles these webhook events:

#### Customer Events
- `customer_created`
- `customer_updated`
- `customer_deleted`

#### Payment/Invoice Events
- `invoice_settled` - Payment successful
- `invoice_failed` - Payment failed
- `invoice_authorized` - Payment authorized (requires capture)
- `invoice_refunded` - Payment refunded
- `invoice_cancelled` - Payment cancelled

#### Subscription Events
- `subscription_created`
- `subscription_cancelled`
- `subscription_uncancelled`
- `subscription_renewal`
- `subscription_on_hold` - Subscription paused
- `subscription_reactivated` - Subscription resumed
- `subscription_expired`
- `subscription_trial_end`

#### Payment Method Events
- `payment_method_created`
- `payment_method_updated`
- `payment_method_deleted`

### Custom Webhook Handlers

You can add custom webhook handlers:

```ruby
# config/initializers/pay.rb
Pay::Webhooks.configure do |events|
  events.subscribe "frisbii.custom_event" do |event|
    # Handle custom event
    Rails.logger.info "Custom event received: #{event}"
  end
end
```

### Handling Refunds

```ruby
# Full refund
charge.refund!

# Partial refund (amount in cents)
charge.refund!(500)

# With reason
charge.refund!(500, reason: "Customer request")
```

### Authorization and Capture

```ruby
# Authorize payment (hold funds)
charge = user.payment_processor.charge(1000, {
  capture: false  # Authorization only
})

# Later capture the payment
charge.capture

# Or capture a different amount
charge.capture(800)

# Cancel authorization
charge.cancel
```

### Error Handling

```ruby
begin
  user.payment_processor.charge(1000)
rescue Pay::Frisbii::Error => e
  Rails.logger.error "Payment failed: #{e.message}"
  # Handle error appropriately
end
```

## API Documentation

For more details on the Frisbii API, visit:
- [Frisbii Documentation](https://docs.frisbii.com)
- [API Reference](https://docs.frisbii.com/reference)

## Testing

Use the FakeProcessor for testing in development/test environments:

```ruby
# In test environment
user.set_payment_processor :fake_processor

# Or configure globally for tests
Pay.enabled_processors = [:fake_processor]
```

## Requirements

- Rails 6.0+
- Ruby 2.7+
- RestClient gem (~> 2.0)

## Support

For issues specific to the Frisbii integration, please include:
- Your Pay gem version
- Rails version
- Complete error messages and stack traces
- Relevant code snippets

Report issues at: https://github.com/pay-rails/pay/issues