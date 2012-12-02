module Nines
  class HttpCheck
    attr_accessor :host, :hostname, :debug, :timeout, :port, :interval, :uri, :ok_statuses, :user_agent
    
    def initialize(hostname, options)
      @hostname = hostname
      @host = options['host'] || hostname
      @debug = options['debug']
      @timeout = options['timeout_sec'] || 5
      @port = options['port'] || 80
      @interval = options['interval_sec'] || 5
      @uri = options['uri'] || "http://#{hostname}:#{port}/"
      @ok_statuses = options['ok_statuses'] || [ 200 ]
      @user_agent = options['user_agent'] || "nines/1.0"
    end
    
    def run(logger = STDOUT, notifier = nil)
      while Nines::App.continue do
        address = Dnsruby::Resolv.getaddress(hostname)
        
        pinger = Net::Ping::HTTP.new(uri, port, timeout)
        pinger.user_agent = user_agent
        if pinger.ping?
          logger.puts "[#{Time.now}] - #{host} - Check passed: #{uri} (#{address}), timeout #{timeout}#{pinger.warning ? " [warning: #{pinger.warning}]" : ''}"
        else
          logger.puts "[#{Time.now}] - #{host} - Check FAILED: #{uri} (#{address}), timeout #{timeout} [reason: #{pinger.exception}]"
          
          # do some notification stuff
          if notifier
            
          end
        end
        
        # TODO: log result
        
        break if debug
        
        wait = interval.to_f - (pinger.duration || 0)
        while wait > 0 do
          break unless Nines::App.continue
          sleep [1, wait].min
          wait -= 1
        end
      end
    end
    
  end
end
