module Nines
  class HttpCheck
    attr_accessor :group, :name, :hostname, :timeout, :port, :interval, :uri, :up_statuses, :user_agent, :logger, :notifier
    
    def initialize(group, options)
      @group = group
      @hostname = options['hostname']
      @name = options['name'] || @hostname
      @timeout = options['timeout_sec'] || 10
      @port = options['port'] || 80
      @interval = options['interval_sec'] || 60
      @uri = options['uri'] || "http://#{hostname}:#{port}/"
      @up_statuses = options['up_statuses'] || [ 200 ]
      @user_agent = options['user_agent'] || "nines/1.0"
      @logger = Nines::App.logger || STDOUT
      @notifier = Nines::App.notifier
      @times_notified = {}
    end
    
    # shortcuts
    def debug     ; Nines::App.debug    ; end
    
    def run
      while Nines::App.continue do
        address = Dnsruby::Resolv.getaddress(hostname)
        
        pinger = Net::Ping::HTTP.new(uri, port, timeout)
        pinger.user_agent = user_agent
        if pinger.ping?
          logger.puts "[#{Time.now}] - #{name} - Check passed: #{uri} (#{address})#{pinger.warning ? " [warning: #{pinger.warning}]" : ''}"
        else
          logger.puts "[#{Time.now}] - #{name} - Check FAILED: #{uri} (#{address}), timeout #{timeout} [reason: #{pinger.exception}]"
          
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
