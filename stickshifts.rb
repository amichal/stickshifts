require 'bundler/setup'
Bundler.require(:default)

OpenURI::Cache.cache_path = "#{File.dirname(__FILE__)}/tmp/cache"
FileUtils.mkdir_p OpenURI::Cache.cache_path

require 'nokogiri';
require 'active_support/core_ext/string'

def fetch_kbb(path)
  STDERR.puts path
  url = "https://www.kbb.com#{path}"
  if !OpenURI::Cache.get(url)
    sleep(0.1) # dont hammer KBB
  end
  Nokogiri::HTML(URI.open(url))
rescue OpenURI::HTTPError => err
  #STDERR.puts "#{url} #{err.message}"
  nil
end

def fetch_nada(path)
  STDERR.puts path
  url = "https://www.nadaguides.com#{path}"
  if !OpenURI::Cache.get(url)
    sleep(0.1) # don't hammer NADA
  end
  Nokogiri::HTML(URI.open(url))
rescue OpenURI::HTTPError => err
  STDERR.puts "#{url} #{err.message}"
  nil
end

# Returns the NADA average retail price for a used car as a string (e.g. "$12,345"),
# or nil if the page or price element cannot be found.
# NADA Guides URL format: /Cars/{year}/{Make}/{Model}/
# Make and model use title-cased words joined by hyphens (e.g. "Alfa-Romeo", "CR-Z").
def fetch_used_price(make, model, year)
  nada_make  = make.split.map(&:capitalize).join('-')
  nada_model = model.split.map(&:capitalize).join('-')
  path = "/Cars/#{year}/#{nada_make}/#{nada_model}/"
  return nil unless (doc = fetch_nada(path))

  # NADA renders three price columns: Trade-In, Loan, and Retail.
  # We want the Average Retail value — the closest equivalent to a
  # fair used-car asking price.
  doc.at_css('.price-section .retail .price-value, ' \
             '.pricing-module [data-price-type="retail"], ' \
             'td.retail-price, ' \
             '.average-retail')&.text&.gsub(/[[:space:]]+/, '')
end

if __FILE__ == $0
  doc = Nokogiri::HTML URI.open('https://bestride.com/research/buyers-guide/manual-transmission-availability-2016-2017/')

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

    # make and model
    make = makers.detect do |m|
      name.include? m
    end || name.split(' ').first
    model = name.gsub(make,'').strip || name
    funny_model_names = {
      ['Mazda','3'] => 'MAZDA3',
      ['Mazda','6'] => 'MAZDA6',
      ['Mini','Mini'] => 'Countryman',
      ['Subaru','WRX and WRX STi'] => 'WRX'
    }
    model = funny_model_names[[make,model]] || model

    # go ask KBB for data on the model and styles (aka trims)
    # for 2016
    kbb_url = "/#{make.parameterize}/#{model.parameterize}/2018/"
    options = {}
    if (kbb_data = fetch_kbb(kbb_url))
      options = kbb_data.css('#Styles-dropdown-subtitle option').map do |n|
        url = n['data-options-url']
        url ? [url, n.text] : nil
      end.compact.select do |k,v|
        v.include?('Manual') && !v.include?('2-door')
      end
    end

    # report cars we cant find trims for so we can fix up
    # our lookup code for them later
    if options.size == 0
      price = fetch_used_price(make, model, 2018) # just to verify we can get a price for it — if not, we'll need to fix that too\

      data << {
        category: @current_category,
        make: make,
        model: model,
        trim: nil,
        kbb_true_price: nil,
        used_price: price,
        trim_url: nil,
      }
    else
      # report pricing for each style group
      options.each do |url, trim|
        trim_path = "#{url.gsub('/options','')}"
        kbb_true_price = nil
        if (trim_data = fetch_kbb(trim_path))
          kbb_true_price = trim_data.at_css('.market-info strong').try(:text)
        end
        data << {
          category: @current_category,
          make: make,
          model: model,
          trim: trim,
          kbb_true_price: kbb_true_price,
          used_price: fetch_used_price(make, model, 2018),
          trim_url: "https://www.kbb.com#{trim_path}",
        }
      end
    end
    pp data.last
  end

  puts data.first.keys.to_csv
  data.map(&:values).each do |row|
    puts row.to_csv
  end
end
