module Pay
  module Frisbii
    class Customer < Pay::Customer
      include Pay::Routing

      has_many :charges, dependent: :destroy, class_name: "Pay::Frisbii::Charge", foreign_key: :customer_id, inverse_of: :customer
      has_many :subscriptions, dependent: :destroy, class_name: "Pay::Frisbii::Subscription", foreign_key: :customer_id, inverse_of: :customer
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::Frisbii::PaymentMethod", foreign_key: :customer_id, inverse_of: :customer

      # Retrieves a Frisbii::Customer object
      #
      # Frisbii expects all attributes to be passed for updates,
      # so we retrieve the current customer, update the attributes,
      # and then save the customer
      def api_record
        return @api_record if @api_record

        @api_record = if processor_id?
          Pay::Frisbii.api_request(:get, "/customer/#{processor_id}")
        else
          create_frisbii_customer
        end
      rescue => e
        raise Pay::Frisbii::Error, "Unable to fetch Frisbii customer: #{e.message}"
      end

      # Synchronizes customer details from Frisbii to local database
      def sync!(object: nil)
        object ||= api_record

        if object.nil?
          self.destroy
        else
          update!(
            email: object["email"],
            processor_id: object["handle"],
            data: object
          )
        end
      end

      def charge(amount, options = {})
        # Charges in Frisbii are created through their charge endpoint
        # Amount is expected in minor units (e.g., cents)

        customer = api_record
        payment_method = options[:payment_method] || default_payment_method&.processor_id

        params = {
          handle: options[:handle] || "charge_#{SecureRandom.hex(8)}",
          amount: amount,
          customer: processor_id,
          currency: options[:currency] || "USD"
        }

        # Add payment method if provided
        params[:payment_method] = payment_method if payment_method

        # Add metadata/order data if provided
        params[:ordertext] = options[:description] if options[:description]
        params[:metadata] = options[:metadata] if options[:metadata]

        # Handle idempotency
        params[:key] = options[:idempotency_key] if options[:idempotency_key]

        # Create the charge
        charge_response = Pay::Frisbii.api_request(:post, "/charge", params)

        # Find or create Pay::Charge record
        pay_charge = charges.find_or_initialize_by(processor_id: charge_response["id"])
        pay_charge.sync!(object: charge_response)
        pay_charge
      rescue => e
        raise Pay::Frisbii::Error, "Unable to create charge: #{e.message}"
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # Create a subscription in Frisbii
        params = {
          handle: options[:handle] || "sub_#{SecureRandom.hex(8)}",
          customer: processor_id,
          plan: plan
        }

        # Trial handling
        if options[:trial_period_days]
          params[:trial_period_days] = options[:trial_period_days]
        elsif options[:trial_end]
          params[:trial_end] = options[:trial_end].iso8601
        end

        # Payment method
        payment_method = options[:payment_method] || default_payment_method&.processor_id
        params[:payment_method] = payment_method if payment_method

        # Metadata
        params[:metadata] = options[:metadata] if options[:metadata]

        # Add subscription metadata with Pay references
        params[:metadata] ||= {}
        params[:metadata][:pay_name] = name

        # Create subscription
        subscription_response = Pay::Frisbii.api_request(:post, "/subscription", params)

        # Find or create Pay::Subscription record
        pay_subscription = subscriptions.find_or_initialize_by(processor_id: subscription_response["handle"])
        pay_subscription.name = name
        pay_subscription.processor_plan = plan
        pay_subscription.sync!(object: subscription_response)
        pay_subscription
      rescue => e
        raise Pay::Frisbii::Error, "Unable to create subscription: #{e.message}"
      end

      def add_payment_method(token = nil, default: true, **options)
        # Add a payment method for the customer in Frisbii
        # Token can be a card token from Frisbii.js or a payment method reference

        return unless token.present?

        params = {
          customer: processor_id,
          token: token
        }

        # Add any additional parameters
        params.merge!(options)

        # Create the payment method in Frisbii
        payment_method_response = Pay::Frisbii.api_request(:post, "/customer/#{processor_id}/payment_method", params)

        # Create local PaymentMethod record
        pay_payment_method = payment_methods.find_or_initialize_by(processor_id: payment_method_response["id"])
        pay_payment_method.sync!(object: payment_method_response)

        # Set as default if requested
        pay_payment_method.make_default! if default

        pay_payment_method
      rescue => e
        raise Pay::Frisbii::Error, "Unable to add payment method: #{e.message}"
      end

      def update_api_record(**attributes)
        # Update customer in Frisbii
        # Frisbii requires all attributes to be sent on update
        customer = api_record.merge(attributes.stringify_keys)

        # Remove read-only fields
        customer.delete("created")
        customer.delete("deleted")

        updated_customer = Pay::Frisbii.api_request(:put, "/customer/#{processor_id}", customer)
        @api_record = updated_customer
      rescue => e
        raise Pay::Frisbii::Error, "Unable to update customer: #{e.message}"
      end

      # Creates a new customer in Frisbii
      def create_frisbii_customer
        params = {
          handle: "cust_#{SecureRandom.hex(8)}",
          email: email || owner.email,
          first_name: owner.try(:first_name) || owner.try(:name)&.split&.first,
          last_name: owner.try(:last_name) || owner.try(:name)&.split&.last
        }

        # Add additional details if available
        params[:phone] = owner.try(:phone) if owner.respond_to?(:phone)
        params[:address] = owner.try(:address) if owner.respond_to?(:address)
        params[:city] = owner.try(:city) if owner.respond_to?(:city)
        params[:postal_code] = owner.try(:postal_code) || owner.try(:zip) if owner.respond_to?(:postal_code) || owner.respond_to?(:zip)
        params[:country] = owner.try(:country) || "US" if owner.respond_to?(:country)

        customer = Pay::Frisbii.api_request(:post, "/customer", params)
        update!(processor_id: customer["handle"])
        customer
      end

      # Sync all subscriptions for the customer
      def sync_subscriptions(**options)
        subscriptions_response = Pay::Frisbii.api_request(:get, "/subscription?customer=#{processor_id}")

        subscriptions_response.each do |subscription_data|
          subscription = subscriptions.find_or_initialize_by(processor_id: subscription_data["handle"])
          subscription.sync!(object: subscription_data)
        end

        subscriptions.reload
      rescue => e
        raise Pay::Frisbii::Error, "Unable to sync subscriptions: #{e.message}"
      end

      # Retrieves a payment intent for SCA/3DS if needed
      def create_payment_intent(amount, options = {})
        params = {
          amount: amount,
          currency: options[:currency] || "USD",
          customer: processor_id
        }

        params.merge!(options)
        Pay::Frisbii.api_request(:post, "/charge", params.merge(intent_only: true))
      rescue => e
        raise Pay::Frisbii::Error, "Unable to create payment intent: #{e.message}"
      end

      # Frisbii-specific: generates a hosted checkout session
      def checkout(mode: "payment", **options)
        params = {
          customer: processor_id,
          mode: mode
        }

        # Add line items, success/cancel URLs, etc.
        params[:success_url] = options[:success_url] || root_url
        params[:cancel_url] = options[:cancel_url] || root_url
        params[:line_items] = options[:line_items] if options[:line_items]

        Pay::Frisbii.api_request(:post, "/checkout/session", params)
      rescue => e
        raise Pay::Frisbii::Error, "Unable to create checkout session: #{e.message}"
      end

      # Frisbii-specific: generates a customer portal session
      def billing_portal(**options)
        params = {
          customer: processor_id,
          return_url: options[:return_url] || root_url
        }

        Pay::Frisbii.api_request(:post, "/customer/#{processor_id}/portal_session", params)
      rescue => e
        raise Pay::Frisbii::Error, "Unable to create portal session: #{e.message}"
      end
    end
  end
end

# Ensure ActiveSupport knows about this class for loading hooks
ActiveSupport.run_load_hooks :pay_frisbii_customer, Pay::Frisbii::Customer
