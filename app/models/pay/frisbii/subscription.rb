module Pay
  module Frisbii
    class Subscription < Pay::Subscription
      # Syncs a subscription from the Frisbii API
      def self.sync(subscription_id, object: nil, name: nil, try: 0, retries: 1)
        object ||= Pay::Frisbii.api_request(:get, "/subscription/#{subscription_id}")

        # Find customer by processor_id
        pay_customer = Pay::Customer.find_by(processor: :frisbii, processor_id: object["customer"])
        return unless pay_customer

        # Find or initialize the subscription
        pay_subscription = pay_customer.subscriptions.find_or_initialize_by(processor_id: object["handle"])

        # Set the subscription name from metadata or use default
        if name.present?
          pay_subscription.name = name
        elsif object["metadata"] && object["metadata"]["pay_name"]
          pay_subscription.name = object["metadata"]["pay_name"]
        else
          pay_subscription.name ||= Pay.default_product_name
        end

        pay_subscription.sync!(object: object)
        pay_subscription
      rescue => e
        if try < retries
          sleep 0.5
          try += 1
          retry
        else
          raise Pay::Frisbii::Error, "Unable to sync subscription #{subscription_id}: #{e.message}"
        end
      end

      # Sync this subscription with latest data from Frisbii
      def sync!(object: nil)
        object ||= api_record

        # Extract trial information
        trial_end = Time.parse(object["trial_end"]) rescue nil
        trial_start = Time.parse(object["trial_start"]) rescue nil

        # Extract billing cycle information
        current_period_start = Time.parse(object["current_period_start"]) rescue nil
        current_period_end = Time.parse(object["current_period_end"]) rescue nil
        next_period_start = Time.parse(object["next_period_start"]) rescue nil

        # Map Frisbii subscription states to Pay statuses
        status = frisbii_state_to_pay_status(object["state"])

        # Update the subscription
        update!(
          processor_id: object["handle"],
          processor_plan: object["plan"],
          status: status,
          quantity: object["quantity"] || 1,
          trial_ends_at: trial_end,
          current_period_start: current_period_start,
          current_period_end: current_period_end,
          ends_at: object["expires"] ? Time.parse(object["expires"]) : nil,
          pause_starts_at: object["on_hold_from"] ? Time.parse(object["on_hold_from"]) : nil,
          pause_resumes_at: object["on_hold_to"] ? Time.parse(object["on_hold_to"]) : nil,
          created_at: Time.parse(object["created"]) rescue Time.current,
          metadata: object["metadata"],
          data: object,
          application_fee_percent: object["application_fee_percent"],
          payment_method_id: sync_payment_method_id(object)
        )

        # Sync the payment method if attached to subscription
        if object["payment_method"] && payment_method_id.blank?
          sync_payment_method(object["payment_method"])
        end
      end

      # Retrieve the subscription from Frisbii API
      def api_record
        @api_record ||= Pay::Frisbii.api_request(:get, "/subscription/#{processor_id}")
      rescue => e
        raise Pay::Frisbii::Error, "Unable to fetch subscription: #{e.message}"
      end

      # Cancel the subscription
      def cancel(**options)
        return if canceled?

        params = {}

        # Set cancellation to happen at period end by default
        if options[:now] || options[:immediately]
          # Cancel immediately
          response = Pay::Frisbii.api_request(:post, "/subscription/#{processor_id}/expire", params)
        else
          # Cancel at period end
          response = Pay::Frisbii.api_request(:post, "/subscription/#{processor_id}/cancel", params)
        end

        sync!
        response
      rescue => e
        raise Pay::Frisbii::Error, "Unable to cancel subscription: #{e.message}"
      end

      # Cancel immediately
      def cancel_now!(**options)
        cancel(now: true, **options)
      end

      # Resume a canceled subscription
      def resume
        unless on_grace_period?
          raise StandardError, "You can only resume subscriptions within their grace period."
        end

        response = Pay::Frisbii.api_request(:post, "/subscription/#{processor_id}/uncancel", {})
        sync!
        response
      rescue => e
        raise Pay::Frisbii::Error, "Unable to resume subscription: #{e.message}"
      end

      # Pause the subscription
      def pause(until_date: nil)
        params = {}
        params[:to] = until_date.iso8601 if until_date

        response = Pay::Frisbii.api_request(:post, "/subscription/#{processor_id}/on_hold", params)
        sync!
        response
      rescue => e
        raise Pay::Frisbii::Error, "Unable to pause subscription: #{e.message}"
      end

      # Unpause the subscription (Frisbii calls this reactivate)
      def unpause
        response = Pay::Frisbii.api_request(:post, "/subscription/#{processor_id}/reactivate", {})
        sync!
        response
      rescue => e
        raise Pay::Frisbii::Error, "Unable to unpause subscription: #{e.message}"
      end

      # Swap the subscription to a different plan
      def swap(plan, **options)
        params = {
          plan: plan,
          timing: options[:timing] || "immediate" # or "renewal" for next period
        }

        # Handle proration if specified
        params[:prorate] = options[:prorate] if options.key?(:prorate)

        response = Pay::Frisbii.api_request(:put, "/subscription/#{processor_id}/change", params)

        # Update local plan reference
        update!(processor_plan: plan)
        sync!

        response
      rescue => e
        raise Pay::Frisbii::Error, "Unable to swap subscription plan: #{e.message}"
      end

      # Change the subscription quantity
      def change_quantity(quantity, **options)
        params = {
          quantity: quantity,
          timing: options[:timing] || "immediate"
        }

        response = Pay::Frisbii.api_request(:put, "/subscription/#{processor_id}/change", params)

        # Update local quantity
        update!(quantity: quantity)
        sync!

        response
      rescue => e
        raise Pay::Frisbii::Error, "Unable to change subscription quantity: #{e.message}"
      end

      # Check if subscription is on trial
      def on_trial?
        trial_ends_at? && Time.current < trial_ends_at
      end

      # Check if subscription is canceled
      def canceled?
        ["cancelled", "expired"].include?(status)
      end

      # Check if subscription is past_due
      def past_due?
        status == "past_due"
      end

      # Check if subscription is paused
      def paused?
        status == "on_hold"
      end

      # Check if subscription will renew
      def will_renew?
        ["active", "trialing", "past_due"].include?(status) && !canceled?
      end

      # Check if on grace period (canceled but not yet expired)
      def on_grace_period?
        (status == "cancelled" || ends_at?) && Time.current < ends_at
      end

      # Retry a failed subscription payment
      def retry_failed_payment
        # Trigger a payment retry in Frisbii
        response = Pay::Frisbii.api_request(:post, "/subscription/#{processor_id}/charge", {})
        sync!
        response
      rescue => e
        raise Pay::Frisbii::Error, "Unable to retry payment: #{e.message}"
      end

      # Get upcoming invoice
      def upcoming_invoice(**options)
        Pay::Frisbii.api_request(:get, "/subscription/#{processor_id}/upcoming_invoice")
      rescue => e
        raise Pay::Frisbii::Error, "Unable to fetch upcoming invoice: #{e.message}"
      end

      # Update the payment method
      def update_payment_method(payment_method_id)
        params = {
          payment_method: payment_method_id
        }

        response = Pay::Frisbii.api_request(:post, "/subscription/#{processor_id}/set_payment_method", params)
        sync!
        response
      rescue => e
        raise Pay::Frisbii::Error, "Unable to update payment method: #{e.message}"
      end

      private

      def frisbii_state_to_pay_status(frisbii_state)
        # Map Frisbii subscription states to Pay statuses
        case frisbii_state
        when "active"
          "active"
        when "canceled", "cancelled"
          "canceled"
        when "expired"
          "canceled"
        when "on_hold"
          "paused"
        when "pending"
          "incomplete"
        when "dunning"
          "past_due"
        when "trial", "trialing"
          "trialing"
        else
          frisbii_state
        end
      end

      def sync_payment_method_id(object)
        return unless object["payment_method"]

        # Find existing payment method by processor_id
        payment_method = customer.payment_methods.find_by(processor_id: object["payment_method"])
        payment_method&.id
      end

      def sync_payment_method(payment_method_id)
        # Create or sync the payment method
        payment_method = customer.payment_methods.find_or_initialize_by(processor_id: payment_method_id)
        payment_method_data = Pay::Frisbii.api_request(:get, "/payment_method/#{payment_method_id}")
        payment_method.sync!(object: payment_method_data)

        # Associate with this subscription
        update!(payment_method: payment_method)
      end
    end
  end
end

# Ensure ActiveSupport knows about this class for loading hooks
ActiveSupport.run_load_hooks :pay_frisbii_subscription, Pay::Frisbii::Subscription
