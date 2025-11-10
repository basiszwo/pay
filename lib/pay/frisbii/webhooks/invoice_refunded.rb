module Pay
  module Frisbii
    module Webhooks
      class InvoiceRefunded
        def call(event)
          # TODO: Implement webhook handler for invoice_refunded
          Rails.logger.info "[Pay] Processing Frisbii invoice_refunded webhook"

          # Extract relevant data from event
          # Sync with local database as needed
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii invoice_refunded webhook: #{e.message}"
        end
      end
    end
  end
end
