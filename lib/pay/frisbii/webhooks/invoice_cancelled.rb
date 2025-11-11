module Pay
  module Frisbii
    module Webhooks
      class InvoiceCancelled
        def call(event)
          # Extract the invoice/charge from the event
          invoice = event.dig("invoice")
          return unless invoice

          # Sync the charge from Frisbii (cancelled state)
          # This typically happens when an authorized charge is cancelled before capture
          Pay::Frisbii::Charge.sync(invoice["id"], object: invoice)

          # No email needed for cancellation - this is typically a backend operation
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii invoice_cancelled webhook: #{e.message}"
        end
      end
    end
  end
end