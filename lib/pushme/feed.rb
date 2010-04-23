require 'redis'
module Pushme
  class Feed
    def initialize
      @redis = Redis.new
    end
    def bootstrap_data(parsers)
      parsers.each do |parser|
        redis.delete(parser.redis_key)
        parser.items do |item|
          redis.set_add parser.redis_key, item['link']
        end
      end
    end
    def exists?(parser, link)
      @redis.set_add(parser.redis_key, link)
    end

  end
end
