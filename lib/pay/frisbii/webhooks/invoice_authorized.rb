module Pay
  module Frisbii
    module Webhooks
      class InvoiceAuthorized
        def call(event)
          # TODO: Implement webhook handler for invoice_authorized
          Rails.logger.info "[Pay] Processing Frisbii invoice_authorized webhook"

          # Extract relevant data from event
          # Sync with local database as needed
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii invoice_authorized webhook: #{e.message}"
        end
      end
    end
  end
end
