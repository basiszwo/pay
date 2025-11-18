module Pay
  module Frisbii
    module Webhooks
      class SubscriptionCreated
        def call(event)
          # Extract subscription from event
          subscription = event.dig("subscription")
          return unless subscription

          # Sync the subscription from Frisbii
          Pay::Frisbii::Subscription.sync(subscription["handle"], object: subscription)
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii subscription_created webhook: #{e.message}"
        end
      end
    end
  end
end
