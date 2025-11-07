module Pay
  module Frisbii
    class Error < Pay::Error
      attr_reader :response

      def initialize(message, response = nil)
        @response = response

        if response
          begin
            parsed = JSON.parse(response.body)
            message = "#{message}: #{parsed['error_message'] || parsed['error'] || parsed['message']}"
          rescue JSON::ParserError
            # Use original message if we can't parse the response
          end
        end

        super(message)
      end

      def code
        return nil unless response

        begin
          parsed = JSON.parse(response.body)
          parsed['error_code'] || parsed['code']
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end