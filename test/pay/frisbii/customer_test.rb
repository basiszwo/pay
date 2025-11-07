require "test_helper"

class Pay::Frisbii::CustomerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @pay_customer = @user.payment_processor
    @pay_customer.processor = "frisbii"
    @pay_customer.processor_id = "cust_test_123"
    @pay_customer.save!
  end

  test "frisbii customer can be created" do
    assert_not_nil @pay_customer
    assert_equal "frisbii", @pay_customer.processor
  end

  test "can retrieve api_record" do
    # Stub the API request
    stub_frisbii_request(:get, "/customer/cust_test_123", body: frisbii_customer_response)

    customer = @pay_customer.api_record
    assert_not_nil customer
    assert_equal "cust_test_123", customer["handle"]
  end

  test "can create a charge" do
    # Stub the charge creation request
    stub_frisbii_request(:post, "/charge", body: frisbii_charge_response)

    charge = @pay_customer.charge(1000, currency: "USD", description: "Test charge")
    assert_not_nil charge
    assert_equal 1000, charge.amount
    assert_equal "USD", charge.currency
  end

  test "can create a subscription" do
    # Stub the subscription creation request
    stub_frisbii_request(:post, "/subscription", body: frisbii_subscription_response)

    subscription = @pay_customer.subscribe(plan: "monthly_plan")
    assert_not_nil subscription
    assert_equal "monthly_plan", subscription.processor_plan
  end

  test "can add payment method" do
    # Stub the payment method creation request
    stub_frisbii_request(:post, "/customer/cust_test_123/payment_method", body: frisbii_payment_method_response)

    payment_method = @pay_customer.add_payment_method("pm_test_token")
    assert_not_nil payment_method
    assert_equal "card", payment_method.type
  end

  test "can sync subscriptions" do
    # Stub the subscriptions list request
    stub_frisbii_request(:get, "/subscription?customer=cust_test_123", body: [frisbii_subscription_response])

    subscriptions = @pay_customer.sync_subscriptions
    assert_not_nil subscriptions
    assert_equal 1, subscriptions.count
  end

  private

  def stub_frisbii_request(method, path, body:, status: 200)
    # This would need to be implemented based on your testing framework
    # Using WebMock, VCR, or similar library
  end

  def frisbii_customer_response
    {
      "handle" => "cust_test_123",
      "email" => "test@example.com",
      "first_name" => "Test",
      "last_name" => "User",
      "created" => Time.current.iso8601
    }
  end

  def frisbii_charge_response
    {
      "id" => "charge_test_123",
      "amount" => 1000,
      "currency" => "USD",
      "state" => "settled",
      "customer" => "cust_test_123",
      "created" => Time.current.iso8601
    }
  end

  def frisbii_subscription_response
    {
      "handle" => "sub_test_123",
      "customer" => "cust_test_123",
      "plan" => "monthly_plan",
      "state" => "active",
      "quantity" => 1,
      "created" => Time.current.iso8601
    }
  end

  def frisbii_payment_method_response
    {
      "id" => "pm_test_123",
      "customer" => "cust_test_123",
      "type" => "card",
      "card_type" => "visa",
      "last4" => "4242",
      "exp_month" => 12,
      "exp_year" => 2025
    }
  end
end