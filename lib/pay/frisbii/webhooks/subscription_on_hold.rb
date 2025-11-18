module Pay
  module Frisbii
    module Webhooks
      class SubscriptionOnHold
        def call(event)
          # Extract subscription from event
          subscription = event.dig("subscription")
          return unless subscription

          # Sync the subscription from Frisbii (paused state)
          pay_subscription = Pay::Frisbii::Subscription.sync(subscription["handle"], object: subscription)

          # Log the pause event
          Rails.logger.info "[Pay] Frisbii subscription #{subscription["handle"]} has been put on hold"
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii subscription_on_hold webhook: #{e.message}"
        end
      end
    end
  end
end