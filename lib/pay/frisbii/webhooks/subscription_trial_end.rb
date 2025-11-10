module Pay
  module Frisbii
    module Webhooks
      class SubscriptionTrialEnd
        def call(event)
          # TODO: Implement webhook handler for subscription_trial_end
          Rails.logger.info "[Pay] Processing Frisbii subscription_trial_end webhook"

          # Extract relevant data from event
          # Sync with local database as needed
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii subscription_trial_end webhook: #{e.message}"
        end
      end
    end
  end
end
