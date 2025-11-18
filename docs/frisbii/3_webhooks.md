# Frisbii Webhooks

## Setup

Configure your webhook endpoint in the Frisbii dashboard:

1. Log into [Frisbii Dashboard](https://app.frisbii.com)
2. Navigate to **Settings** → **Webhooks**
3. Add webhook URL: `https://yourdomain.com/pay/webhooks/frisbii`
4. Copy the signing secret to your credentials
5. Select the events you want to receive

## Webhook Security

All webhooks are verified using HMAC-SHA256:

```ruby
signature = hexencode(hmac_sha_256(webhook_secret, timestamp + id))
```

The webhook controller automatically verifies signatures before processing.

## Supported Events

### Customer Events

- `customer_created` - New customer created
- `customer_updated` - Customer details updated
- `customer_deleted` - Customer deleted

### Invoice/Charge Events

- `invoice_settled` - Payment successful
- `invoice_failed` - Payment failed
- `invoice_authorized` - Payment authorized (awaiting capture)
- `invoice_refunded` - Payment refunded
- `invoice_cancelled` - Payment cancelled

### Subscription Events

- `subscription_created` - New subscription created
- `subscription_cancelled` - Subscription cancelled
- `subscription_uncancelled` - Cancelled subscription resumed
- `subscription_renewal` - Subscription renewed
- `subscription_on_hold` - Subscription paused
- `subscription_reactivated` - Subscription resumed from pause
- `subscription_expired` - Subscription expired
- `subscription_trial_end` - Trial period ending/ended

### Payment Method Events

- `payment_method_created` - Payment method added
- `payment_method_updated` - Payment method updated
- `payment_method_deleted` - Payment method removed

## Custom Webhook Handlers

Add custom handlers for specific events:

```ruby
# config/initializers/pay.rb
Pay::Webhooks.configure do |events|
  events.subscribe "frisbii.invoice_settled" do |event|
    # Custom logic for successful payments
    Rails.logger.info "Payment received: #{event.dig("invoice", "id")}"
  end

  events.subscribe "frisbii.subscription_cancelled" do |event|
    # Custom cancellation logic
    subscription_id = event.dig("subscription", "handle")
    # Send internal notifications, update analytics, etc.
  end
end
```

## Testing Webhooks Locally

### Using ngrok

1. Install ngrok: `brew install ngrok`
2. Start your Rails server: `rails server`
3. Expose localhost: `ngrok http 3000`
4. Use ngrok URL in Frisbii dashboard: `https://xxx.ngrok.io/pay/webhooks/frisbii`

### Manual Testing

Test webhooks with curl:

```bash
curl -X POST http://localhost:3000/pay/webhooks/frisbii \
  -H "Content-Type: application/json" \
  -d '{
    "id": "webhook_123",
    "event_id": "event_456",
    "event_type": "invoice_settled",
    "timestamp": "2024-01-01T00:00:00Z",
    "signature": "test_signature",
    "invoice": {
      "id": "inv_test_123",
      "amount": 1000,
      "currency": "USD",
      "state": "settled",
      "customer": "cust_test_123"
    }
  }'
```

## Webhook Processing

Webhooks are processed asynchronously via Active Job:

```ruby
# Webhook flow:
# 1. Controller receives webhook
# 2. Verifies signature
# 3. Stores in database
# 4. Queues ProcessJob
# 5. Job delegates to handler
# 6. Handler updates records
```

## Retry Policy

Frisbii retries failed webhooks:

- Schedule: 2, 5, 10, 20, 30 minutes, then hourly for 3 days
- Test accounts: Retries stop after 24 hours
- Your endpoint must respond with HTTP 2XX within 10 seconds

## Idempotency

Webhooks may be delivered multiple times. Handlers must be idempotent:

```ruby
class InvoiceSettled
  def call(event)
    invoice_id = event.dig("invoice", "id")

    # Use find_or_initialize_by to handle duplicates
    charge = Pay::Charge.find_or_initialize_by(
      processor: :frisbii,
      processor_id: invoice_id
    )

    charge.sync!(object: event["invoice"])
  end
end
```

## Monitoring

Add monitoring to track webhook processing:

```ruby
# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
  around_perform do |job, block|
    if job.is_a?(Pay::Webhooks::ProcessJob)
      webhook = job.arguments.first
      StatsD.increment("webhooks.#{webhook.processor}.#{webhook.event_type}")
    end

    block.call
  end
end
```

## Troubleshooting

### Webhook not received

1. Check webhook URL is correct
2. Verify endpoint is publicly accessible
3. Check Frisbii dashboard for delivery attempts
4. Review server logs for errors

### Signature verification failed

1. Ensure signing secret is correct
2. Check for encoding issues
3. Verify timestamp format

### Duplicate processing

1. Implement idempotency checks
2. Use database unique constraints
3. Log webhook IDs to detect duplicates
