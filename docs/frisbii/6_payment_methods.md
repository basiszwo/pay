# Frisbii Payment Methods

## Adding Payment Methods

### Add from Token

```ruby
# Add payment method using token from Frisbii.js
payment_method = user.payment_processor.add_payment_method(
  "pm_token_xxxxx",
  default: true
)
```

### Add with Options

```ruby
payment_method = user.payment_processor.add_payment_method(
  token,
  default: true,
  metadata: {
    source: "checkout_page",
    added_by: "user"
  }
)
```

## Managing Payment Methods

### List Payment Methods

```ruby
# Get all payment methods
payment_methods = user.payment_processor.payment_methods

# Get default payment method
default = user.payment_processor.default_payment_method

# Filter by type
cards = payment_methods.where(type: "card")
```

### Set Default Payment Method

```ruby
# Make a payment method default
payment_method.make_default!

# This will unset any other default payment methods
```

### Remove Payment Method

```ruby
# Remove from Frisbii and local database
payment_method.detach
```

## Payment Method Types

Frisbii supports various payment method types:

- `card` - Credit/debit cards
- `bank_account` - Bank transfers/SEPA
- `paypal` - PayPal accounts
- `mobilepay` - MobilePay (Nordic)
- `vipps` - Vipps (Norway)
- `swish` - Swish (Sweden)

## Payment Method Attributes

```ruby
# Access payment method details
payment_method.type          # "card", "bank_account", etc.
payment_method.brand         # "visa", "mastercard", etc.
payment_method.last4         # Last 4 digits
payment_method.exp_month     # Expiration month (cards)
payment_method.exp_year      # Expiration year (cards)
payment_method.email         # Associated email
payment_method.bank          # Bank name (bank accounts)
payment_method.default       # Is default?
payment_method.processor_id  # Frisbii ID
```

## Card-specific Details

```ruby
if payment_method.type == "card"
  puts "Card: #{payment_method.brand} ending in #{payment_method.last4}"
  puts "Expires: #{payment_method.exp_month}/#{payment_method.exp_year}"
end
```

## Bank Account Details

```ruby
if payment_method.type == "bank_account"
  puts "Bank: #{payment_method.bank}"
  puts "Account ending in: #{payment_method.last4}"
end
```

## Syncing Payment Methods

```ruby
# Sync from Frisbii API
Pay::Frisbii::PaymentMethod.sync("pm_xxxxx")

# Sync from webhook event
payment_method = Pay::Frisbii::PaymentMethod.sync(
  event["payment_method"]["id"],
  object: event["payment_method"]
)
```

## Payment Method Validation

```ruby
# Check if customer has payment methods
if user.payment_processor.payment_methods.any?
  # Can process payments
else
  # Need to add payment method
  redirect_to add_payment_method_path
end

# Check for default payment method
unless user.payment_processor.default_payment_method
  flash[:alert] = "Please set a default payment method"
end
```

## Updating Payment Methods

Payment methods are typically immutable. To update:

1. Add the new payment method
2. Set it as default if needed
3. Remove the old payment method

```ruby
# Replace a payment method
old_method = user.payment_processor.default_payment_method
new_method = user.payment_processor.add_payment_method(new_token)
new_method.make_default!
old_method.detach
```

## Frontend Integration

### Frisbii.js Setup

```html
<!-- Include Frisbii.js -->
<script src="https://checkout.frisbii.com/v1/checkout.js"></script>

<script>
  // Initialize with public key
  const frisbii = Frisbii('pub_your_public_key');

  // Create payment method
  frisbii.createPaymentMethod({
    card: {
      number: '4242424242424242',
      exp_month: 12,
      exp_year: 2025,
      cvc: '123'
    }
  }).then(function(result) {
    // Send result.token to your server
    submitPaymentMethod(result.token);
  });
</script>
```

### Rails Controller

```ruby
class PaymentMethodsController < ApplicationController
  def create
    payment_method = current_user.payment_processor.add_payment_method(
      params[:payment_method_token],
      default: true
    )

    if payment_method.persisted?
      redirect_to account_path, notice: "Payment method added"
    else
      redirect_to account_path, alert: "Failed to add payment method"
    end
  end

  def destroy
    payment_method = current_user.payment_processor.payment_methods.find(params[:id])
    payment_method.detach
    redirect_to account_path, notice: "Payment method removed"
  end

  def set_default
    payment_method = current_user.payment_processor.payment_methods.find(params[:id])
    payment_method.make_default!
    redirect_to account_path, notice: "Default payment method updated"
  end
end
```

## Payment Method Events

Webhook events for payment methods:

- `payment_method_created` - New payment method added
- `payment_method_updated` - Payment method updated
- `payment_method_deleted` - Payment method removed

## Security Considerations

1. **Never store card numbers** - Only store tokens
2. **Use HTTPS** - Always use SSL in production
3. **Validate tokens server-side** - Don't trust client data
4. **PCI compliance** - Use Frisbii.js to avoid PCI scope
5. **Limit payment methods** - Consider max per customer
