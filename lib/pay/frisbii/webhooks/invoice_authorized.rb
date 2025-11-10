module Pay
  module Frisbii
    module Webhooks
      class InvoiceAuthorized
        def call(event)
          # Extract the invoice/charge from the event
          invoice = event.dig("invoice")
          return unless invoice

          # Sync the charge from Frisbii (authorized state)
          Pay::Frisbii::Charge.sync(invoice["id"], object: invoice)

          # No email needed for authorization - merchant will capture later
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii invoice_authorized webhook: #{e.message}"
        end
      end
    end
  end
end