require File.join File.dirname(__FILE__), 'Exceptions.rb'
require File.join File.dirname(__FILE__), 'Registry.rb'
require File.join File.dirname(__FILE__), 'ExceptionLimiter.rb'
require 'net/smtp'


# Sends email notifications when exceptions are raised
class Notifier
  # From address for notification emails
  @@from_name = 'Xerox 4112 Queue Checker (SCC)'
  @@from_addr = 'lan@tamu.edu'
  
  # Subject prefix
  @@subj = '[Xerox QChecker] (SCC)'
  
  # Default to address for notification emails
  @@to = 'jrafferty@tamu.edu'

  def initialize
    @limiter = ExceptionLimiter.new
  end
  
  # Handles a raised exception
  # @param [ExceptionWithObject] e Exception to raise
  def raise_e(e)  
    # Check if we should send a notification for this exception
    if @limiter.should_raise? e
      # Do we have a custom handler for this exception?
      exception_method_name = e.class.to_s.underscore
      if self.respond_to? exception_method_name, true
        # If so, call that method
        send(exception_method_name, e)
      else
        # If not, call the generic handler method
        unspecified_error e
      end
    end
  end
  
  # Generic notification, for debug use
  # @param [String] m Message to send in the notification
  def notify(m)
    send_email_with_reg("Debug notification", m)
  end
  
  # Clear a notification/exception to be sent again
  # @param [ExceptionWithObject] e Exception to clear
  def clear(e)
    @limiter.clear(e)
  end
  
  private
  
  # Notification to handle ConnectionTimeout exceptions
  # @param [ConnectionTimeout] e Exception
  def connection_timeout(e)
    msg = "Connection timed out while trying to connect to #{e.object.host}."
    puts "EXCEPTION: #{msg}"
    
    send_email("Connection timeout on #{e.object.host}", msg)
  end
  
  # Notification to handle HttpError exceptions
  # @param [HttpError] e Exception
  def http_error(e)
    msg = "Got http error #{e.message} when trying read status page on #{e.object.host}."
    puts "EXCEPTION: #{msg}"
    
    send_email("HTTP Error #{e.message} on #{e.object.host}", msg)
  end
  
  # Notification to handle StructureNotFound exceptions
  # @param [StructureNotFound] e Exception
  def structure_not_found(e)
    msg = "Unexpected HTML table structure on status page of #{e.object.host}."
    puts "EXCEPTION: #{msg}"
    
    send_email("Unexpected response from #{e.object.host}", msg)
  end
  
  # Notification to handle QueueNotFound exceptions
  # @param [QueueNotFound] e Exception
  def queue_not_found(e)
    msg = "Queue '#{e.object.queue}' not listed on the status page of host: #{e.object.host}."
    puts "EXCEPTION: #{msg}"
    
    send_email("Queue error on #{e.object.host}", msg)
  end
  
  # Notification to handle UnknownStatusValue exceptions
  # @param [UnknownStatusValue] e Exception
  def unknown_status_value(e)
    msg = "Unknown status '#{e.message}' for queue '#{e.object.queue}' listed on the status page of host: #{e.object.queue}."
    puts "EXCEPTION: #{msg}"
    
    send_email("Queue error on #{e.object.host}", msg)
  end
  
  # Notification to handle EmptyResponse exceptions
  # @param [EmptyResponse] e Exception
  def empty_response(e)
    msg = "Empty http response received from host: #{e.object.host}."
    puts "EXCEPTION: #{msg}"
    
    send_email("Unexpected response from #{e.object.host}", msg)
  end
  
  # Notification to handle RegistryReadError exceptions
  # @param [RegistryReadError] e Exception
  def registry_read_error(e)
    msg = "Error reading the registry at key #{e.object.regkey.key_path}."
    puts "EXCEPTION: #{msg}"
    
    send_email_with_reg("Registry read error", msg)
  end
  
  # Notification to handle RegistryWriteError exceptions
  # @param [RegistryWriteError] e Exception
  def registry_write_error(e)
    msg = "Error writing to the registry at the key #{e.message}. A pending change needs to be made to #{e.object.regkey.key_path}, but write access was denied.\n"
    
    # This ternary needs to be OPPOSITE of the expected result, because @accepting will not be changed before an exception is raised
    msg += "New value needs to be: " + (e.object.accepting) ? (e.class).bogus_host : e.object.host
    
    send_email_with_reg("Registry write error", msg)
  end
  
  # Notification to handle all other exceptions
  # @param [Exception] e Exception
  def unspecified_error(e)
    msg = "Exception: #{e.inspect}\n#{e.message}\n\n#{e.backtrace}"
    send_email("Exception was raised", msg)
  end

  # Sends email containing a notification message
  # @param [String] subject subject line (comes after the subject prefix)
  # @param [String] body Body of notification email
  # @param [boolean] html Should send html email or not
  def send_email(subject, body, html=false)
    body.gsub!(/(\r)?\n/, "<br />") if html

    message = <<-MESSAGE_END.gsub(/^ {6}/, '')
      From: #{@@from_name} <#{@@from_addr}>
      To: #{@@to}
      Subject: #{@@subj} #{subject}
      MIME-Version: 1.0
      #{ "Content-type: text/html" if html }

      #{body}
    MESSAGE_END

    Net::SMTP.start('smtp-relay.tamu.edu') do |smtp|
      smtp.send_message message, @@from, @@to
    end
  end
  
  # Sends email containing a notification message along with a table of current registry values
  # @param [String] subject subject line (comes after the subject prefix)
  # @param [String] body Body of notification email
  def send_email_with_reg(subject, body)
    message = <<-MESSAGE.gsub(/^ {6}/, '')
      #{body}

      Current registry status:

      <span style="font-family:monospace">#{build_registry_table}</span>
    MESSAGE

    send_email(subject, message, true)
  end
  
  # Builds an ascii table of registry values for the ports defined at the beginning of the script
  # @return [String] An ascii table of registry values for a collection of ports
  def build_registry_table
    s = "SYSTEM\\CurrentControlSet\\Control\\Print\\Monitors\\Pcounter Port\\Ports:\n"
    s += (0..(s.length)).map { "=" }.join + "\n"
    PORTS.each do |port|
      begin
        t = "#{port.name}".ljust(60, '.') + port.regkey.read_key(:key =>"HostName").to_s + "\n"
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
  # Converts a CamelCase string into a camel_case string
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end
end