module Pay
  module Frisbii
    class Charge < Pay::Charge
      # Syncs a charge from the Frisbii API
      def self.sync(charge_id, object: nil, try: 0, retries: 1)
        object ||= Pay::Frisbii.api_request(:get, "/charge/#{charge_id}")

        # Find customer by processor_id
        pay_customer = Pay::Customer.find_by(processor: :frisbii, processor_id: object["customer"])
        return unless pay_customer

        # Find or initialize the charge
        pay_charge = pay_customer.charges.find_or_initialize_by(processor_id: object["id"])
        pay_charge.sync!(object: object)
        pay_charge
      rescue => e
        if try < retries
          sleep 0.5
          try += 1
          retry
        else
          raise Pay::Frisbii::Error, "Unable to sync charge #{charge_id}: #{e.message}"
        end
      end

      # Sync this charge with latest data from Frisbii
      def sync!(object: nil)
        object ||= api_record

        # Map Frisbii charge states to Pay charge attributes
        update!(
          processor_id: object["id"],
          amount: object["amount"],
          currency: object["currency"],
          status: frisbii_status_to_pay_status(object["state"]),
          created_at: Time.parse(object["created"]) rescue Time.current,
          metadata: object["metadata"],
          data: object,
          # Refund information
          amount_refunded: object["refunded_amount"] || 0,
          # Extract payment method details
          payment_method_type: extract_payment_method_type(object),
          brand: extract_brand(object),
          last4: extract_last4(object),
          exp_month: extract_exp_month(object),
          exp_year: extract_exp_year(object),
          email: object["email"],
          # Additional fields
          application_fee_amount: object["application_fee_amount"]
        )
      end

      # Retrieve the charge from Frisbii API
      def api_record
        @api_record ||= Pay::Frisbii.api_request(:get, "/charge/#{processor_id}")
      rescue => e
        raise Pay::Frisbii::Error, "Unable to fetch charge: #{e.message}"
      end

      # Refund a charge
      def refund!(amount = nil, **options)
        # If no amount specified, refund the full amount
        amount ||= self.amount - amount_refunded

        params = {
          amount: amount
        }

        # Add refund reason if provided
        params[:text] = options[:reason] if options[:reason]

        # Create the refund
        refund_response = Pay::Frisbii.api_request(:post, "/charge/#{processor_id}/refund", params)

        # Update the charge with refund information
        sync!

        refund_response
      rescue => e
        raise Pay::Frisbii::Error, "Unable to refund charge: #{e.message}"
      end

      # Capture an authorized charge
      def capture(amount = nil)
        params = amount.present? ? {amount: amount} : {}

        # Settle the authorized charge
        capture_response = Pay::Frisbii.api_request(:post, "/charge/#{processor_id}/settle", params)

        # Update local record
        sync!

        capture_response
      rescue => e
        raise Pay::Frisbii::Error, "Unable to capture charge: #{e.message}"
      end

      # Cancel an authorized charge
      def cancel
        # Cancel the authorized charge
        cancel_response = Pay::Frisbii.api_request(:post, "/charge/#{processor_id}/cancel", {})

        # Update local record
        sync!

        cancel_response
      rescue => e
        raise Pay::Frisbii::Error, "Unable to cancel charge: #{e.message}"
      end

      private

      def frisbii_status_to_pay_status(frisbii_state)
        # Map Frisbii charge states to Pay statuses
        case frisbii_state
        when "created", "pending"
          "pending"
        when "authorized"
          "requires_capture"
        when "settled"
          "succeeded"
        when "failed"
          "failed"
        when "cancelled", "canceled"
          "canceled"
        else
          frisbii_state
        end
      end

      def extract_payment_method_type(object)
        return nil unless object["payment_method_info"]

        case object["payment_method_info"]["type"]
        when "card", "card_token"
          "card"
        when "mobilepay", "vipps", "swish"
          "mobile_payment"
        when "paypal"
          "paypal"
        else
          object["payment_method_info"]["type"]
        end
      end

      def extract_brand(object)
        return nil unless object["payment_method_info"]
        object["payment_method_info"]["card_type"] || object["payment_method_info"]["brand"]
      end

      def extract_last4(object)
        return nil unless object["payment_method_info"]

        # Extract last 4 digits if it's a card
        if object["payment_method_info"]["masked_card"]
          object["payment_method_info"]["masked_card"].last(4)
        elsif object["payment_method_info"]["last4"]
          object["payment_method_info"]["last4"]
        end
      end

      def extract_exp_month(object)
        return nil unless object["payment_method_info"]
        object["payment_method_info"]["exp_month"]
      end

      def extract_exp_year(object)
        return nil unless object["payment_method_info"]
        object["payment_method_info"]["exp_year"]
      end
    end
  end
end

# Ensure ActiveSupport knows about this class for loading hooks
ActiveSupport.run_load_hooks :pay_frisbii_charge, Pay::Frisbii::Charge