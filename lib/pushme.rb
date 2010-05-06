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
  option :config, :required => true do
    short '-c'
    long '--config=FILE'
    desc 'the file with configuration of pushme'
  end

  option :log do
    short '-l'
    long '--log=FILE'
    desc 'the file where all log are write'
    default STDOUT
  end

  option :help do
    long '--help'
    desc 'Show this message'
  end
end
    class ProxyLogger
      def initialize(logger)
        @logger = logger
      end

      def write(msg)
        @logger.info(msg)
      end

      def flush
        #nothing
      end

      def puts(msg)
        if msg.is_a?(Array)
          @logger.info(msg.map(&:chomp).join("\n"))
        elsif msg.is_a?(String)
          @logger.info(msg.chomp)
        else
          @logger.info(msg)
        end
      end

      def method_missing(method, *args)
        @logger.send(method, *args)
      end
    end

class LogError
  def initialize(app, logger)
    @app = app
    @logger = logger
  end

  def call(env)
    env['rack.errors'] = @logger
    @app.call(env)
  end
end

Pushme::OPTIONS = YAML.load_file(Choice.choices[:config])
Pushme::Logger = Logger.new(Choice.choices[:log])
Pushme::Logger.level = eval(Pushme::OPTIONS[:log_level]) || Logger::ERROR

parsers = Pushme::Parsers.new(Pushme::OPTIONS[:datas])
feed = Pushme::Feed.new

RestClient.enable LogError, ProxyLogger.new(Pushme::Logger)
RestClient.enable Rack::Cache,
  :verbose => true,
  :metastore   => 'redis://localhost:6379/',
  :entitystore => 'redis://localhost:6379/'

RestClient.enable Rack::CommonLogger, ProxyLogger.new(Pushme::Logger)
RestClient.log = Pushme::Logger

EventMachine.run {
  EventMachine::PeriodicTimer.new(Pushme::OPTIONS[:cycle]) do
    Pushme::Logger.info('check feeds')
    parsers.each do |parser|
      Pushme::Logger.debug("parse feeds : #{parser.inspect}")
      parser.items do |item|
        if feed.exists?(parser, item)
          parser.push(item)
          Pushme::Logger.info("push item #{item.inspect}")
        end
      end
    end
  end
  Pushme::Logger.debug('start eventmachine')
}
Pushme::Logger.debug("stop eventmachine")
