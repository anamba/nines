module Nines
  class PingCheck
    attr_accessor :host, :hostname, :debug, :timeout, :port, :interval, :protocol
    
    def initialize(hostname, options)
      @hostname = hostname
      @host = options['host'] || hostname
      @debug = options['debug']
      @timeout = options['timeout_sec'] || 5
      @port = options['port']
      @interval = options['interval_sec'] || 5
      @protocol = (options['protocol'] || 'icmp').downcase
    end
    
    def run(logger = STDOUT, notifier = nil)
      while Nines::App.continue do
        address = Dnsruby::Resolv.getaddress(hostname)
        
        pinger = case protocol
          when 'tcp'  then Net::Ping::TCP.new(hostname, nil, timeout)
          when 'udp'  then Net::Ping::UDP.new(hostname, nil, timeout)
          when 'icmp'
            if Process::UID == 0
              Net::Ping::ICMP.new(hostname, nil, timeout)
            else
              Net::Ping::External.new(hostname, nil, timeout)
            end
          else "invalid ping protocol #{protocol}"
        end
        
        if pinger.ping?
          logger.puts "[#{Time.now}] - #{host} - Check passed: #{protocol == 'icmp' ? 'icmp' : "#{protocol}/#{port}"} ping on #{hostname} (#{address}), timeout #{timeout}"
        else
          logger.puts "[#{Time.now}] - #{host} - Check FAILED: #{port ? "#{protocol}/#{port}" : protocol} ping on #{hostname} (#{address}), timeout #{timeout}"
          
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
