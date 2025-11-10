module Pay
  module Frisbii
    module Webhooks
      class SubscriptionRenewal
        def call(event)
          # Extract subscription from event
          subscription = event.dig("subscription")
          return unless subscription

          # Sync the subscription from Frisbii
          pay_subscription = Pay::Frisbii::Subscription.sync(subscription["handle"], object: subscription)

          # Send renewal notification if enabled
          if pay_subscription && Pay.send_email?(:subscription_renewing, pay_subscription)
            Pay.mailer.with(
              pay_customer: pay_subscription.customer,
              pay_subscription: pay_subscription
            ).subscription_renewing.deliver_later
          end
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii subscription_renewal webhook: #{e.message}"
        end
      end
    end
  end
end
