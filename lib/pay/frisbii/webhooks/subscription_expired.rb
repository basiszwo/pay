module Pay
  module Frisbii
    module Webhooks
      class SubscriptionExpired
        def call(event)
          # Extract subscription from event
          subscription = event.dig("subscription")
          return unless subscription

          # Sync the subscription from Frisbii (expired/ended state)
          pay_subscription = Pay::Frisbii::Subscription.sync(subscription["handle"], object: subscription)

          # The subscription has fully expired (past grace period)
          Rails.logger.info "[Pay] Frisbii subscription #{subscription["handle"]} has expired"
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii subscription_expired webhook: #{e.message}"
        end
      end
    end
  end
end