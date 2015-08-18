module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PagseguroGateway < Gateway
      self.test_url = 'https://ws.sandbox.pagseguro.uol.com.br/v2/checkout'
      self.live_url = 'https://ws.pagseguro.uol.com.br/v2/checkout'

      self.supported_countries = ['BR']
      self.default_currency = 'BRL'
      self.supported_cardtypes = [:pagseguro]

      self.homepage_url = 'http://pagseguro.com.br/'
      self.display_name = 'Pagseguro'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :pagseguroemail, :token)
        super
      end

      def purchase(options={})
        post = {}
        add_merchant_data(post)
        add_invoice(post, options)
        #add_payment(post, payment)
        add_address(post, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_customer_data(post, options)
        post[:senderName] = options[:name]
        post[:senderEmail] = options[:email]
        post[:senderAreaCode] = options[:area_code] unless options[:area_code].blank?
        post[:senderPhone] = options[:phone] unless options[:phone].blank?
      end

      def add_address(post, options)
        address = options.fetch(:billing_address, {})
        post[:shippingType] = address[:shipping_type]
        post[:shippingCost] = address[:shipping_cost]
        post[:shippingAddressStreet] = address[:street]
        post[:shippingAddressNumber] = address[:number]
        post[:shippingAddressComplement] = address[:complement] unless address[:complement].blank?
        post[:shippingAddressDistrict] = address[:district]
        post[:shippingAddressPostalCode] = address[:zip]
        post[:shippingAddressCity] = address[:city]
        post[:shippingAddressState] = address[:state]
        post[:shippingAddressCountry] = address[:country]
      end

      def add_invoice(post, options)
        post[:reference] = options[:order_id]
        post[:currency] = self.default_currency
        #add products
        key = 1
        options[:products].each do |product|
          post["itemId#{key}"] = product[:id]
          post["itemDescription#{key}"] = product[:description]
          post["itemAmount#{key}"] = amount(product[:amount])
          post["itemQuantity#{key}"] = product[:quantity]
          post["itemWeight#{key}"] = product[:weight]
          key = key+1
        end

        post[:extraAmount] = amount(options[:extra_amout]) unless options[:extra_amout].blank?
      end

      def add_payment(post, payment)
      end

      def add_merchant_data(post)
        post[:email] = options.fetch(:pagseguroemail)
        post[:token] = options.fetch(:token)
      end

      def parse(body)
        reply = {}
        xml = REXML::Document.new(body)
        if root = REXML::XPath.first(xml, "//checkout")
          reply[:success] = true
          reply[:code] = REXML::XPath.first(root, "//code").text
          reply[:date] = REXML::XPath.first(root, "//date").text
          reply[:message] = "Pay with Pagseguro: https://pagseguro.uol.com.br/v2/checkout/payment.html?code="+reply[:code]
        elsif REXML::XPath.first(xml, "//errors")
          reply[:success] = false
          errors = REXML::XPath.match(xml, "//errors" )
          reply[:message] = ""
          reply[:errors] = []
          errors.each do |error|
            code  = REXML::XPath.first(error, "//code").text
            message = REXML::XPath.first(error, "//message").text
            reply[:errors].push({:code => code, :message => message}) 
            reply[:message] += "code: "+ code + " - " + message
            reply[:message] += "\n"
          end
        end

        return reply
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        headers = {"Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8"}
        response = parse(ssl_post(url, post_data(parameters), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        response[:success]
      end

      def message_from(response)
        response[:message]
      end

      def authorization_from(response)
        response[:code]
      end

      def post_data(parameters = {})
        parameters.collect { |key, value| "#{key}=#{ CGI.escape(value.to_s)}" }.join("&")
      end

      def error_code_from(response)
        unless success_from(response)
          response[:errors]
        end
      end
    end
  end
end
