module Pay
  module Frisbii
    module Webhooks
      class SubscriptionReactivated
        def call(event)
          # Extract subscription from event
          subscription = event.dig("subscription")
          return unless subscription

          # Sync the subscription from Frisbii (resumed from hold/pause)
          pay_subscription = Pay::Frisbii::Subscription.sync(subscription["handle"], object: subscription)

          # Log the reactivation
          Rails.logger.info "[Pay] Frisbii subscription #{subscription["handle"]} has been reactivated from hold"
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii subscription_reactivated webhook: #{e.message}"
        end
      end
    end
  end
end