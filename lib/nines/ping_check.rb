require 'net/ping'
require 'dnsruby'

module Nines
  class PingCheck < Check
    attr_accessor :protocol
    
    def initialize(group, options)
      super(group, options)
      
      @protocol = (options['protocol'] || 'icmp').downcase
    end
    
    # shortcuts
    def debug     ; Nines::App.debug    ; end
    
    def run
      while Nines::App.continue do
        check_started = Time.now
        @address = Dnsruby::Resolv.getaddress(hostname)
        
        @pinger = case protocol
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
        
        # the check
        log_status(@pinger.ping?, "#{protocol == 'icmp' ? 'icmp' : "#{protocol}/#{port}"} ping on #{hostname} (#{address})")
        
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
