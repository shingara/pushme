require 'pushme/push'
require 'pushme/parser'
require 'pushme/parsers'
require 'pushme/feed'

require 'eventmachine'
require 'yaml'
require 'logger'
require 'redis'
require 'restclient/components'
require 'rack/cache'
require 'redis-store'

require 'choice'

Choice.options do
  option :config do
    short '-c'
    long '--config=FILE'
    desc 'the file with configuration of pushme'
  end

  option :help do
    long '--help'
    desc 'Show this message'
  end

end

Pushme::OPTIONS = YAML.load_file(Choice.choices[:config])
Pushme::Logger = Logger.new(STDOUT)
Pushme::Logger.level = eval(Pushme::OPTIONS[:log_level]) || Logger::ERROR

parsers = Pushme::Parsers.new(Pushme::OPTIONS[:datas])
feed = Pushme::Feed.new

RestClient.enable Rack::Cache,
  :metastore   => 'redis://localhost:6379/',
  :entitystore => 'redis://localhost:6379/'

RestClient.enable Rack::CommonLogger, Pushme::Logger
RestClient.log = Pushme::Logger

EventMachine.run {
  EventMachine::PeriodicTimer.new(Pushme::OPTIONS[:cycle]) do
    Pushme::Logger.info('check feeds')
    parsers.each do |parser|
      Pushme::Logger.debug("parse feeds : #{parser.inspect}")
      parser.items do |item|
        #Pushme::Logger.debug("items : #{item.inspect}")
        if feed.exists?(parser, item['link'])
          parser.push(item['link'])
          Pushme::Logger.info("push item #{item.inspect}")
        end
      end
    end
  end
  Pushme::Logger.debug('start eventmachine')
}
Pushme::Logger.debug("stop eventmachine")
