require 'yaml'
require 'erb'
require 'net/ping'
require 'dnsruby'

module Nines
  class App
    class << self
      attr_accessor :config, :logfile, :pidfile, :debug, :verbose, :continue, :state, :state_mutex, :logger, :notifier
    end
    
    def initialize(config_file)
      case File.extname(config_file)
        when '.yml' then self.class.config = YAML.load(ERB.new(File.read(config_file)).result)
        when '.rb'  then require config_file
      end
      self.class.config = stringify_keys_and_symbols(self.class.config)
      
      if !config['check_groups'].is_a?(Array) || config['check_groups'].empty?
        raise Exception.new("No check groups configured, nothing to do.")
      end
      
      @check_groups = []
      config['check_groups'].each do |options|
        @check_groups << CheckGroup.new(options)
      end
      
      self.class.logfile = config['logfile'] || 'nines.log'
      self.class.pidfile = config['pidfile'] || 'nines.pid'
      self.class.debug   = config['debug']
      self.class.verbose = config['verbose']
    end
    
    # shortcuts
    def config    ; self.class.config   ; end
    def logfile   ; self.class.logfile  ; end
    def pidfile   ; self.class.pidfile  ; end
    def debug     ; self.class.debug    ; end
    def verbose   ; self.class.verbose  ; end
    def logger    ; self.class.logger   ; end
    def notifier  ; self.class.notifier ; end
    
    def logfile_writable
      begin
        File.open(logfile, 'a') { }
        true
      rescue Exception => e
        puts "Exception: #{e}"
        false
      end
    end
    
    def pidfile_writable
      begin
        File.open(pidfile, 'a') { }
        true
      rescue Exception => e
        puts "Exception: #{e}"
        false
      end
    end
    
    # make sure you're not using OpenDNS or something else that resolves invalid names
    def check_hostnames
      all_good = true
      
      @check_groups.each do |group|
        group.checks.each do |check|
          unless check.hostname && Dnsruby::Resolv.getaddress(check.hostname)
            puts "Error: check #{check.name} has invalid hostname '#{check.hostname}'"
            all_good = false
          end
        end
      end
      
      all_good
    end
    
    def configure_action_mailer
      if config['smtp'].is_a?(Hash)
        ActionMailer::Base.smtp_settings = {
          :address => config['smtp']['address'] || 'localhost',
          :port => config['smtp']['port'],
          :user_name => config['smtp']['user_name'],
          :password => config['smtp']['password'],
          :authentication => (config['smtp']['authentication'] || 'plain').to_sym,
          :enable_starttls_auto => config['smtp']['enable_starttls_auto'] || false,
        }
      end
    end
    
    def stringify_keys_and_symbols(obj)
      case obj.class.to_s
      when 'Array'
        obj.map! { |el| stringify_keys_and_symbols(el) }
      when 'Hash'
        obj.stringify_keys!
        obj.each { |k,v| obj[k] = stringify_keys_and_symbols(v) }
      when 'Symbol'
        obj = obj.to_s
      end
      
      obj
    end
    
    def start(options = {})
      # fork and detach
      if pid = fork
        File.open(pidfile, 'w') { |f| f.print pid }
        puts "Background process started with pid #{pid} (end it using `#{$0} stop`)"
        puts "Debug mode enabled, background process will log to STDOUT and exit after running each check once." if debug
        exit 0
      end
      
      #
      # rest of this method runs as background process
      #
      
      # trap signals before spawning threads
      self.class.continue = true
      trap("INT") { Nines::App.continue = false ; puts "Caught SIGINT, will exit after current checks complete or time out." }
      trap("TERM") { Nines::App.continue = false ; puts "Caught SIGTERM, will exit after current checks complete or time out." }
      
      self.class.logger = Logger.new(debug ? STDOUT : File.open(logfile, 'a'))
      logger.sync = 1
      logger.puts "[#{Time.now}] - nines starting"
      
      # iterate through config, spawning check threads as we go
      @threads = []
      
      @check_groups.each do |group|
        group.checks.each do |check|
          @threads << Thread.new(Thread.current) { |parent|
            begin
              check.run
            rescue Exception => e
              parent.raise e
            end
          }
        end
      end
      
      @threads.each { |t| t.join if t.alive? }
      
      logger.puts "[#{Time.now}] - nines finished"
      logger.close unless debug
      
      puts "Background process finished"
    end
    
    def stop(options = {})
      pid = File.read(self.class.pidfile).to_i
      Process.kill "INT", pid
      exit 0
    end
    
  end
end
