require File.join File.dirname(__FILE__), 'Exceptions.rb'
require File.join File.dirname(__FILE__), 'Registry.rb'
require File.join File.dirname(__FILE__), 'ExceptionLimiter.rb'

require 'net/smtp'



class Notifier
  @@from = 'lan@tamu.edu'
  @@to = 'jrafferty@tamu.edu'

  def initialize
    @limiter = ExceptionLimiter.new
  end
  
  def notify(e)    
    if @limiter.should_raise? e
      exception_method_name = e.class.to_s.underscore
      if self.respond_to? exception_method_name, true
        send(exception_method_name, e)
      else
        unspecified_error e
      end
    end
  end
  
  def clear(e)
    @limiter.clear(e)
  end
  
  private
  
  def connection_timeout(e)
    msg = "Connection timed out while trying to connect to #{e.object.host}."
    puts "EXCEPTION: #{msg}"
    
    send_email("Connection timeout on #{e.object.host}", msg)
  end
  
  def http_error(e)
    msg = "Got http error #{e.message} when trying read status page on #{e.object.host}."
    puts "EXCEPTION: #{msg}"
    
    send_email("HTTP Error #{e.message} on #{e.object.host}", msg)
  end
  
  def structure_not_found(e)
    msg = "Unexpected HTML table structure on status page of #{e.object.host}."
    puts "EXCEPTION: #{msg}"
    
    send_email("Unexpected response from #{e.object.host}", msg)
  end
  
  def queue_not_found(e)
    msg = "Queue '#{e.object.queue}' not listed on the status page of host: #{e.object.host}."
    puts "EXCEPTION: #{msg}"
    
    send_email("Queue error on #{e.object.host}", msg)
  end
  
  def unknown_status_value(e)
    msg = "Unknown status '#{e.message}' for queue '#{e.object.queue}' listed on the status page of host: #{e.object.queue}."
    puts "EXCEPTION: #{msg}"
    
    send_email("Queue error on #{e.object.host}", msg)
  end
  
  def empty_response(e)
    msg = "Empty http response received from host: #{e.object.host}."
    puts "EXCEPTION: #{msg}"
    
    send_email("Unexpected response from #{e.object.host}", msg)
  end
  
  def registry_read_error(e)
    msg = "Error reading the registry at key #{e.object.regkey.key_path}."
    puts "EXCEPTION: #{msg}"
    
    send_email_with_reg("Registry read error", msg)
  end
  
  def registry_write_error(e)
    msg = "Error writing to the registry at the key #{e.message}. A pending change needs to be made to #{e.object.regkey.key_path}, but write access was denied.\n"
    
    # This ternary needs to be OPPOSITE of the expected result, because @accepting will not be changed before an exception is raised
    msg += "New value needs to be: " + (e.object.accepting) ? (e.class).bogus_host : e.object.host
    
    send_email_with_reg("Registry write error", msg)
  end
  
  def unspecified_error(e)
    msg = "Exception: #{e}\n#{e.message}"
    send_email("Exception was raised", msg)
  end
  
  private
  
  def send_email(subject, body, html=false)
    body.gsub!(/(\r)?\n/, "<br />") if html

    message = <<-MESSAGE_END.gsub(/^ {6}/, '')
      From: Xerox 4112 Queue Checker (SCC) <#{@@from}>
      To: #{@@to}
      Subject: [Xerox QChecker] (SCC) #{subject}
      MIME-Version: 1.0
      #{ "Content-type: text/html" if html }

      #{body}
    MESSAGE_END

    Net::SMTP.start('smtp-relay.tamu.edu') do |smtp|
      smtp.send_message message, @@from, @@to
    end
  end
  
  def send_email_with_reg(subject, body)
    message = <<-MESSAGE.gsub(/^ {6}/, '')
      #{body}

      Current registry status:

      <span style="font-family:monospace">#{self.build_registry_table}</span>
    MESSAGE

    send_email(subject, message, true)
  end
  
  def build_registry_table
    s = "SYSTEM\\CurrentControlSet\\Control\\Print\\Monitors\\Pcounter Port\\Ports:\n"
    s += (0..(s.length)).map { "=" }.join + "\n"
    PORTS.each do |port|
      begin
        t = "#{port.name}".ljust(60, '.') + port.regkey.read_key("hostname") + "\n"
        t += (0..(t.length)).map { "-" }.join + "\n"
        s += t
      rescue Exception => e
        s += "#{port.name}: Error - #{e}" + "\n"
      end
    end
    s
  end
end

class String
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end