require 'yaml'
require 'erb'
require 'dnsruby'
require 'mail'

module Nines
  class App
    class << self
      attr_accessor :root, :config, :continue,
                    :debug, :verbose, :logfile, :pidfile, :logger, :notifier,
                    :email_from, :email_subject_prefix
    end
    
    def initialize(config_file)
      self.class.root = File.expand_path('../../../', __FILE__)
      
      # load config files
      case File.extname(config_file)
        when '.yml' then self.class.config = YAML.load(ERB.new(File.read(config_file)).result)
        when '.rb'  then require config_file
      end
      self.class.config = stringify_keys_and_symbols(self.class.config)
      
      # set main parameters
      self.class.debug      = config['debug']
      self.class.verbose    = config['verbose']
      
      self.class.logfile    = config['logfile'] || 'nines.log'
      self.class.pidfile    = config['pidfile'] || 'nines.pid'
      self.class.email_from = config['email_from'] || 'Nines Notifier <no-reply@example.com>'
      self.class.email_subject_prefix = config['email_subject_prefix'] || ''
      
      # set up logger
      self.class.logger = Logger.new(debug ? STDOUT : File.open(logfile, 'a'))
      logger.sync = 1  # makes it possible to tail the logfile
      
      # set up notifier
      configure_smtp
      self.class.notifier = Notifier.new(config['contacts'])
      
      # set up check_groups (uses logger and notifier)
      if !config['check_groups'].is_a?(Array) || config['check_groups'].empty?
        raise Exception.new("No check groups configured, nothing to do.")
      end
      
      @check_groups = []
      config['check_groups'].each do |options|
        @check_groups << CheckGroup.new(options)
      end
    end
    
    # shortcuts
    def config    ; self.class.config   ; end
    def logfile   ; self.class.logfile  ; end
    def pidfile   ; self.class.pidfile  ; end
    def debug     ; self.class.debug    ; end
    def logger    ; self.class.logger   ; end
    
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
    
    def configure_smtp
      if config['smtp'].is_a?(Hash)
        Mail.defaults do
          delivery_method :smtp, { 
            :address => Nines::App.config['smtp']['address'] || 'localhost',
            :port => Nines::App.config['smtp']['port'] || 25,
            :domain => Nines::App.config['smtp']['domain'],
            :user_name => Nines::App.config['smtp']['user_name'],
            :password => Nines::App.config['smtp']['password'],
            :authentication => (Nines::App.config['smtp']['authentication'] || 'plain').to_sym,
            :enable_starttls_auto => Nines::App.config['smtp']['enable_starttls_auto'],
            :tls => Nines::App.config['smtp']['tls'],
          }
        end
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
      logger.puts "[#{Time.now}] - nines starting"
      
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
      logger.close
      
      puts "Background process finished"
    end
    
    def stop(options = {})
      begin
        pid = File.read(self.class.pidfile).to_i
      rescue Errno::ENOENT => e
        STDERR.puts "Couldn't open pid file #{self.class.pidfile}, please check your config."
        exit 1
      end
      
      begin
        Process.kill "INT", pid
        exit 0
      rescue Errno::ESRCH => e
        STDERR.puts "Couldn't kill process with pid #{pid}. Are you sure it's running?"
        exit 1
      end
    end
    
  end
end
