module Pay
  module Frisbii
    module Webhooks
      class InvoiceRefunded
        def call(event)
          # Extract the invoice/charge from the event
          invoice = event.dig("invoice")
          return unless invoice

          # Sync the charge with updated refund information
          pay_charge = Pay::Frisbii::Charge.sync(invoice["id"], object: invoice)

          # Send refund email if enabled
          if pay_charge && Pay.send_email?(:refund, pay_charge)
            Pay.mailer.with(pay_customer: pay_charge.customer, pay_charge: pay_charge).refund.deliver_later
          end
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii invoice_refunded webhook: #{e.message}"
        end
      end
    end
  end
end