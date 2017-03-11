require 'open-uri/cached';
require 'fileutils';
OpenURI::Cache.cache_path = "#{File.dirname(__FILE__)}/tmp/cache"
FileUtils.mkdir_p OpenURI::Cache.cache_path

require 'nokogiri';
require 'uri'
require 'pp'
require 'text-table'
require 'active_support/core_ext/string'


bits = open('http://bestride.com/research/buyers-guide/manual-transmission-availability-2016-2017#car1manual-transmission-availability-2016-2017')

doc = Nokogiri::HTML(bits)


def fetch_kbb(path)
  Nokogiri::HTML(open("https://www.kbb.com#{path}"))
rescue OpenURI::HTTPError => err
  #STDERR.puts "#{path} #{err.message}"
  nil
end

data = []
categories = [
  'COMPACT',
  'MID-SIZED',
  'PICKUPS',
  'SPORTS CARS',
  'SPORT SEDANS'
]

# we only need to two word ones
makers = [
  'Aston Martin',
  'Alfa Romeo'
]
@current_category = nil
doc.css('p > strong').each do |n|
  # skip promo-links
  next if n.text =~ /Find a /

  # handle category changes
  if (new_category = categories.detect{|c| n.text.include?(c)})
    @current_category = new_category
    next
  end

  name = n.text.strip

  # get descriptions
  desc = ""
  desc_node = n.parent.next_element
  nodes_checked = 0
  max_nodes_to_check = 100
  while desc_node && !desc_node.at_css('strong')
    desc.concat desc_node.text
    nodes_checked += 1
    break if nodes_checked >= max_nodes_to_check
    desc_node = desc_node.next_element
  end
  make = makers.detect do |m|
    name.include? m
  end || name.split(' ').first
  model = name.gsub(make,'').strip.presence || name

  funny_model_names = {
    ['Mazda','3'] => 'MAZDA3',
    ['Mazda','6'] => 'MAZDA6',
    ['Mini','Mini'] => 'Countryman'
  }
  model = funny_model_names[[make,model]] || model

  kbb_url = "/#{make.parameterize}/#{model.parameterize}/2016/"

  options = {}
  if (kbb_data = fetch_kbb(kbb_url))
    options = kbb_data.css('#Styles-dropdown-subtitle option').map do |n|
      url = n['data-options-url'].presence
      url ? [url, n.text] : nil
    end.compact.select do |k,v|
      v.include?('Manual') && !v.include?('2-door')
    end
  end

  # FIXME: report cars we cant find trims for so we can fix them up
  if options.size == 0
    data << {
      category: @current_category,
      make: make,
      model: model,
      trim: nil,
      kbb_true_price: nil
    }
  else
    options.each do |url, trim|
      params = CGI::parse(url.split('?',2).last)
      trim_url = "#{url.gsub('/options','')}"
      kbb_true_price = nil
      if (trim_data = fetch_kbb(trim_url))
        kbb_true_price = trim_data.at_css('.market-info strong').try(:text)
      end
      data << {
        category: @current_category,
        make: make,
        model: model,
        trim: trim,
        trim_url: trim_url,
        kbb_true_price: kbb_true_price
      }
    end
  end
end

puts Text::Table.new(head: data.first.keys, rows: data.map(&:values))

