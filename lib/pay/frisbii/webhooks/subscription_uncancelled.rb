module Pay
  module Frisbii
    module Webhooks
      class SubscriptionUncancelled
        def call(event)
          # Extract subscription from event
          subscription = event.dig("subscription")
          return unless subscription

          # Sync the subscription from Frisbii (reactivated from cancelled state)
          pay_subscription = Pay::Frisbii::Subscription.sync(subscription["handle"], object: subscription)

          # The subscription has been resumed/uncancelled
          Rails.logger.info "[Pay] Frisbii subscription #{subscription["handle"]} has been uncancelled"
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii subscription_uncancelled webhook: #{e.message}"
        end
      end
    end
  end
end