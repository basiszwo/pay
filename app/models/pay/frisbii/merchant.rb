module Pay
  module Frisbii
    class Merchant < Pay::Merchant
      # Create a connected account in Frisbii (for marketplace/platform functionality)
      def create_account(**options)
        params = {
          type: options[:type] || "standard",
          email: owner.email
        }

        # Add business information if available
        if options[:business_name]
          params[:business_name] = options[:business_name]
        end

        if options[:country]
          params[:country] = options[:country]
        end

        # Create the account
        account = Pay::Frisbii.api_request(:post, "/account", params)

        # Update local record with processor_id
        update!(processor_id: account["id"])

        account
      rescue => e
        raise Pay::Frisbii::Error, "Unable to create merchant account: #{e.message}"
      end

      # Retrieve the merchant account from Frisbii
      def account
        @account ||= Pay::Frisbii.api_request(:get, "/account/#{processor_id}")
      rescue => e
        raise Pay::Frisbii::Error, "Unable to fetch merchant account: #{e.message}"
      end

      # Create an account onboarding link
      def account_link(refresh_url:, return_url:, type: "account_onboarding", **options)
        params = {
          account: processor_id,
          refresh_url: refresh_url,
          return_url: return_url,
          type: type
        }

        params.merge!(options)

        Pay::Frisbii.api_request(:post, "/account_links", params)
      rescue => e
        raise Pay::Frisbii::Error, "Unable to create account link: #{e.message}"
      end

      # Create a login link for the merchant to access their dashboard
      def login_link(redirect_url: nil)
        params = {
          account: processor_id
        }

        params[:redirect_url] = redirect_url if redirect_url

        Pay::Frisbii.api_request(:post, "/account/#{processor_id}/login_link", params)
      rescue => e
        raise Pay::Frisbii::Error, "Unable to create login link: #{e.message}"
      end

      # Transfer funds to the connected account
      def transfer(amount:, currency: "USD", **options)
        params = {
          amount: amount,
          currency: currency,
          destination: processor_id
        }

        params.merge!(options)

        Pay::Frisbii.api_request(:post, "/transfers", params)
      rescue => e
        raise Pay::Frisbii::Error, "Unable to create transfer: #{e.message}"
      end

      # Update the merchant account
      def update_account(**attributes)
        Pay::Frisbii.api_request(:put, "/account/#{processor_id}", attributes)
        @account = nil # Clear cached account
      rescue => e
        raise Pay::Frisbii::Error, "Unable to update merchant account: #{e.message}"
      end
    end
  end
end

# Ensure ActiveSupport knows about this class for loading hooks
ActiveSupport.run_load_hooks :pay_frisbii_merchant, Pay::Frisbii::Merchant
