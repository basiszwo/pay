# Frisbii Error Handling

## Error Class

All Frisbii errors inherit from `Pay::Frisbii::Error`:

```ruby
begin
  user.payment_processor.charge(1000)
rescue Pay::Frisbii::Error => e
  Rails.logger.error "Frisbii error: #{e.message}"
  Rails.logger.error "Error code: #{e.code}" if e.code
  Rails.logger.error "Response: #{e.response}" if e.response
end
```

## Common Error Scenarios

### Payment Failures

```ruby
begin
  charge = user.payment_processor.charge(1000)
rescue Pay::Frisbii::Error => e
  case e.code
  when "insufficient_funds"
    flash[:alert] = "Your card has insufficient funds."
  when "card_declined"
    flash[:alert] = "Your card was declined."
  when "expired_card"
    flash[:alert] = "Your card has expired."
  when "processing_error"
    flash[:alert] = "Payment processing error. Please try again."
  else
    flash[:alert] = "Payment failed: #{e.message}"
  end

  redirect_to checkout_path
end
```

### Subscription Errors

```ruby
begin
  subscription = user.payment_processor.subscribe(plan: "premium")
rescue Pay::Frisbii::Error => e
  if e.message.include?("payment_method_required")
    redirect_to add_payment_method_path,
      alert: "Please add a payment method first"
  elsif e.message.include?("plan_not_found")
    redirect_to pricing_path,
      alert: "Invalid subscription plan"
  else
    redirect_to account_path,
      alert: "Could not create subscription"
  end
end
```

### API Connection Errors

```ruby
begin
  user.payment_processor.charge(1000)
rescue RestClient::Exception => e
  # Network or connection error
  Rails.logger.error "API connection failed: #{e.message}"
  flash[:alert] = "Connection error. Please try again later."
rescue Pay::Frisbii::Error => e
  # Frisbii-specific error
  handle_frisbii_error(e)
end
```

## Error Codes

Common Frisbii error codes:

- `insufficient_funds` - Not enough money
- `card_declined` - Card declined by issuer
- `expired_card` - Card expired
- `invalid_number` - Invalid card number
- `invalid_cvc` - Invalid security code
- `incorrect_cvc` - Incorrect security code
- `processing_error` - Generic processing error
- `authentication_required` - 3D Secure required
- `payment_method_required` - No payment method
- `plan_not_found` - Invalid plan ID
- `customer_not_found` - Invalid customer

## Webhook Error Handling

```ruby
# In webhook handlers
module Pay
  module Frisbii
    module Webhooks
      class InvoiceSettled
        def call(event)
          # Process webhook
          Pay::Frisbii::Charge.sync(event["invoice"]["id"])
        rescue => e
          # Log but don't raise - avoid webhook retries for data issues
          Rails.logger.error "[Pay] Webhook processing failed: #{e.message}"

          # Optionally notify error tracking
          Sentry.capture_exception(e) if defined?(Sentry)

          # Return success to prevent retries
          true
        end
      end
    end
  end
end
```

## Retry Logic

Implement retry logic for transient failures:

```ruby
def charge_with_retry(amount, options = {})
  retries = 0
  max_retries = 3

  begin
    user.payment_processor.charge(amount, options)
  rescue Pay::Frisbii::Error => e
    if retries < max_retries && retryable_error?(e)
      retries += 1
      sleep(retries ** 2) # Exponential backoff
      retry
    else
      raise
    end
  end
end

def retryable_error?(error)
  ["timeout", "connection_failed", "processing_error"].include?(error.code)
end
```

## User-Friendly Messages

```ruby
class PaymentErrorHandler
  ERROR_MESSAGES = {
    "insufficient_funds" => "Your card has insufficient funds. Please try another card.",
    "card_declined" => "Your card was declined. Please contact your bank.",
    "expired_card" => "Your card has expired. Please update your payment method.",
    "invalid_number" => "Invalid card number. Please check and try again.",
    "authentication_required" => "Additional authentication required. Please complete verification."
  }.freeze

  def self.message_for(error)
    ERROR_MESSAGES[error.code] || "Payment failed. Please try again or contact support."
  end
end

# Usage
begin
  charge = user.payment_processor.charge(1000)
rescue Pay::Frisbii::Error => e
  flash[:alert] = PaymentErrorHandler.message_for(e)
end
```

## Logging Best Practices

```ruby
def process_payment(amount)
  Rails.logger.info "[Payment] Starting charge for user #{current_user.id}, amount: #{amount}"

  charge = current_user.payment_processor.charge(amount)

  Rails.logger.info "[Payment] Success - Charge ID: #{charge.processor_id}"
  charge
rescue Pay::Frisbii::Error => e
  Rails.logger.error "[Payment] Failed for user #{current_user.id}"
  Rails.logger.error "[Payment] Error: #{e.message}, Code: #{e.code}"
  Rails.logger.error "[Payment] Backtrace: #{e.backtrace.first(5).join("\n")}"

  # Track in analytics
  Analytics.track(
    user_id: current_user.id,
    event: "Payment Failed",
    properties: {
      error_code: e.code,
      error_message: e.message,
      amount: amount
    }
  )

  raise
end
```

## Error Monitoring

Integrate with error tracking services:

```ruby
# config/initializers/sentry.rb
Sentry.configure do |config|
  config.before_send = lambda do |event, hint|
    # Add Frisbii context to errors
    if hint[:exception].is_a?(Pay::Frisbii::Error)
      event.extra[:frisbii_error_code] = hint[:exception].code
      event.extra[:frisbii_response] = hint[:exception].response
    end
    event
  end
end
```

## Testing Error Scenarios

```ruby
# spec/controllers/payments_controller_spec.rb
RSpec.describe PaymentsController do
  it "handles insufficient funds" do
    allow_any_instance_of(Pay::Frisbii::Customer)
      .to receive(:charge)
      .and_raise(Pay::Frisbii::Error.new("Insufficient funds",
        {"error_code" => "insufficient_funds"}))

    post :create, params: { amount: 1000 }

    expect(flash[:alert]).to include("insufficient funds")
    expect(response).to redirect_to(checkout_path)
  end
end
```

## Best Practices

1. **Always catch specific errors** - Don't use bare rescue
2. **Log all payment errors** - For debugging and auditing
3. **Show user-friendly messages** - Don't expose technical details
4. **Implement retry logic** - For transient failures
5. **Monitor error rates** - Set up alerts for spikes
6. **Test error paths** - Ensure graceful degradation
