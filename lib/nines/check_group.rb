module Nines
  class CheckGroup
    attr_accessor :contacts, :checks
    
    def initialize(options = {})
      options.stringify_keys!
      @name = options['name']
      @description = options['description']
      
      parameters = options['parameters'] || {}
      parameters.stringify_keys!
      @check_type = parameters.delete('type')
      
      @contacts = []
      notify = options['notify'] || []
      notify.each do |contact|
        contact.stringify_keys!
        @contacts << {
          'name'  => contact['contact'],
          'after' => contact['after'] || 2,
          'every' => contact['every'] || 5,
          'upto'  => contact['upto'] || 5
        }
      end
      
      @checks = []
      checks = options['checks'] || []
      checks.each do |check|
        check = { hostname: check } unless check.is_a?(Hash)
        check.stringify_keys!
        case @check_type
        when 'http'
          @checks << HttpCheck.new(self, parameters.merge(check))
        when 'ping'
          @checks << PingCheck.new(self, parameters.merge(check))
        else
          raise Exception.new("Unknown check type: #{@check_type} (supported values: http, ping)")
        end
      end
    end
    
    # times_notified must be a hash with contact names as keys
    def contacts_to_notify(cycles, times_notified)
      # cycles starts at 0, but user generally expects first down event to be cycle 1
      
      to_notify = []
      @contacts.each do |contact|
        next if times_notified[contact['name']].to_i >= contact['upto']
        next if (cycles+1) < contact['after']
        next if (cycles+1 - contact['after']) % contact['every'] != 0
        to_notify << contact['name']
      end
      
      to_notify
    end
    
  end
end
