require "pay/env"

module Pay
  module Frisbii
    autoload :Customer, "pay/frisbii/customer"
    autoload :Charge, "pay/frisbii/charge"
    autoload :PaymentMethod, "pay/frisbii/payment_method"
    autoload :Subscription, "pay/frisbii/subscription"
    autoload :Merchant, "pay/frisbii/merchant"
    autoload :Error, "pay/frisbii/error"

    # API endpoint for Frisbii
    mattr_accessor :api_base_url
    @@api_base_url = "https://api.frisbii.com"

    # API version for Frisbii (they use v1)
    mattr_accessor :api_version
    @@api_version = "v1"

    # For holding API key
    mattr_accessor :private_key

    class << self
      def enabled?
        return false unless Pay.enabled_processors.include?(:frisbii) && defined?(::RestClient)

        Pay::Engine.version_matches?(required: "~> 2.0", current: ::RestClient::VERSION) || (raise "[Pay] rest-client gem must be version ~> 2.0")
      end

      def setup
        Pay.config.application_name ||= Rails.application.class.module_parent_name

        # Set API key from Rails credentials
        secrets = Rails.application.credentials.frisbii
        return unless secrets

        self.private_key = secrets[:private_key]
      end

      def public_key
        find_value_by_name(:frisbii, :public_key)
      end

      def signing_secret
        find_value_by_name(:frisbii, :signing_secret)
      end

      def configure_webhooks
        Pay::Webhooks.configure do |events|
          # Customer events
          events.subscribe "frisbii.customer_created", Pay::Frisbii::Webhooks::CustomerCreated.new
          events.subscribe "frisbii.customer_updated", Pay::Frisbii::Webhooks::CustomerUpdated.new
          events.subscribe "frisbii.customer_deleted", Pay::Frisbii::Webhooks::CustomerDeleted.new

          # Payment/Charge events (invoice events in Frisbii)
          events.subscribe "frisbii.invoice_settled", Pay::Frisbii::Webhooks::InvoiceSettled.new
          events.subscribe "frisbii.invoice_authorized", Pay::Frisbii::Webhooks::InvoiceAuthorized.new
          events.subscribe "frisbii.invoice_failed", Pay::Frisbii::Webhooks::InvoiceFailed.new
          events.subscribe "frisbii.invoice_refunded", Pay::Frisbii::Webhooks::InvoiceRefunded.new
          events.subscribe "frisbii.invoice_cancelled", Pay::Frisbii::Webhooks::InvoiceCancelled.new

          # Subscription events
          events.subscribe "frisbii.subscription_created", Pay::Frisbii::Webhooks::SubscriptionCreated.new
          events.subscribe "frisbii.subscription_renewal", Pay::Frisbii::Webhooks::SubscriptionRenewal.new
          events.subscribe "frisbii.subscription_cancelled", Pay::Frisbii::Webhooks::SubscriptionCancelled.new
          events.subscribe "frisbii.subscription_uncancelled", Pay::Frisbii::Webhooks::SubscriptionUncancelled.new
          events.subscribe "frisbii.subscription_on_hold", Pay::Frisbii::Webhooks::SubscriptionOnHold.new
          events.subscribe "frisbii.subscription_reactivated", Pay::Frisbii::Webhooks::SubscriptionReactivated.new
          events.subscribe "frisbii.subscription_expired", Pay::Frisbii::Webhooks::SubscriptionExpired.new
          events.subscribe "frisbii.subscription_trial_end", Pay::Frisbii::Webhooks::SubscriptionTrialEnd.new

          # Payment method events
          events.subscribe "frisbii.payment_method_created", Pay::Frisbii::Webhooks::PaymentMethodCreated.new
          events.subscribe "frisbii.payment_method_updated", Pay::Frisbii::Webhooks::PaymentMethodUpdated.new
          events.subscribe "frisbii.payment_method_deleted", Pay::Frisbii::Webhooks::PaymentMethodDeleted.new
        end
      end

      # Make an API request to Frisbii
      def api_request(method, path, params = {})
        url = "#{api_base_url}/#{api_version}#{path}"
        auth = {username: private_key, password: ""}

        begin
          response = case method.downcase.to_sym
          when :get
            RestClient::Request.execute(method: :get, url: url, user: auth[:username], password: auth[:password])
          when :post
            RestClient::Request.execute(method: :post, url: url, payload: params.to_json, user: auth[:username], password: auth[:password], headers: {content_type: :json})
          when :put
            RestClient::Request.execute(method: :put, url: url, payload: params.to_json, user: auth[:username], password: auth[:password], headers: {content_type: :json})
          when :delete
            RestClient::Request.execute(method: :delete, url: url, user: auth[:username], password: auth[:password])
          end

          JSON.parse(response.body)
        rescue RestClient::Exception => e
          raise Pay::Frisbii::Error.new(e.message, e.response)
        end
      end

      def find_value_by_name(scope, name)
        if Pay.application_owner_class.respond_to?(:pay_environments)
          Pay.application_owner_class.send(:pay_environments).dig(scope, name)
        else
          Rails.application.credentials.dig(scope, name)
        end
      end
    end
  end
end