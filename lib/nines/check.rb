module Nines
  class Check
    attr_accessor :group, :name, :hostname, :address, :timeout, :port, :interval, :logger, :notifier, :up, :since, :cycles
    
    def initialize(group, options)
      @group = group
      @hostname = options['hostname']
      @name = options['name'] || @hostname
      @timeout = options['timeout_sec'] || 10
      @port = options['port']
      @interval = options['interval_sec'] || 60
      
      @logger = Nines::App.logger || STDOUT
      @notifier = Nines::App.notifier
      
      @times_notified = {}
      @up = true
      @since = Time.now.utc
      @cycles = 0
    end
    
    def log_status(up, description)
      if up
        logger.puts "[#{Time.now}] - #{name} - Check passed: #{description}"
        
        case @up
        when true
          @cycles += 1
        when false
          @up = true
          @since = Time.now.utc
          @cycles = 0
          
          # back up notification
          if notifier
            @times_notified.keys.each do |contact_name|
              logger.puts "[#{Time.now}] - #{name} - UP again, notifying contact '#{contact_name}'"
              notifier.notify!(contact_name, self)
            end
            @times_notified = {}
          end
        end
      else
        logger.puts "[#{Time.now}] - #{name} - Check FAILED: #{description}"
        
        case @up
        when false
          @cycles += 1
        when true
          @up = false
          @since = Time.now.utc
          @cycles = 0
        end
        
        if notifier && to_notify = group.contacts_to_notify(@cycles, @times_notified)
          to_notify.each do |contact_name|
            logger.puts "[#{Time.now}] - #{name} - Notifying contact '#{contact_name}'"
            notifier.notify!(contact_name, self)
            @times_notified[contact_name] ||= 0
            @times_notified[contact_name] += 1
          end
        end
      end
    end
    
  end
end
