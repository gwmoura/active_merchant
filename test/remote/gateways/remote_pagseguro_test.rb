require 'test_helper'

class RemotePagseguroTest < Test::Unit::TestCase
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
      billing_address: @address,
      description: 'Store Purchase',
      products: @products,
      extra_amount: 100
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@options)
    assert_success response
    assert_true response.message.include? 'Pay with Pagseguro:'
    assert_true response.params["hash_response"]["checkout"].has_key?("code")
  end

  def test_successful_purchase_with_more_options
    @options[:order_id] = '2'
    @options[:area_code] = "71"
    @options[:phone] = "87886089"

    response = @gateway.purchase(@options)
    assert_success response
    assert_true response.message.include? 'Pay with Pagseguro:'
  end

  def test_failed_purchase
    @options[:billing_address][:shipping_type] = ""
    response = @gateway.purchase(@options)
    assert_failure response
    assert_true response.message.include? "ShippingType is required."
  end

  # def test_successful_authorize_and_capture
  #   auth = @gateway.authorize(@amount, @options)
  #   assert_success auth

  #   assert capture = @gateway.capture(@amount, auth.authorization)
  #   assert_success capture
  #   assert_equal 'REPLACE WITH SUCCESS MESSAGE', response.message
  # end

  # def test_failed_authorize
  #   response = @gateway.authorize(@amount, @options)
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED AUTHORIZE MESSAGE', response.message
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
  #   purchase = @gateway.purchase(@options)
  #   assert_success purchase

  #   assert refund = @gateway.refund(@amount, purchase.authorization)
  #   assert_success refund
  #   assert_equal 'REPLACE WITH SUCCESSFUL REFUND MESSAGE', response.message
  # end

  # def test_partial_refund
  #   purchase = @gateway.purchase(@options)
  #   assert_success purchase

  #   assert refund = @gateway.refund(@amount-1, purchase.authorization)
  #   assert_success refund
  # end

  # def test_failed_refund
  #   response = @gateway.refund(@amount, '')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED REFUND MESSAGE', response.message
  # end

  # def test_successful_void
  #   auth = @gateway.authorize(@amount, @options)
  #   assert_success auth

  #   assert void = @gateway.void(auth.authorization)
  #   assert_success void
  #   assert_equal 'REPLACE WITH SUCCESSFUL VOID MESSAGE', response.message
  # end

  # def test_failed_void
  #   response = @gateway.void('')
  #   assert_failure response
  #   assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
  # end

  # def test_successful_verify
  #   response = @gateway.verify(@options)
  #   assert_success response
  #   assert_match %r{REPLACE WITH SUCCESS MESSAGE}, response.message
  # end

  # def test_failed_verify
  #   response = @gateway.verify(@options)
  #   assert_failure response
  #   assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
  # end

  def test_invalid_login
    gateway = PagseguroGateway.new(pagseguroemail: 'v82873057996502497451@sandbox.pagseguro.com.br', token: 'BFG56483874GFH')
    
    begin 
      gateway.purchase(@options)
    rescue ActiveMerchant::ResponseError => r
      assert_equal r.message, "Failed with 401 Unauthorized"
      assert_equal r.response.body, 'Unauthorized'
    end

  end

  # def test_dump_transcript
  #   # This test will run a purchase transaction on your gateway
  #   # and dump a transcript of the HTTP conversation so that
  #   # you can use that transcript as a reference while
  #   # implementing your scrubbing logic.  You can delete
  #   # this helper after completing your scrub implementation.
  #   dump_transcript_and_fail(@gateway, @amount, @options)
  # end

  # def test_transcript_scrubbing
  #   transcript = capture_transcript(@gateway) do
  #     @gateway.purchase(@options)
  #   end
  #   transcript = @gateway.scrub(transcript)

  #   assert_scrubbed(@credit_card.number, transcript)
  #   assert_scrubbed(@credit_card.verification_value, transcript)
  #   assert_scrubbed(@gateway.options[:password], transcript)
  # end

end
