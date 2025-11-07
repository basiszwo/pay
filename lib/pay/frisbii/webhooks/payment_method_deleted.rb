module Pay
  module Frisbii
    module Webhooks
      class UpaymentUmethodUdeleted
        def call(event)
          # TODO: Implement webhook handler for payment_method_deleted
          Rails.logger.info "[Pay] Processing Frisbii payment_method_deleted webhook"
          
          # Extract relevant data from event
          # Sync with local database as needed
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii payment_method_deleted webhook: #{e.message}"
        end
      end
    end
  end
end
