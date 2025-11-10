module Pay
  module Frisbii
    module Webhooks
      class InvoiceFailed
        def call(event)
          # Extract the invoice/charge ID from the event
          invoice = event.dig("invoice")
          return unless invoice

          # Sync the charge from Frisbii
          pay_charge = Pay::Frisbii::Charge.sync(invoice["id"], object: invoice)

          # Check if this is related to a subscription
          subscription_id = invoice["subscription"]
          if subscription_id
            pay_subscription = Pay::Frisbii::Subscription.sync(subscription_id)

            # Send payment failed email if enabled
            if pay_subscription && Pay.send_email?(:payment_failed, pay_subscription)
              Pay.mailer.with(
                pay_customer: pay_subscription.customer,
                pay_subscription: pay_subscription,
                pay_charge: pay_charge
              ).payment_failed.deliver_later
            end
          end
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii invoice_failed webhook: #{e.message}"
        end
      end
    end
  end
end
