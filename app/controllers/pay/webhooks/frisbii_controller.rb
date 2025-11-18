module Pay
  module Webhooks
    class FrisbiiController < Pay::ApplicationController
      skip_before_action :verify_authenticity_token

      def create
        # Get the raw request body for signature verification
        payload = request.body.read

        # Parse the JSON payload
        event = JSON.parse(payload)

        # Verify the webhook signature
        verify_signature(event, payload)

        # Queue the webhook for processing
        queue_webhook(event)

        head :ok
      rescue JSON::ParserError => e
        Rails.logger.error "[Pay] Invalid JSON payload: #{e.message}"
        head :bad_request
      rescue Pay::Frisbii::Error => e
        Rails.logger.error "[Pay] Frisbii webhook verification failed: #{e.message}"
        head :bad_request
      rescue => e
        Rails.logger.error "[Pay] Frisbii webhook error: #{e.class} - #{e.message}"
        head :internal_server_error
      end

      private

      def verify_signature(event, payload)
        # Extract signature from the event
        signature = event["signature"]
        timestamp = event["timestamp"]
        event_id = event["id"]

        # Get the webhook secret from configuration
        secret = Pay::Frisbii.signing_secret

        if secret.blank?
          Rails.logger.warn "[Pay] Frisbii webhook secret is not configured. Skipping signature verification."
          return
        end

        # Calculate expected signature
        # Frisbii uses: hexencode(hmac_sha_256(webhook_secret, timestamp + id))
        expected_signature = calculate_signature(secret, timestamp, event_id)

        # Compare signatures
        unless secure_compare(signature, expected_signature)
          raise Pay::Frisbii::Error, "Invalid webhook signature"
        end
      end

      def calculate_signature(secret, timestamp, event_id)
        # Concatenate timestamp and id
        message = "#{timestamp}#{event_id}"

        # Calculate HMAC-SHA256
        OpenSSL::HMAC.hexdigest("SHA256", secret, message)
      end

      def secure_compare(a, b)
        return false if a.nil? || b.nil?
        return false unless a.bytesize == b.bytesize

        # Constant time comparison to prevent timing attacks
        l = a.unpack("C*")
        res = 0
        b.each_byte.with_index { |byte, index| res |= byte ^ l[index] }
        res == 0
      end

      def queue_webhook(event)
        # Store the webhook in the database
        webhook = Pay::Webhook.create!(
          processor: :frisbii,
          event_type: event["event_type"],
          event: event
        )

        # Queue for processing
        Pay::Webhooks::ProcessJob.perform_later(webhook)
      end
    end
  end
end
