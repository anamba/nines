require 'action_mailer'
require 'inline-style'

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.register_interceptor InlineStyle::Mail::Interceptor.new
ActionMailer::Base.view_paths= File.dirname(__FILE__)
ActionMailer::Base.smtp_settings = { :address => 'localhost', :port => 25 }

class Mailer < ActionMailer::Base
  
  def notification(options)
    @body = options[:body]
    mail(:to => options[:to], :from => options[:from], :subject => options[:subject])
  end
  
end
