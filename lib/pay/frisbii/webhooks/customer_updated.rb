module Pay
  module Frisbii
    module Webhooks
      class CustomerUpdated
        def call(event)
          customer = event.dig("customer")
          return unless customer

          pay_customer = Pay::Customer.find_by(processor: :frisbii, processor_id: customer["handle"])

          # Skip if customer not found
          return unless pay_customer

          # Update customer data
          pay_customer.update!(
            email: customer["email"],
            data: customer
          )

          # Sync default payment method if changed
          if customer["default_payment_method"]
            # Sync the new default payment method
            Pay::Frisbii::PaymentMethod.sync(customer["default_payment_method"])
          else
            # No default payment method set
            pay_customer.payment_methods.update_all(default: false)
          end
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii customer_updated webhook: #{e.message}"
        end
      end
    end
  end
end