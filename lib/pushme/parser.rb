require 'json'
require 'feedzirra'
require 'restclient'

module Pushme
  class ParserError < Exception
  end

  class Parser
    attr_reader :redis_key, :feed_url, :feed_type
    def initialize(options)
      @feed_url = options[:feed_url]
      @redis_key = options[:redis_key]
      @feed_type = options[:feed_type]
      @push = Push.new(options[:push])
    end

    def items
      if @feed_type == 'json'
        JSON.parse(RestClient.get(@feed_url))['value']['items'].each do |item|
          yield item['link']
        end
      elsif @feed_type == 'rss' || @feed_type == 'atom'
        Feedzirra::Feed.parse(RestClient.get(@feed_url)).entries.each do |entry|
          yield entry.url
        end
      else
        raise ParserError.new("the feed type : #{@feed_type} is unknow")
      end
    end

    def push(link)
      @push.push(link)
    end
  end
end
