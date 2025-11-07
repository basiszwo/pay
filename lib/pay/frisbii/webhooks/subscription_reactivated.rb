module Pay
  module Frisbii
    module Webhooks
      class UsubscriptionUreactivated
        def call(event)
          # TODO: Implement webhook handler for subscription_reactivated
          Rails.logger.info "[Pay] Processing Frisbii subscription_reactivated webhook"
          
          # Extract relevant data from event
          # Sync with local database as needed
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii subscription_reactivated webhook: #{e.message}"
        end
      end
    end
  end
end
