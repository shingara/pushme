class PushmeServer < Sinatra::Base
  # params[:feed_url]
  # params[:feed_type]
  # params[:pusher][:push_type]
  # params[:pusher][:options]
  post '/' do
    if Pushme::Parser.find(:first, :conditions => {:feed_url => params[:push][:feed_url],
                      :feed_type => params[:push][:feed_type]}).nil?
      parser = Pushme::Parser.new(params[:push])
      parser.redis_key = parser.feed_url
      parser.save
      'save'
    else
      'already exist'
    end
  end

  get '/' do
    'hello'
  end
end
