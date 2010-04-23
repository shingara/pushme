module Pushme
  class Parsers < Array
    def initialize(options)
      options.each do |option|
        self << Parser.new(option)
      end
    end
  end
end
