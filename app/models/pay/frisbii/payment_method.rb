module Pay
  module Frisbii
    class PaymentMethod < Pay::PaymentMethod
      # Sync a payment method from the Frisbii API
      def self.sync(payment_method_id, object: nil)
        object ||= Pay::Frisbii.api_request(:get, "/payment_method/#{payment_method_id}")

        # Find customer by processor_id
        pay_customer = Pay::Customer.find_by(processor: :frisbii, processor_id: object["customer"])
        return unless pay_customer

        # Find or initialize the payment method
        pay_payment_method = pay_customer.payment_methods.find_or_initialize_by(processor_id: object["id"])
        pay_payment_method.sync!(object: object)
        pay_payment_method
      rescue => e
        raise Pay::Frisbii::Error, "Unable to sync payment method #{payment_method_id}: #{e.message}"
      end

      # Sync this payment method with latest data from Frisbii
      def sync!(object: nil)
        object ||= api_record

        # Extract payment method details
        attributes = extract_attributes(object)

        # Update the payment method
        update!(
          processor_id: object["id"],
          type: payment_type(object),
          default: customer.payment_methods.none? || object["default"],
          data: object,
          **attributes
        )
      end

      # Retrieve the payment method from Frisbii API
      def api_record
        @api_record ||= Pay::Frisbii.api_request(:get, "/payment_method/#{processor_id}")
      rescue => e
        raise Pay::Frisbii::Error, "Unable to fetch payment method: #{e.message}"
      end

      # Make this payment method the default for the customer
      def make_default!
        # First, unset any existing defaults
        customer.payment_methods.where(default: true).where.not(id: id).update_all(default: false)

        # Set this as default in Frisbii
        Pay::Frisbii.api_request(:post, "/customer/#{customer.processor_id}/payment_method/#{processor_id}/default", {})

        # Update local record
        update!(default: true)
      rescue => e
        raise Pay::Frisbii::Error, "Unable to set default payment method: #{e.message}"
      end

      # Remove the payment method
      def detach
        # Delete from Frisbii
        Pay::Frisbii.api_request(:delete, "/customer/#{customer.processor_id}/payment_method/#{processor_id}")

        # Delete local record
        destroy
      rescue => e
        raise Pay::Frisbii::Error, "Unable to detach payment method: #{e.message}"
      end

      private

      def payment_type(object)
        case object["type"]
        when "card", "card_token"
          "card"
        when "mobilepay", "vipps", "swish"
          "mobile_payment"
        when "paypal"
          "paypal"
        when "bank", "sepa", "bank_transfer"
          "bank_account"
        else
          object["type"]
        end
      end

      def extract_attributes(object)
        attrs = {}

        case object["type"]
        when "card", "card_token"
          # Extract card details
          attrs[:brand] = object["card_type"] || object["brand"]
          attrs[:last4] = extract_last4(object)
          attrs[:exp_month] = object["exp_month"]
          attrs[:exp_year] = object["exp_year"]

        when "mobilepay", "vipps", "swish"
          # Mobile payment methods typically have phone or email
          attrs[:username] = object["phone"] || object["email"]

        when "paypal"
          # PayPal typically has email
          attrs[:email] = object["email"]

        when "bank", "sepa", "bank_transfer"
          # Bank account details
          attrs[:bank] = object["bank_name"] || object["bank"]
          attrs[:last4] = extract_last4(object)
        end

        # Add common fields
        attrs[:email] ||= object["email"] if object["email"]

        attrs
      end

      def extract_last4(object)
        # Try different possible fields for last 4 digits
        if object["masked_card"]
          # Extract last 4 from masked card number (e.g., "XXXX-XXXX-XXXX-1234")
          object["masked_card"].gsub(/[^0-9]/, "").last(4)
        elsif object["last4"]
          object["last4"]
        elsif object["account_number"]
          # For bank accounts
          object["account_number"].last(4)
        end
      end
    end
  end
end

# Ensure ActiveSupport knows about this class for loading hooks
ActiveSupport.run_load_hooks :pay_frisbii_payment_method, Pay::Frisbii::PaymentMethod