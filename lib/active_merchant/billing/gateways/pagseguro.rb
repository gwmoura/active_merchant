module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class PagseguroGateway < Gateway
      self.test_url = 'https://ws.sandbox.pagseguro.uol.com.br'
      self.live_url = 'https://ws.pagseguro.uol.com.br'

      self.supported_countries = ['BR']
      self.default_currency = 'BRL'
      self.supported_cardtypes = [:pagseguro]

      self.homepage_url = 'http://pagseguro.com.br/'
      self.display_name = 'Pagseguro'

      STANDARD_TRANSACTION_STATUS_CODE = {
        1 => "Aguardando pagamento",
        2 => "Em análise  ",
        3 => "Paga",
        4 => "Disponível",
        5 => "Em disputa",
        6 => "Devolvida",
        7 => "Cancelada",
        8 => "Chargeback debitado",
        9 => "Em contestação",
      }
      
      STANDARD_PAYMENT_METHOD_TYPE = {
        1 => "Cartão de crédito",
        2 => "Boleto",
        3 => "Débito online (TEF)",
        4 => "Saldo PagSeguro",
        5 => "Oi Paggo",
        7 => "Depósito em conta",
      }

      def initialize(options={})
        requires!(options, :pagseguroemail, :token)
        super
      end

      def purchase(options={})
        post = {}
        add_merchant_data(post)
        add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_merchant_data(post)
        add_invoice(post, options)
        add_address(post, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(transaction_code)
        post = {}
        post[:transaction_code] = transaction_code 
        add_merchant_data(post)
        commit('capture', post)
      end

      def transactions_by_date(initial_date = Time.now - 3600, final_date = Time.now, page=1, max_results=50)
        initial_date = initial_date.strftime("%Y-%m-%dT%H:%M")
        final_date = final_date.strftime("%Y-%m-%dT%H:%M")
        post = {}
        post[:initialDate] = initial_date
        post[:finalDate] = final_date
        post[:page] = page
        post[:maxPageResults] = max_results
        post[:abandoned] = false
        add_merchant_data(post)
        commit('transactions_by_date', post)
      end

      def transactions_abandoned(initial_date = Time.now - 3600, final_date = Time.now, page=1, max_results=50)
        initial_date = initial_date.strftime("%Y-%m-%dT%H:%M")
        final_date = final_date.strftime("%Y-%m-%dT%H:%M")
        post = {}
        post[:initialDate] = initial_date
        post[:finalDate] = final_date
        post[:page] = page
        post[:maxPageResults] = max_results
        post[:abandoned] = true
        add_merchant_data(post)
        commit('transactions_by_date', post)
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
        post[:redirectURL] = options[:redirect_url] unless options[:redirect_url].blank?
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
          sandbox = (test? ? "sandbox." : "")
          reply[:message] = "Pay with Pagseguro: https://#{sandbox}pagseguro.uol.com.br/v2/checkout/payment.html?code="+reply[:code]
          reply[:hash_response] = Hash.from_xml(body)
        elsif REXML::XPath.first(xml, "//transactionSearchResult")
          reply[:success] = true
          hash_transactions = Hash.from_xml(body)
          reply[:result] = hash_transactions["transactionSearchResult"]
          result = hash_transactions["transactionSearchResult"]
          reply[:message] = "Found #{result['resultsInThisPage']} transaction on page #{result['currentPage']} of #{result['totalPages']}"
        elsif REXML::XPath.first(xml, "//transaction")
          reply[:success] = true
          hash_transaction = Hash.from_xml(body)
          transaction = hash_transaction['transaction']
          reply[:transaction] = transaction
          reply[:message] = "Transaction: #{transaction['code']} - Status: #{STANDARD_TRANSACTION_STATUS_CODE[transaction['status'].to_i]}"
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
        else
          reply[:success] = false
          reply[:message] = body
        end

        return reply
      end

      def treating_request(method,url,parameters,headers={})
        begin
          body = ssl_request(method, url, parameters,headers)
        rescue ActiveMerchant::ResponseError => r
          body = r.response.body
        end
        return body
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        if action == "sale"
          url = url+"/v2/checkout"
          response = parse(treating_request(:post, url, post_data(parameters)))
        elsif action == "capture"
          url = url + "/v3/transactions/"+parameters[:transaction_code]
          parameters.delete(:transaction_code)
          url = url+'?'+post_data(parameters)
          response = parse(treating_request(:get, url, nil))
        elsif action == "transactions_by_date"
          url = "#{url}/v2/transactions"
          if parameters.has_key? :abandoned && parameters[:abandoned]
            parameters.delete(:abandoned)
            url = "#{url}/abandoned"
          end
          url = "#{url}?#{post_data(parameters)}"
          response = parse(treating_request(:get, url, nil))
        end
        
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
