require 'net/ping'
require 'dnsruby'

module Nines
  class HttpCheck < Check
    attr_accessor :uri, :up_statuses, :user_agent
    
    def initialize(group, options)
      super(group, options)
      
      @uri = options['uri'] || "http://#{hostname}:#{port}/"
      @up_statuses = options['up_statuses'] || [ 200 ]
      @user_agent = options['user_agent'] || "nines/1.0"
    end
    
    # shortcuts
    def debug     ; Nines::App.debug    ; end
    
    def run
      while Nines::App.continue do
        check_started = Time.now
        @address = Dnsruby::Resolv.getaddress(hostname)
        
        @pinger = Net::Ping::HTTP.new(uri, port, timeout)
        @pinger.user_agent = user_agent
        
        # the check
        log_status(@pinger.ping?, "#{uri} (#{address})#{@pinger.warning ? " [warning: #{@pinger.warning}]" : ''}")
        
        break if debug
        
        wait = interval.to_f - (Time.now - check_started)
        while wait > 0 do
          break unless Nines::App.continue
          sleep [1, wait].min
          wait -= 1
        end
      end
    end
    
  end
end
