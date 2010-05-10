require 'eventmachine'
require 'yaml'
require 'logger'
require 'redis'
require 'restclient/components'
require 'rack/cache'
require 'redis-store'
require 'mongoid'

require 'pushme/push'
require 'pushme/parser'
require 'pushme/feed'
require 'thin'

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
      @logger.debug(msg.map(&:chomp).join("\n"))
    elsif msg.is_a?(String)
      @logger.debug(msg.chomp)
    else
      @logger.debug(msg)
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

Mongoid.configure do |config|
    name = Pushme::OPTIONS[:mongodb][:database]
    host = Pushme::OPTIONS[:mongodb][:host]
    config.allow_dynamic_fields = false
    config.master = Mongo::Connection.new.db(name, :logger => Pushme::Logger)
end

Pushme::OPTIONS[:datas].each do |data|
  if Pushme::Parser.find(:first, :conditions => {:feed_url => data[:feed_url],
                      :feed_type => data[:feed_type]}).nil?
    Pushme::Parser.create(:feed_url => data[:feed_url],
                          :feed_type => data[:feed_type],
                          :redis_key => data[:redis_key],
                          :pusher => Pushme::Push.new(data[:push]))
  end
end
feed = Pushme::Feed.new

RestClient.enable LogError, ProxyLogger.new(Pushme::Logger)
RestClient.enable Rack::Cache,
  :verbose => true,
  :metastore   => 'redis://localhost:6379/',
  :entitystore => 'redis://localhost:6379/'

RestClient.enable Rack::CommonLogger, ProxyLogger.new(Pushme::Logger)
RestClient.log = Pushme::Logger

EventMachine.run do

  EventMachine::PeriodicTimer.new(Pushme::OPTIONS[:cycle]) do
    Pushme::Logger.info('check feeds')
    Pushme::Parser.all.each do |parser|
      Pushme::Logger.debug("parse feeds : #{parser.inspect}")
      parser.items do |item|
        if feed.exists?(parser, item)
          parser.push(item)
          Pushme::Logger.info("push item #{item.inspect}")
        end
      end
    end
  end

  Thin::Server.start('0.0.0.0', 3000) do
    use Rack::CommonLogger
    use Hello
  end

end
