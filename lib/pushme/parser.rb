require 'json'
require 'feedzirra'
require 'restclient'

module Pushme
  class ParserError < Exception
  end

  class Parser
    include MongoMapper::Document

    key :feed_url, String
    key :feed_type, String
    key :redis_key, String
    key :pusher, Pushme::Push

    def items
      if feed_type == 'json'
        JSON.parse(RestClient.get(feed_url))['value']['items'].each do |item|
          yield item['link']
        end
      elsif feed_type == 'rss' || feed_type == 'atom'
        Feedzirra::Feed.parse(RestClient.get(feed_url)).entries.each do |entry|
          yield entry.url
        end
      else
        raise ParserError.new("the feed type : #{feed_type} is unknow")
      end
    end

    def push(link)
      pusher.push(link)
    end
  end
end
