require 'mail'

module Nines
  class Notifier
    
    def initialize(contacts)
      @contacts = contacts
    end
    
    def notify!(contact_name, check, details = '')
      contact = @contacts[contact_name]
      email_body = ERB.new(File.open(Nines::App.root + '/lib/nines/email_templates/notification.text.erb').read).result(binding)
      
      Mail.deliver do
        from      Nines::App.email_from
        to        contact['email']
        subject   "#{check.name} is #{check.up ? 'UP' : 'DOWN'}"
        body      email_body
      end
    end
    
    def human_duration(seconds)
      case
        when seconds < 60 then "#{seconds} sec"
        when seconds < 3600 then "#{seconds/60} min #{seconds%60} sec"
        when seconds < 86400 then "#{seconds/3600} hr #{seconds%3600/60} min #{seconds%60} sec"
        else "#{seconds/86400} day #{seconds%86400/3600} hr #{seconds%3600/60} min #{seconds%60} sec"
      end
    end
    
  end
end
