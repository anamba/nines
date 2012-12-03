module Nines
  class PingCheck
    attr_accessor :group, :name, :hostname, :timeout, :port, :interval, :protocol, :logger, :notifier
    
    def initialize(group, options)
      @group = group
      @hostname = options['hostname']
      @name = options['name'] || @hostname
      @timeout = options['timeout_sec'] || 10
      @port = options['port']
      @interval = options['interval_sec'] || 60
      @protocol = (options['protocol'] || 'icmp').downcase
      @logger = Nines::App.logger || STDOUT
      @notifier = Nines::App.notifier
      @times_notified = {}
    end
    
    # shortcuts
    def debug     ; Nines::App.debug    ; end
    
    def run
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
          logger.puts "[#{Time.now}] - #{name} - Check passed: #{protocol == 'icmp' ? 'icmp' : "#{protocol}/#{port}"} ping on #{hostname} (#{address})"
        else
          logger.puts "[#{Time.now}] - #{name} - Check FAILED: #{port ? "#{protocol}/#{port}" : protocol} ping on #{hostname} (#{address}), timeout #{timeout}"
          
          if notifier && to_notify = group.contacts_to_notify(@times_notified)
            to_notify.each do |contact_name|
              notifier.notify!(contact_name)
              @times_notified[contact_name] ||= 0
              @times_notified[contact_name] += 1
            end
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
