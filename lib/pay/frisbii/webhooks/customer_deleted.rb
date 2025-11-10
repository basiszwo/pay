module Pay
  module Frisbii
    module Webhooks
      class CustomerDeleted
        def call(event)
          customer = event.dig("customer")
          return unless customer

          pay_customer = Pay::Customer.find_by(processor: :frisbii, processor_id: customer["handle"])

          # Skip if customer not found
          return unless pay_customer

          # Mark all active subscriptions as canceled
          pay_customer.subscriptions.active.update_all(ends_at: Time.current, status: "canceled")

          # Remove all payment methods
          pay_customer.payment_methods.destroy_all

          # Mark customer as deleted
          pay_customer.update!(default: false, deleted_at: Time.current)
        rescue => e
          Rails.logger.error "[Pay] Error processing Frisbii customer_deleted webhook: #{e.message}"
        end
      end
    end
  end
end