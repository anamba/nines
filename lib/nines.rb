require 'nines/app'
require 'nines/check_group'
require 'nines/http_check'
require 'nines/ping_check'
require 'nines/logger'
require 'nines/notifier'
require 'nines/version'

# borrowed from activesupport
unless Hash.new.respond_to?(:stringify_keys!)
  class Hash
    def stringify_keys!
      keys.each do |key|
        self[key.to_s] = delete(key)
      end
      self
    end
  end
end
