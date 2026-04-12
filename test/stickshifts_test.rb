require 'minitest/autorun'
require 'webmock/minitest'
require_relative '../stickshifts'

class StickshiftsTest < Minitest::Test
  def test_fetch_kbb_returns_parsed_html
    stub_request(:get, 'https://www.kbb.com/honda/civic/2018/')
      .to_return(status: 200, body: '<html><body><h1>Honda Civic</h1></body></html>')

    result = fetch_kbb('/honda/civic/2018/')

    assert_instance_of Nokogiri::HTML4::Document, result
    assert_equal 'Honda Civic', result.at_css('h1').text
  end

  def test_fetch_used_price_returns_retail_price
    stub_request(:get, 'https://www.nadaguides.com/Cars/2018/Honda/Civic/')
      .to_return(status: 200, body: <<~HTML)
        <html><body>
          <div class="price-section">
            <div class="retail">
              <span class="price-value">$14,750</span>
            </div>
          </div>
        </body></html>
      HTML

    result = fetch_used_price('Honda', 'Civic', 2018)

    assert_equal '$14,750', result
  end

  def test_fetch_used_price_returns_nil_on_http_error
    stub_request(:get, 'https://www.nadaguides.com/Cars/2018/Honda/Fit/')
      .to_return(status: 404)

    result = fetch_used_price('Honda', 'Fit', 2018)

    assert_nil result
  end

  def test_fetch_used_price_handles_multi_word_make
    stub_request(:get, 'https://www.nadaguides.com/Cars/2018/Alfa-Romeo/Giulia/')
      .to_return(status: 200, body: '<html><body></body></html>')

    result = fetch_used_price('Alfa Romeo', 'Giulia', 2018)

    assert_nil result  # no price element in stub — just verifying URL construction
  end
end
