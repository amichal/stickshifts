# frozen_string_literal: true

require 'bundler/setup'
Bundler.require(:default)
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/string'

OpenURI::Cache.cache_path = "#{File.dirname(__FILE__)}/tmp/cache"
FileUtils.mkdir_p OpenURI::Cache.cache_path

def fetch_kbb(path)
  url = URI.parse('https://www.kbb.com').merge(path)
  unless OpenURI::Cache.get(url)
    sleep(0.1) # don't hammer KBB
  end
  Nokogiri::HTML(url.open)
rescue OpenURI::HTTPError => e
  warn "#{url} #{e.message}"
  nil
end

if __FILE__ == $PROGRAM_NAME
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
    if (new_category = categories.detect { |c| n.text.include?(c) })
      @current_category = new_category
      next
    end

    name = n.text.strip

    # get descriptions
    desc = ''
    desc_node = n.parent.next_element
    nodes_checked = 0
    max_nodes_to_check = 100
    while desc_node && !desc_node.at_css('strong')
      desc += desc_node.text
      nodes_checked += 1
      break if nodes_checked >= max_nodes_to_check

      desc_node = desc_node.next_element
    end

    # make and model
    make = makers.detect do |m|
      name.include? m
    end || name.split(' ').first
    model = name.gsub(make, '').strip.presence || name
    funny_model_names = {
      %w[Mazda 3] => 'MAZDA3',
      %w[Mazda 6] => 'MAZDA6',
      %w[Mini Mini] => 'Countryman',
      ['Subaru', 'WRX and WRX STi'] => 'WRX'
    }
    model = funny_model_names[[make, model]] || model

    # go ask KBB for data on the model and styles (aka trims)
    # for 2016
    kbb_url = "/#{make.parameterize}/#{model.parameterize}/2018/"
    options = {}
    if (kbb_data = fetch_kbb(kbb_url))
      options = kbb_data.css('#Styles-dropdown-subtitle option').map do |n|
        url = n['data-options-url']
        url ? [url, n.text] : nil
      end.compact.select do |_k, v|
        v.include?('Manual') && !v.include?('2-door')
      end
    end

    # report cars we cant find trims for so we can fix up
    # our lookup code for them later
    if options.empty?
      data << {
        category: @current_category,
        make: make,
        model: model,
        trim: nil,
        kbb_true_price: nil,
        trim_url: nil
      }
    else
      # report pricing for each style group
      options.each do |url, trim|
        trim_path = url.gsub('/options', '')
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
          trim_url: "https://www.kbb.com#{trim_path}"
        }
      end
    end
  end

  puts data.first.keys.to_csv
  data.map(&:values).each do |row|
    puts row.to_csv
  end
end
