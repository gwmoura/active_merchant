require 'test_helper'

class PagseguroTest < Test::Unit::TestCase
  def setup
    @gateway = PagseguroGateway.new(fixtures(:pagseguro))

    @products = []
    @products[0] = {
      id: 1,
      description: "Service One",
      quantity: 1,
      amount: 10000,
      weight: 0
    }
    @products[1] = {
      id: 2,
      description: "Service Two",
      quantity: 1,
      amount: 10500,
      weight: 0
    }

    @address = {
      shipping_type: 3,
      street: "Rua Das Margaridas",
      number: 100,
      complement: "",
      district: "Boca do Rio",
      city: "Salvador",
      state: "BA",
      country: "BRA" 
    }

    @options = {
      order_id: '1',
      name: "George Moura",
      email: "c64944351509424390810@sandbox.pagseguro.com.br",
      area_code: "71",
      phone: "87886089",
      billing_address: @address,
      description: 'Store Purchase',
      products: @products,
      extra_amount: 100
    }
  end

  def test_successful_purchase
    #@gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@options)
    assert_success response

    #puts response.message
    assert_equal 32, response.authorization.length
    assert response.test?
  end

  def test_failed_purchase
    @options[:billing_address][:shipping_type] = ""

    response = @gateway.purchase(@options)
    assert_failure response
    assert_true response.message.include? "ShippingType is required."
  end

  # def test_successful_authorize
  # end

  # def test_failed_authorize
  # end

  def test_successful_capture
    transaction_code = '9B24469F-6582-48B5-BCFD-7D7DD415617F'
    response = @gateway.capture(transaction_code)
    #puts "response: #{response.message}"
    assert_success response
    assert_true response.message.include? "Transaction: #{transaction_code} - Status:"
  end

  def test_failed_capture
    transaction_code = '9D55E537-945A-4D05-A2F7-0DDB0A93420E'
    response = @gateway.capture(transaction_code)
    #puts "response: #{response.message}"
    assert_failure response
    assert_equal response.message, "Not Found"
  end

  def test_successful_transactions_by_date
    response = @gateway.transactions_by_date(Time.now-7.days, Time.now)
    assert_true response.message.include? "transaction on page"
    assert_success response
  end

  def test_failed_transactions_by_date
    response = @gateway.transactions_by_date(Time.now-7.days, Time.now, 0)
    assert_true response.message.include? "code: 13013 - page invalid value"
    assert_failure response
  end

  def test_seccessful_transactions_abandoned
    response = @gateway.transactions_abandoned(Time.now-7.days, Time.now)
    assert_true response.message.include? "transaction on page"
    assert_success response
  end

  def test_failed_transactions_abandoned
    response = @gateway.transactions_abandoned(Time.now-7.days, Time.now, 0)
    assert_true response.message.include? "code: 13013 - page invalid value"
    assert_failure response
  end

  # def test_successful_refund
  # end

  # def test_failed_refund
  # end

  # def test_successful_void
  # end

  # def test_failed_void
  # end

  # def test_successful_verify
  # end

  # def test_successful_verify_with_failed_void
  # end

  # def test_failed_verify
  # end

  # def test_scrub
  #   assert @gateway.supports_scrubbing?
  #   assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  # end

  # private

  # def pre_scrubbed
  #   %q(
  #     Run the remote tests for this gateway, and then put the contents of transcript.log here.
  #   )
  # end

  # def post_scrubbed
  #   %q(
  #     Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
  #     Things to scrub:
  #       - Credit card number
  #       - CVV
  #       - Sensitive authentication details
  #   )
  # end

  # def successful_purchase_response
  #   %(
  #     Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
  #     to "true" when running remote tests:

  #     $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
  #       test/remote/gateways/remote_pagseguro_test.rb \
  #       -n test_successful_purchase
  #   )
  # end

  def failed_purchase_response
    # %(
    #   Easy to capture by setting the DEBUG_ACTIVE_MERCHANT environment variable
    #   to "true" when running remote tests:

    #   $ DEBUG_ACTIVE_MERCHANT=true ruby -Itest \
    #     test/remote/gateways/remote_pagseguro_test.rb \
    #     -n test_failed_purchase
    # )
    '<?xml version="1.0" encoding="ISO-8859-1" standalone="yes"?><errors><error><code>11015</code><message>ShippingType is required.</message></error></errors>'
  end

  # def successful_authorize_response
  # end

  # def failed_authorize_response
  # end

  # def successful_capture_response
  # end

  # def failed_capture_response
  # end

  # def successful_refund_response
  # end

  # def failed_refund_response
  # end

  # def successful_void_response
  # end

  # def failed_void_response
  # end
end
