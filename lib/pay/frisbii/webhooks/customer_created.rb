module Pay
  module Frisbii
    module Webhooks
      class CustomerCreated
        def call(event)
          # Extract customer from event
          customer = event.dig("customer")
          return unless customer

          # Find and sync the customer
          pay_customer = Pay::Customer.find_by(processor: :frisbii, processor_id: customer["handle"])
          pay_customer&.sync!(object: customer)
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii customer_created webhook: #{e.message}"
        end
      end
    end
  end
end
