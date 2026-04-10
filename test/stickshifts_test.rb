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
end
