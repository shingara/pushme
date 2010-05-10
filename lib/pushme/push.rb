require 'twitter'
require 'restclient'

module Pushme
  class Push
    include Mongoid::Document
    field :push_type, :type => String
    field :options, :type => Hash

    def push(link)
      send(type, link)
    end

    private

    def twitter(link)
      httpauth = Twitter::HTTPAuth.new(options[:login], options[:password])
      client = Twitter::Base.new(httpauth)
      client.update("New question : #{link}")
    end

    def open_notification(link)
      RestClient.post('http://open-notification.com/messages',
                      {'body'=> "News entries on feed #{link} ",
                        'api_key' => options[:api_key],
                        :message_kinds => {'0' => {'channel' => options[:channel], 'to' => options[:to]}}})
    end
  end
end
