require "test_helper"

class Pay::Frisbii::WebhookTest < ActiveSupport::TestCase
  setup do
    @webhook_secret = "test_webhook_secret"
    Pay::Frisbii.stubs(:signing_secret).returns(@webhook_secret)
  end

  test "webhook signature verification succeeds with valid signature" do
    event = build_webhook_event
    signature = calculate_valid_signature(event)
    event["signature"] = signature

    controller = Pay::Webhooks::FrisbiiController.new
    assert_nothing_raised do
      controller.send(:verify_signature, event, event.to_json)
    end
  end

  test "webhook signature verification fails with invalid signature" do
    event = build_webhook_event
    event["signature"] = "invalid_signature"

    controller = Pay::Webhooks::FrisbiiController.new
    assert_raises(Pay::Frisbii::Error) do
      controller.send(:verify_signature, event, event.to_json)
    end
  end

  test "invoice_settled webhook processes charge" do
    event = build_webhook_event(
      event_type: "invoice_settled",
      invoice: {
        "id" => "charge_123",
        "amount" => 1000,
        "currency" => "USD",
        "state" => "settled",
        "customer" => "cust_123"
      }
    )

    # Stub customer lookup
    customer = mock_customer
    Pay::Customer.stubs(:find_by).returns(customer)

    # Process webhook
    handler = Pay::Frisbii::Webhooks::InvoiceSettled.new
    handler.call(event)

    # Verify charge was synced
    charge = customer.charges.last
    assert_equal "charge_123", charge.processor_id
    assert_equal 1000, charge.amount
  end

  test "subscription_created webhook processes subscription" do
    event = build_webhook_event(
      event_type: "subscription_created",
      subscription: {
        "handle" => "sub_123",
        "customer" => "cust_123",
        "plan" => "monthly_plan",
        "state" => "active"
      }
    )

    # Stub customer lookup
    customer = mock_customer
    Pay::Customer.stubs(:find_by).returns(customer)

    # Process webhook
    handler = Pay::Frisbii::Webhooks::SubscriptionCreated.new
    handler.call(event)

    # Verify subscription was synced
    subscription = customer.subscriptions.last
    assert_equal "sub_123", subscription.processor_id
    assert_equal "monthly_plan", subscription.processor_plan
  end

  test "subscription_cancelled webhook updates subscription status" do
    event = build_webhook_event(
      event_type: "subscription_cancelled",
      subscription: {
        "handle" => "sub_123",
        "customer" => "cust_123",
        "plan" => "monthly_plan",
        "state" => "cancelled",
        "expires" => 1.month.from_now.iso8601
      }
    )

    # Stub customer lookup
    customer = mock_customer
    Pay::Customer.stubs(:find_by).returns(customer)

    # Create existing subscription
    subscription = customer.subscriptions.create!(
      processor_id: "sub_123",
      processor_plan: "monthly_plan",
      status: "active"
    )

    # Process webhook
    handler = Pay::Frisbii::Webhooks::SubscriptionCancelled.new
    handler.call(event)

    # Verify subscription was updated
    subscription.reload
    assert_equal "canceled", subscription.status
    assert_not_nil subscription.ends_at
  end

  private

  def build_webhook_event(event_type: "test_event", **data)
    event = {
      "id" => "webhook_#{SecureRandom.hex(8)}",
      "event_id" => "event_#{SecureRandom.hex(8)}",
      "event_type" => event_type,
      "timestamp" => Time.current.iso8601
    }
    event.merge!(data)
    event
  end

  def calculate_valid_signature(event)
    timestamp = event["timestamp"]
    event_id = event["id"]
    message = "#{timestamp}#{event_id}"
    OpenSSL::HMAC.hexdigest("SHA256", @webhook_secret, message)
  end

  def mock_customer
    customer = mock("customer")
    customer.stubs(:processor).returns("frisbii")
    customer.stubs(:processor_id).returns("cust_123")
    customer.stubs(:charges).returns(mock_relation)
    customer.stubs(:subscriptions).returns(mock_relation)
    customer
  end

  def mock_relation
    relation = mock("relation")
    relation.stubs(:find_or_initialize_by).returns(mock_record)
    relation.stubs(:create!).returns(mock_record)
    relation.stubs(:last).returns(mock_record)
    relation
  end

  def mock_record
    record = mock("record")
    record.stubs(:sync!).returns(true)
    record.stubs(:processor_id).returns("test_123")
    record.stubs(:amount).returns(1000)
    record.stubs(:processor_plan).returns("monthly_plan")
    record.stubs(:status).returns("active")
    record.stubs(:status=)
    record.stubs(:ends_at=)
    record.stubs(:reload).returns(record)
    record
  end
end