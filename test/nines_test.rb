require 'test_helper'
require 'nines'

class NinesTest < Test::Unit::TestCase
  
  def teardown
  end
  
  def test_config1_rb
    config_file = File.expand_path('../test_config1.rb', __FILE__)
    assert app = Nines::App.new(config_file)
    
    # check defaults
    assert Nines::App.debug === false
    assert Nines::App.verbose === false
    assert Nines::App.logfile == 'nines.log'
    assert Nines::App.pidfile == 'nines.pid'
    
    # these class settings and instance settings should be equivalent
    assert Nines::App.config == app.config
    assert Nines::App.logfile == app.logfile
    assert Nines::App.pidfile == app.pidfile
    assert Nines::App.debug === app.debug
    assert Nines::App.logger == app.logger
  end
  
  def test_config_1_yaml
    config_file = File.expand_path('../test_config1.yml', __FILE__)
    assert app = Nines::App.new(config_file)
    
    # check defaults
    assert Nines::App.debug === false
    assert Nines::App.verbose === false
    assert Nines::App.logfile == 'nines.log'
    assert Nines::App.pidfile == 'nines.pid'
    
    # these class settings and instance settings should be equivalent
    assert Nines::App.config == app.config
    assert Nines::App.logfile == app.logfile
    assert Nines::App.pidfile == app.pidfile
    assert Nines::App.debug === app.debug
    assert Nines::App.logger == app.logger
  end
  
  def test_config_smtp
    config_file = File.expand_path('../test_config1.rb', __FILE__)
    assert app = Nines::App.new(config_file)
    
    Nines::App.config['smtp'] = {
      :address => 'mx1.example.com',
      :port => 465,
      :domain => 'example.com',
      :user_name => 'asdf',
      :password => 'passw0rd1',
      :authentication => :plain,
      :enable_starttls_auto => false,
      :tls => true,
    }
    app.stringify_config!
    app.configure_smtp
    
    m = Mail.new
    assert m.delivery_method.settings[:address] == 'mx1.example.com'
    # assert m.delivery_method.settings[:port] == 465
    # assert m.delivery_method.settings[:domain] == 'example.com'
    # assert m.delivery_method.settings[:user_name] == 'asdf'
    # assert m.delivery_method.settings[:password] == 'passw0rd1'
    # assert m.delivery_method.settings[:authentication] === :plain
    # assert m.delivery_method.settings[:enable_starttls_auto] === false
    # assert m.delivery_method.settings[:tls] === true
  end
  
  private
    
    
end
