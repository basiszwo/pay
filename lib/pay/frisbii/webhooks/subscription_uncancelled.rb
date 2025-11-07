module Pay
  module Frisbii
    module Webhooks
      class UsubscriptionUuncancelled
        def call(event)
          # TODO: Implement webhook handler for subscription_uncancelled
          Rails.logger.info "[Pay] Processing Frisbii subscription_uncancelled webhook"
          
          # Extract relevant data from event
          # Sync with local database as needed
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii subscription_uncancelled webhook: #{e.message}"
        end
      end
    end
  end
end
