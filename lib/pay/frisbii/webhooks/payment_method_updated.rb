module Pay
  module Frisbii
    module Webhooks
      class PaymentMethodUpdated
        def call(event)
          # Extract payment method from event
          payment_method = event.dig("payment_method")
          return unless payment_method

          if payment_method["customer"]
            # Sync the updated payment method
            Pay::Frisbii::PaymentMethod.sync(payment_method["id"], object: payment_method)
          else
            # If customer was removed, delete the payment method if it exists
            Pay::PaymentMethod.find_by(processor: :frisbii, processor_id: payment_method["id"])&.destroy
          end
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii payment_method_updated webhook: #{e.message}"
        end
      end
    end
  end
end