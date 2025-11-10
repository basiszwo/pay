# Frisbii Webhook Implementation Guide

## Implemented Webhooks

All Frisbii webhooks have been implemented following the patterns established by the Stripe integration. Here's a complete overview:

## Customer Webhooks

### customer_created

- **Action**: Syncs customer data when created
- **Implementation**: Already implemented

### customer_updated

- **Action**: Updates customer data and syncs default payment method
- **Implementation**: Mirrors Stripe's implementation

### customer_deleted

- **Action**: Marks customer as deleted, cancels active subscriptions, removes payment methods
- **Implementation**: Mirrors Stripe's implementation

## Invoice/Charge Webhooks

### invoice_settled

- **Action**: Syncs charge and sends receipt email
- **Implementation**: Already implemented (equivalent to Stripe's charge.succeeded)

### invoice_failed

- **Action**: Syncs charge and sends payment failed email for subscriptions
- **Implementation**: Already implemented

### invoice_authorized

- **Action**: Syncs charge in authorized state (awaiting capture)
- **Implementation**: No email sent - this is a merchant-initiated state

### invoice_refunded

- **Action**: Syncs charge with refund data and sends refund email
- **Implementation**: Mirrors Stripe's charge.refunded

### invoice_cancelled

- **Action**: Syncs cancelled charge (typically authorized charges cancelled before capture)
- **Implementation**: No email sent - backend operation only

## Subscription Webhooks

### subscription_created

- **Action**: Syncs new subscription
- **Implementation**: Already implemented

### subscription_cancelled

- **Action**: Syncs cancelled subscription and sends cancellation email
- **Implementation**: Already implemented

### subscription_renewal

- **Action**: Syncs subscription and sends renewal notification
- **Implementation**: Already implemented

### subscription_uncancelled

- **Action**: Syncs reactivated subscription (cancelled subscription resumed within grace period)
- **Unique to Frisbii**: This event doesn't exist in Stripe. It's triggered when a cancelled subscription is resumed.
- **Recommendation**: Log the event for auditing. Consider sending a custom "subscription resumed" email if desired.

### subscription_on_hold

- **Action**: Syncs paused subscription
- **Unique to Frisbii**: Represents a paused/held state (similar to Stripe's pause_collection)
- **Recommendation**: Update subscription status to "paused". No email needed unless you want to confirm the pause.

### subscription_reactivated

- **Action**: Syncs resumed subscription (from hold/pause state)
- **Unique to Frisbii**: Triggered when a paused subscription is resumed
- **Recommendation**: Update subscription status back to "active". Consider sending a "subscription resumed" email.

### subscription_expired

- **Action**: Syncs expired subscription (past grace period)
- **Unique to Frisbii**: Final expiration event (different from cancellation)
- **Recommendation**: Mark subscription as permanently ended. This is a terminal state.

### subscription_trial_end

- **Action**: Syncs subscription and sends trial ending/ended emails
- **Implementation**: Mirrors Stripe's subscription_trial_will_end

## Payment Method Webhooks

### payment_method_created

- **Action**: Syncs new payment method if attached to customer
- **Implementation**: Mirrors Stripe's implementation

### payment_method_updated

- **Action**: Syncs updated payment method or removes if detached from customer
- **Implementation**: Mirrors Stripe's implementation

### payment_method_deleted

- **Action**: Removes payment method from database
- **Implementation**: Mirrors Stripe's implementation

## Recommendations for Frisbii-Specific Events

### Events Unique to Frisbii

1. **subscription_uncancelled**
   - This is valuable for tracking subscription resurrections
   - Consider adding analytics/metrics tracking
   - Optionally send a "Welcome back" email

2. **subscription_on_hold**
   - Important for billing pause scenarios
   - Update UI to show "Paused" status
   - Consider implementing a pause reason field

3. **subscription_reactivated**
   - Complement to subscription_on_hold
   - Clear any pause-related UI indicators
   - Consider sending a "Billing resumed" notification

4. **subscription_expired**
   - Different from cancelled - this is the final state
   - Use for cleanup operations
   - Archive or flag the subscription as permanently inactive

### Custom Email Notifications

You can add custom emails for Frisbii-specific events:

```ruby
# config/initializers/pay.rb
Pay.emails.subscription_paused = true  # For on_hold
Pay.emails.subscription_resumed = true # For reactivated/uncancelled

# In your mailer
class Pay::UserMailer < Pay::ApplicationMailer
  def subscription_paused
    # Send pause confirmation
  end

  def subscription_resumed
    # Send resume confirmation
  end
end
```

### Testing Webhooks

1. Use ngrok or similar for local testing: ``

   ```bash
   ngrok http 3000
   ```

2. Configure webhook URL in Frisbii dashboard:

   ```bash
   https://your-ngrok-url.ngrok.io/pay/webhooks/frisbii
   ```

3. Test with curl:

   ```bash
   curl -X POST http://localhost:3000/pay/webhooks/frisbii \
     -H "Content-Type: application/json" \
     -d '{
       "id": "webhook_123",
       "event_id": "event_456",
       "event_type": "subscription_created",
       "timestamp": "2024-01-01T00:00:00Z",
       "signature": "test_signature",
       "subscription": {
         "handle": "sub_test_123",
         "customer": "cust_test_123",
         "plan": "monthly_plan",
         "state": "active"
       }
     }'
   ```

## Webhook Security

Always verify webhook signatures in production:

```ruby
# The webhook controller already implements signature verification
# Ensure your webhook secret is configured:
Rails.application.credentials.frisbii[:signing_secret]
```

## Monitoring

Consider adding monitoring for webhook processing:

```ruby
# app/jobs/pay/webhooks/process_job.rb
class Pay::Webhooks::ProcessJob < ApplicationJob
  around_perform do |job, block|
    webhook = job.arguments.first
    Rails.logger.info "[Pay] Processing #{webhook.processor} webhook: #{webhook.event_type}"

    block.call

    Rails.logger.info "[Pay] Successfully processed webhook: #{webhook.id}"
  rescue => e
    Rails.logger.error "[Pay] Failed to process webhook: #{webhook.id} - #{e.message}"
    raise
  end
end
```
