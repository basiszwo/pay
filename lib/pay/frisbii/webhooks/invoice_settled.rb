module Pay
  module Frisbii
    module Webhooks
      class InvoiceSettled
        def call(event)
          # Extract the invoice/charge ID from the event
          invoice = event.dig("invoice")
          return unless invoice

          # Sync the charge from Frisbii
          pay_charge = Pay::Frisbii::Charge.sync(invoice["id"], object: invoice)

          # Send receipt email if enabled
          if pay_charge && Pay.send_email?(:receipt, pay_charge)
            Pay.mailer.with(pay_customer: pay_charge.customer, pay_charge: pay_charge).receipt.deliver_later
          end
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii invoice_settled webhook: #{e.message}"
        end
      end
    end
  end
end
