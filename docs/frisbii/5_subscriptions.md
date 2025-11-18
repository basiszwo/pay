# Frisbii Subscriptions

## Creating Subscriptions

### Basic Subscription

```ruby
subscription = user.payment_processor.subscribe(
  plan: "monthly_plan"
)
```

### Subscription with Trial

```ruby
# Trial period in days
subscription = user.payment_processor.subscribe(
  plan: "premium_monthly",
  trial_period_days: 14
)

# Trial until specific date
subscription = user.payment_processor.subscribe(
  plan: "premium_monthly",
  trial_end: 2.weeks.from_now
)
```

### Subscription with Payment Method

```ruby
subscription = user.payment_processor.subscribe(
  plan: "monthly_plan",
  payment_method: "pm_xxxxx"
)
```

### Subscription with Metadata

```ruby
subscription = user.payment_processor.subscribe(
  plan: "enterprise_plan",
  metadata: {
    seats: 10,
    department: "engineering",
    contract_id: "ENT-2024-001"
  }
)
```

## Managing Subscriptions

### Cancel Subscription

```ruby
# Cancel at end of billing period (default)
subscription.cancel

# Cancel immediately
subscription.cancel_now!

# Cancel with options
subscription.cancel(immediately: true)
```

### Resume Cancelled Subscription

```ruby
# Resume during grace period
if subscription.on_grace_period?
  subscription.resume
end
```

### Pause Subscription

```ruby
# Pause indefinitely
subscription.pause

# Pause until specific date
subscription.pause(until_date: 1.month.from_now)
```

### Resume Paused Subscription

```ruby
subscription.unpause
```

### Change Plans

```ruby
# Change immediately
subscription.swap("new_plan")

# Change at next renewal
subscription.swap("new_plan", timing: "renewal")

# Change with proration
subscription.swap("new_plan", prorate: true)
```

### Update Quantity

```ruby
# Update quantity immediately
subscription.change_quantity(5)

# Update at next renewal
subscription.change_quantity(5, timing: "renewal")
```

## Subscription States

- `incomplete` - Initial payment pending
- `trialing` - In trial period
- `active` - Active and paid
- `past_due` - Payment failed, retrying
- `canceled` - Cancelled (may be in grace period)
- `paused` - On hold
- `expired` - Fully expired

## Checking Subscription Status

```ruby
# Status checks
subscription.active?           # Currently active
subscription.on_trial?        # In trial period
subscription.canceled?        # Cancelled
subscription.on_grace_period? # Cancelled but still active
subscription.past_due?        # Payment failed
subscription.paused?          # On hold
subscription.trial_ended?     # Trial has ended

# Will it renew?
subscription.will_renew?      # True if will renew

# Trial information
subscription.trial_ends_at    # Trial end date
subscription.ends_at          # Subscription end date
```

## Subscription Dates

```ruby
# Important dates
subscription.current_period_start # Current billing period start
subscription.current_period_end   # Current billing period end
subscription.trial_ends_at        # Trial end date
subscription.ends_at              # Cancellation effective date
subscription.pause_starts_at      # Pause start date
subscription.pause_resumes_at     # Pause end date
```

## Updating Payment Methods

```ruby
# Change payment method
subscription.update_payment_method("pm_new_xxxxx")

# Get current payment method
payment_method = subscription.payment_method
```

## Retry Failed Payments

```ruby
# Manually retry a failed payment
subscription.retry_failed_payment
```

## Preview Changes

```ruby
# Preview upcoming invoice
invoice = subscription.upcoming_invoice

# Check next charge amount
next_amount = invoice["amount"]
next_date = invoice["period_end"]
```

## Multiple Subscriptions

```ruby
# User can have multiple subscriptions
user.payment_processor.subscriptions.active.each do |subscription|
  puts "#{subscription.name}: #{subscription.processor_plan}"
end

# Find specific subscription
subscription = user.payment_processor.subscription(name: "premium")

# Check if subscribed to any plan
user.payment_processor.subscribed?

# Check if subscribed to specific plan
user.payment_processor.subscribed?(name: "premium", processor_plan: "premium_monthly")
```

## Subscription Webhooks

Key webhook events for subscriptions:

- `subscription_created` - New subscription created
- `subscription_renewal` - Subscription renewed
- `subscription_cancelled` - Cancellation initiated
- `subscription_expired` - Fully expired
- `subscription_trial_end` - Trial ending/ended
- `invoice_payment_failed` - Payment failed

## Metered Billing

For usage-based subscriptions:

```ruby
# Report usage (implementation depends on Frisbii's metered billing API)
user.payment_processor.report_usage(
  quantity: 1000,
  action: "increment",
  timestamp: Time.current
)
```

## Best Practices

1. **Handle trial endings** - Notify users before trial ends
2. **Grace periods** - Allow cancellation reversal
3. **Payment failures** - Implement dunning emails
4. **Proration** - Understand when charges are prorated
5. **Webhook sync** - Keep subscription data current
6. **Multiple plans** - Support plan upgrades/downgrades
