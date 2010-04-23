require 'json'
require 'restclient'

module Pushme
  class Parser
    attr_reader :redis_key, :feed_url
    def initialize(options)
      @feed_url = options[:feed_url]
      @redis_key = options[:redis_key]
      @push = Push.new(options[:push])
    end

    def items
      JSON.parse(RestClient.get(@feed_url).body)['value']['items'].each do |item|
        yield item
      end
    end

    def push(link)
      @push.push(link)
    end
  end
end
