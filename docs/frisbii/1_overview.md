# Frisbii Overview

Frisbii integration for the Pay gem enables you to process payments, manage subscriptions, and handle webhooks through the Frisbii payment platform (formerly Reepay).

## Features

- **One-time charges** - Process single payments with or without authorization
- **Subscriptions** - Create and manage recurring billing
- **Payment methods** - Store and manage customer payment methods
- **Webhooks** - Real-time event notifications
- **Refunds** - Full and partial refund support
- **Customer portal** - Allow customers to manage their billing

## Requirements

- Rails 6.0+
- Ruby 2.7+
- RestClient gem (~> 2.0)
- Frisbii account with API access

## Installation

1. Add to your Gemfile:

```ruby
gem 'rest-client', '~> 2.0'
```

2. Enable Frisbii in your Pay configuration:

```ruby
# config/initializers/pay.rb
Pay.setup do |config|
  config.enabled_processors = [:frisbii]
end
```

3. Configure your API credentials (see [Credentials](2_credentials.md))

## Basic Usage

### Setting up a Customer

```ruby
# Set Frisbii as the payment processor
user = User.find(1)
user.set_payment_processor :frisbii
```

### Creating a Charge

```ruby
# Create a one-time charge (amount in cents)
charge = user.payment_processor.charge(1000, {
  currency: "USD",
  description: "One-time payment"
})
```

### Creating a Subscription

```ruby
# Subscribe to a plan
subscription = user.payment_processor.subscribe(
  plan: "monthly_plan",
  trial_period_days: 7
)
```

## Payment Flow

1. **Customer Creation** - Automatically created when setting payment processor
2. **Payment Method** - Add via token from Frisbii.js or API
3. **Charge/Subscribe** - Process payment or start subscription
4. **Webhook Processing** - Handle events asynchronously
5. **Email Notifications** - Automatic receipts and notifications

## Architecture

The Frisbii integration follows the Pay gem's standard architecture:

- **Customer** (`Pay::Frisbii::Customer`) - Manages billable entities
- **Charge** (`Pay::Frisbii::Charge`) - Handles one-time payments
- **Subscription** (`Pay::Frisbii::Subscription`) - Manages recurring billing
- **PaymentMethod** (`Pay::Frisbii::PaymentMethod`) - Stores payment methods
- **Webhooks** - Event handlers for real-time updates

## Support

- [Frisbii Documentation](https://docs.frisbii.com)
- [Frisbii API Reference](https://docs.frisbii.com/reference)
- [Pay Gem Issues](https://github.com/pay-rails/pay/issues)
