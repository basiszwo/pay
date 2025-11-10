module Pay
  module Frisbii
    module Webhooks
      class PaymentMethodCreated
        def call(event)
          # TODO: Implement webhook handler for payment_method_created
          Rails.logger.info "[Pay] Processing Frisbii payment_method_created webhook"

          # Extract relevant data from event
          # Sync with local database as needed
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii payment_method_created webhook: #{e.message}"
        end
      end
    end
  end
end
