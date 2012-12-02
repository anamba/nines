require 'net/ping'
require 'dnsruby'

module Nines
  class App
    class << self
      attr_accessor :continue
    end
    
    attr_accessor :config, :logfile, :pidfile, :debug, :verbose, :user_agent, :logger
    
    def initialize(config_file)
      @config = YAML.load(File.read(config_file))
      @logfile = config['logfile'] || 'nines.log'
      @pidfile = config['pidfile'] || 'nines.pid'
      @debug = config['debug']
      @verbose = config['verbose']
      @user_agent = config['user_agent'] || "nines/1.0"
    end
    
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
    
    def check_hostnames
      all_good = true
      
      config['hosts'].each do |host, options|
        unless options['hostname'] && Dnsruby::Resolv.getaddress(options['hostname'])
          puts "Error: host #{host} has invalid hostname '#{options['hostname']}'"
          all_good = false
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
      
      self.logger = debug ? STDOUT : File.open(logfile, 'a')
      logger.sync = 1
      logger.puts "[#{Time.now}] - nines starting"
      
      # iterate through config
      threads = []
      config['hosts'].each do |host, options|
        logger.puts "[#{Time.now}] - #{host} - Starting up checks"
        hostname = options.delete('hostname')
        
        options.each do |name, check_opts|
          case name
          when /http-check/
            check_opts['debug'] = debug
            check_opts['host'] = host
            check_opts['user_agent'] = user_agent
            threads << Thread.new(Thread.current) { |parent|
              begin
                check = HttpCheck.new(hostname, check_opts)
                check.run(logger)
              rescue Exception => e
                parent.raise e
              end
            }
            
          when /ping-check/
            check_opts['debug'] = debug
            check_opts['host'] = host
            threads << Thread.new(Thread.current) { |parent|
              begin
                check = PingCheck.new(hostname, check_opts)
                check.run(logger)
              rescue Exception => e
                parent.raise e
              end
            }
          
          else
            logger.puts "Unknown scan type or option found: #{name}"
          end
        end
      end
      
      threads.each { |t| t.join if t.alive? }
      
      logger.puts "[#{Time.now}] - nines finished"
      logger.close unless debug
      
      puts "Background process finished"
    end
    
    def stop(options = {})
      begin
        pid = File.read(@pidfile).to_i
        Process.kill "INT", pid
      rescue Exception => e
        puts "Could not stop background process: #{e}"
        exit 1
      end
      exit 0
    end
    
  end
end
