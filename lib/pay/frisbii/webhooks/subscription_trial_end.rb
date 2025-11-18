module Pay
  module Frisbii
    module Webhooks
      class SubscriptionTrialEnd
        def call(event)
          # Extract subscription from event
          subscription = event.dig("subscription")
          return unless subscription

          # Find and sync the subscription
          pay_subscription = Pay::Subscription.find_by(processor: :frisbii, processor_id: subscription["handle"])
          return unless pay_subscription

          pay_subscription.sync!(object: subscription)

          # Send trial ended email if configured
          pay_user_mailer = Pay.mailer.with(pay_customer: pay_subscription.customer, pay_subscription: pay_subscription)

          if Pay.send_email?(:subscription_trial_will_end, pay_subscription) && pay_subscription.on_trial?
            # Trial is ending soon
            pay_user_mailer.subscription_trial_will_end.deliver_later
          elsif Pay.send_email?(:subscription_trial_ended, pay_subscription) && pay_subscription.trial_ended?
            # Trial has ended
            pay_user_mailer.subscription_trial_ended.deliver_later
          end
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii subscription_trial_end webhook: #{e.message}"
        end
      end
    end
  end
end