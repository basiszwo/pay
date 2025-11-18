module Pay
  module Frisbii
    module Webhooks
      class PaymentMethodCreated
        def call(event)
          # Extract payment method from event
          payment_method = event.dig("payment_method")
          return unless payment_method

          # Only sync if it has a customer attached
          if payment_method["customer"]
            Pay::Frisbii::PaymentMethod.sync(payment_method["id"], object: payment_method)
          end
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii payment_method_created webhook: #{e.message}"
        end
      end
    end
  end
end