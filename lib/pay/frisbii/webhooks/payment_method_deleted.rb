module Pay
  module Frisbii
    module Webhooks
      class PaymentMethodDeleted
        def call(event)
          # Extract payment method from event
          payment_method = event.dig("payment_method")
          return unless payment_method

          # Find and delete the payment method from our database
          pay_payment_method = Pay::PaymentMethod.find_by(
            processor: :frisbii,
            processor_id: payment_method["id"]
          )

          pay_payment_method&.destroy
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii payment_method_deleted webhook: #{e.message}"
        end
      end
    end
  end
end