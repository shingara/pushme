class PushmeServer < Sinatra::Base
  get '/' do
    'hello world'
  end
end
