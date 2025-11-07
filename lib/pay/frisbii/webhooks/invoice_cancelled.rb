module Pay
  module Frisbii
    module Webhooks
      class UinvoiceUcancelled
        def call(event)
          # TODO: Implement webhook handler for invoice_cancelled
          Rails.logger.info "[Pay] Processing Frisbii invoice_cancelled webhook"
          
          # Extract relevant data from event
          # Sync with local database as needed
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii invoice_cancelled webhook: #{e.message}"
        end
      end
    end
  end
end
