require 'eventmachine'
require 'yaml'
require 'logger'
require 'redis'
require 'restclient/components'
require 'rack/cache'
require 'redis-store'
require 'mongo_mapper'

require 'pushme/push'
require 'pushme/parser'
#require 'pushme/parsers'
require 'pushme/feed'

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

  option :jid, :required => true do
    long '--jid=jid'
    desc 'your jid listen'
  end

  option :jid_password, :required => true do
    long '--jid-password=jid-password'
    desc 'your password of your jid'
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

MongoMapper.connection = Mongo::Connection.new(Pushme::OPTIONS[:mongodb][:host],
                                               Pushme::OPTIONS[:mongodb][:port],
                                               :logger => Pushme::Logger)
MongoMapper.database = Pushme::OPTIONS[:mongodb][:database]
MongoMapper.database.authenticate(Pushme::OPTIONS[:mongodb][:username],
                                  Pushme::OPTIONS[:mongodb][:password]) if Pushme::OPTIONS[:mongodb][:username] && Pushme::OPTIONS[:mongodb][:password]

#parsers = Pushme::Parsers.new(Pushme::OPTIONS[:datas])
Pushme::Parser.all.each {|f| f.delete }
Pushme::OPTIONS[:datas].each do |data|
  unless Pushme::Parser.exists?(:feed_url => data[:feed_url],
                      :feed_type => data[:feed_type])
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

require 'blather/client/dsl'
$stdout.sync = true

module Ping
  extend Blather::DSL

  def self.run; client.run; end

  setup Choice.choices[:jid], Choice.choices[:jid_password]

  when_ready do
    p 'ok'
    Pushme::Logger.debug "Connected ! send messages to #{jid.stripped}."
  end

  message do |m|
    p 'message'
    p m
  end

  message :chat?, :body do |m|
    puts 'ok'
    say m.from, 'ping'
  end
end

EventMachine.run {
  Ping.run

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
  Pushme::Logger.debug('start eventmachine')

}

Pushme::Logger.debug("stop eventmachine")
