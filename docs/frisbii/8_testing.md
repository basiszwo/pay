# Testing with Frisbii

## Test Environment Setup

### Using Test API Keys

Frisbii provides test API keys for development:

```ruby
# config/credentials/development.yml
frisbii:
  private_key: priv_test_xxxxx  # Test mode key
  public_key: pub_test_xxxxx
  signing_secret: whsec_test_xxxxx
```

Test keys process payments in test mode without real charges.

### Using FakeProcessor

For unit tests, use the FakeProcessor to avoid API calls:

```ruby
# spec/rails_helper.rb or test/test_helper.rb
Pay.enabled_processors = [:fake_processor]

# In tests
before do
  user.set_payment_processor :fake_processor
end
```

## Testing Charges

### Unit Tests

```ruby
# spec/models/payment_spec.rb
RSpec.describe Payment do
  let(:user) { create(:user) }

  before do
    user.set_payment_processor :fake_processor
  end

  it "creates a charge" do
    charge = user.payment_processor.charge(1000)

    expect(charge).to be_persisted
    expect(charge.amount).to eq(1000)
    expect(charge.status).to eq("succeeded")
  end

  it "handles failed charges" do
    allow_any_instance_of(Pay::FakeProcessor::Customer)
      .to receive(:charge)
      .and_raise(Pay::Error, "Card declined")

    expect {
      user.payment_processor.charge(1000)
    }.to raise_error(Pay::Error, "Card declined")
  end
end
```

### Integration Tests

```ruby
# spec/requests/payments_spec.rb
RSpec.describe "Payments", type: :request do
  it "processes payment successfully" do
    user = create(:user)
    sign_in user

    post payments_path, params: {
      amount: 1000,
      payment_method: "pm_test_123"
    }

    expect(response).to redirect_to(success_path)
    expect(user.payment_processor.charges.count).to eq(1)
  end
end
```

## Testing Subscriptions

```ruby
# spec/models/subscription_spec.rb
RSpec.describe Subscription do
  let(:user) { create(:user) }

  before do
    user.set_payment_processor :fake_processor
  end

  it "creates a subscription" do
    subscription = user.payment_processor.subscribe(
      plan: "monthly_plan"
    )

    expect(subscription).to be_active
    expect(subscription.processor_plan).to eq("monthly_plan")
  end

  it "cancels a subscription" do
    subscription = user.payment_processor.subscribe(
      plan: "monthly_plan"
    )

    subscription.cancel

    expect(subscription).to be_canceled
    expect(subscription.ends_at).to be_present
  end

  it "handles trial periods" do
    subscription = user.payment_processor.subscribe(
      plan: "monthly_plan",
      trial_period_days: 14
    )

    expect(subscription).to be_on_trial
    expect(subscription.trial_ends_at).to be_within(1.minute).of(14.days.from_now)
  end
end
```

## Testing Webhooks

### Webhook Controller Tests

```ruby
# spec/controllers/webhooks_controller_spec.rb
RSpec.describe Pay::Webhooks::FrisbiiController do
  let(:webhook_secret) { "test_secret" }

  before do
    allow(Pay::Frisbii).to receive(:signing_secret).and_return(webhook_secret)
  end

  it "processes valid webhook" do
    event = build_webhook_event("invoice_settled")
    signature = calculate_signature(event)
    event["signature"] = signature

    post pay.webhooks_frisbii_path,
      params: event.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:ok)
    expect(Pay::Webhook.count).to eq(1)
  end

  it "rejects invalid signature" do
    event = build_webhook_event("invoice_settled")
    event["signature"] = "invalid"

    post pay.webhooks_frisbii_path,
      params: event.to_json,
      headers: { "Content-Type" => "application/json" }

    expect(response).to have_http_status(:bad_request)
  end

  private

  def build_webhook_event(type)
    {
      "id" => "webhook_#{SecureRandom.hex}",
      "event_id" => "event_#{SecureRandom.hex}",
      "event_type" => type,
      "timestamp" => Time.current.iso8601,
      "invoice" => {
        "id" => "inv_test_123",
        "amount" => 1000,
        "currency" => "USD"
      }
    }
  end

  def calculate_signature(event)
    message = "#{event["timestamp"]}#{event["id"]}"
    OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, message)
  end
end
```

### Webhook Handler Tests

```ruby
# spec/lib/pay/frisbii/webhooks/invoice_settled_spec.rb
RSpec.describe Pay::Frisbii::Webhooks::InvoiceSettled do
  let(:handler) { described_class.new }
  let(:user) { create(:user) }

  before do
    user.set_payment_processor :frisbii
    user.payment_processor.update!(processor_id: "cust_test_123")
  end

  it "syncs charge from webhook" do
    event = {
      "invoice" => {
        "id" => "inv_test_123",
        "amount" => 1000,
        "currency" => "USD",
        "state" => "settled",
        "customer" => "cust_test_123"
      }
    }

    expect {
      handler.call(event)
    }.to change { Pay::Charge.count }.by(1)

    charge = Pay::Charge.last
    expect(charge.processor_id).to eq("inv_test_123")
    expect(charge.amount).to eq(1000)
  end
end
```

## Mocking API Calls

### Using WebMock

```ruby
# spec/support/frisbii_helpers.rb
module FrisbiiHelpers
  def stub_frisbii_customer_create
    stub_request(:post, "https://api.frisbii.com/v1/customer")
      .to_return(
        status: 200,
        body: {
          handle: "cust_test_123",
          email: "test@example.com"
        }.to_json
      )
  end

  def stub_frisbii_charge_create
    stub_request(:post, "https://api.frisbii.com/v1/charge")
      .to_return(
        status: 200,
        body: {
          id: "charge_test_123",
          amount: 1000,
          state: "settled"
        }.to_json
      )
  end
end

RSpec.configure do |config|
  config.include FrisbiiHelpers
end
```

### Using VCR

```ruby
# spec/support/vcr.rb
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data("<FRISBII_KEY>") { Pay::Frisbii.private_key }
  config.filter_sensitive_data("<WEBHOOK_SECRET>") { Pay::Frisbii.signing_secret }
end

# In tests
it "creates a real charge", :vcr do
  # This will record/replay actual API calls
  charge = user.payment_processor.charge(1000)
  expect(charge).to be_persisted
end
```

## Test Data

### Factory Definitions

```ruby
# spec/factories/pay.rb
FactoryBot.define do
  factory :pay_customer, class: "Pay::Customer" do
    owner { create(:user) }
    processor { "frisbii" }
    processor_id { "cust_test_#{SecureRandom.hex}" }
  end

  factory :pay_charge, class: "Pay::Charge" do
    customer { create(:pay_customer) }
    processor_id { "charge_test_#{SecureRandom.hex}" }
    amount { 1000 }
    currency { "USD" }
    status { "succeeded" }
  end

  factory :pay_subscription, class: "Pay::Subscription" do
    customer { create(:pay_customer) }
    name { "default" }
    processor_id { "sub_test_#{SecureRandom.hex}" }
    processor_plan { "monthly_plan" }
    status { "active" }
    current_period_start { Time.current }
    current_period_end { 1.month.from_now }
  end
end
```

## System Tests

```ruby
# spec/system/payment_flow_spec.rb
RSpec.describe "Payment Flow", type: :system do
  it "completes checkout process" do
    user = create(:user)
    sign_in user

    visit pricing_path
    click_button "Subscribe to Premium"

    # Fill in payment details
    fill_in "Card number", with: "4242424242424242"
    fill_in "Expiry", with: "12/25"
    fill_in "CVC", with: "123"

    click_button "Subscribe"

    expect(page).to have_content("Subscription created successfully")
    expect(user.payment_processor.subscriptions.count).to eq(1)
  end
end
```

## CI/CD Configuration

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    env:
      FRISBII_PRIVATE_KEY: priv_test_ci_key
      FRISBII_SIGNING_SECRET: whsec_test_ci_secret

    steps:
      - uses: actions/checkout@v2
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bundle exec rspec
```

## Best Practices

1. **Use FakeProcessor for unit tests** - Faster and more reliable
2. **Use test API keys for integration tests** - Real API behavior
3. **Mock external calls in CI** - Avoid flaky tests
4. **Test error scenarios** - Not just happy paths
5. **Test webhooks thoroughly** - Critical for data sync
6. **Use factories for test data** - Consistent and maintainable
