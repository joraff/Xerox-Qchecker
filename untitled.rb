require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'timeout'
require 'win32/registry'
require 'win32/eventlog'
require 'net/smtp'

require 'Notifier.rb'

# These are the hosts we should check queues for

HOSTS = [
  "cartman.continuum.tamu.edu",
  "kyle.continuum.tamu.edu",
  "stan.continuum.tamu.edu",
  "timmy.continuum.tamu.edu"
  ]

# Fake host to point the port to

BOGUS_HOST = "bogus.continuum.tamu.edu"

# These are the lpr queues on each host we should check for

QUEUES = [ "scc", "large" ]


# This is a map of information about the server's child printer ports
#  Key names should be the same as the values from the QUEUE array above,
#  and the values should be an array of key => value pairs of "hostname" => "port_name"

PORTS = {
  "scc" => {
    "cartman.continuum.tamu.edu"  => "PCOUNT_SCC-SCC-cartman.continuum.tamu.edu",
    "kyle.continuum.tamu.edu"     => "PCOUNT_SCC-SCC-kyle.continuum.tamu.edu",
    "stan.continuum.tamu.edu"     => "PCOUNT_SCC-SCC-stan.continuum.tamu.edu",
    "timmy.continuum.tamu.edu"    => "PCOUNT_SCC-SCC-timmy.continuum.tamu.edu"
  },
  "large" => {
    "cartman.continuum.tamu.edu"  => "PCOUNT_SCC-LARGE-cartman.continuum.tamu.edu",
    "kyle.continuum.tamu.edu"     => "PCOUNT_SCC-LARGE-kyle.continuum.tamu.edu",
    "stan.continuum.tamu.edu"     => "PCOUNT_SCC-LARGE-stan.continuum.tamu.edu",
    "timmy.continuum.tamu.edu"    => "PCOUNT_SCC-LARGE-timmy.continuum.tamu.edu"
  }
}


# This is the order of the table elements on the printer's webpage
# Should not have to change unless a printer firmware update changes the html layout

TABLE_FORMAT = [
  "printer",
  "queue",
  "accepts",
  "releases",
  "show_jobs_link",
  "properties_link",
  "details_link"
]
  
  
# Path in the registry where the pcounter ports live
  
KEY_PREFIX = "SYSTEM\\CurrentControlSet\\Control\\Print\\Monitors\\Pcounter Port\\Ports"


@logger = Win32::EventLog.new

class TableNotFound < Exception
end

class QueueNotFound < Exception
end

class EmptyResponse < Exception
end

class FetchError < Exception
end


# Method to add or remove entries in the registry for a given load balance port
# params:
# => action: on or off
# => host:   the host to remove - will be used to lookup the host's queue name
# => queue:  the printer lpr queue to modify the load balance port for

def get_key_path(host, queue)
  begin
    key_name = PORTS[queue][host]
  rescue Exception => e
    puts "Something wrong with your hash, yo. #{e}"
    raise e
  end
  KEY_PREFIX + "\\#{key_name}"
end

def mod_reg(action, host, queue)
  begin
    change = false
    key_path = get_key_path(host, queue)
    access = Win32::Registry::KEY_ALL_ACCESS
    
    Win32::Registry::HKEY_LOCAL_MACHINE.open(key_path, access) do |reg|
      current_hostname = reg["HostName"]
      begin
        if current_hostname == BOGUS_HOST && action == :on
          reg["HostName"] = host
          @logger.report_event(:source => "Xerox Queue Accept Checker", :event_id => 2, :event_type => Win32::EventLog::INFO, :data => "Enabling pcounter port for host: #{host}")
          change = true
        elsif current_hostname == host && action == :off
          reg["HostName"] = BOGUS_HOST
          @logger.report_event(:source => "Xerox Queue Accept Checker", :event_id => 1, :event_type => Win32::EventLog::INFO, :data => "Disabling pcounter port for host: #{host}")
          change = true
        end
      rescue Win32::Registry::Error => e
        puts "Error writing to the registry key: #{key_path}"
        Notifier.registry_write_error
      end
    end
  rescue Win32::Registry::Error => e
    puts "Error reading the registry key #{key_path}: #{e.message}"
    send_email_to_lss "Error read the registry", "An access error was raised when trying to read #{key_path}"
  rescue Exception => e
    puts "Generic error #{e}"
  end
  return change
end

def disable_host_for_queue(host, queue)
  mod_reg(:off, host, queue)
end

def enable_host_for_queue(host, queue)
  mod_reg(:on, host, queue)
end

def get_status_of_host_for_queue(host, queue)
  key_path = get_key_path(host, queue)
  access = Win32::Registry::KEY_ALL_ACCESS
  begin
    Win32::Registry::HKEY_LOCAL_MACHINE.open(key_path, access) do |reg|
      reg["HostName"]
    end
  rescue Win32::Registry::Error => e
    puts "Error reading the registry key #{key_path}: #{e.message}"
    send_email_to_lss "Error read the registry", "An access error was raised when trying to read #{key_path}"
  end
end

def fetch_host_html(host)
  begin
    url = "http://#{host}/isgw/ListQueues.do?method=byPrinterName"
    Timeout::timeout(5) do
      Nokogiri::HTML( open(url) )
    end
  rescue OpenURI::HTTPError => e
    puts "Looks like a URL is misconfigured! got a #{e.message} when trying to read #{url}"
    send_email_to_lss "HTTP Error code #{e.io.status[0]} on #{host}", "Got a #{e.message} when trying to read #{url} on host #{host}."
    raise FetchError
  rescue Timeout::Error => e
    puts "Timeout when trying to connect to #{host}"
    send_email_to_lss "Timeout on #{host}", "A timeout was reached when trying to connect to #{host} to obtain a queue list."
    raise FetchError
  end
end

def hashify_values_with_keys(values, keys)
  hash = {}
  keys.each_with_index do |k,i|
    hash[k] = values[i]
  end
  hash
end

def nl2br(s)
  s.gsub(/(\r)?\n/, "<br />")
end

def send_email_to_lss(subject, body, html=false)
  body = nl2br(body)
  
  message = <<-MESSAGE_END.gsub(/^ {2}/, '')
  From: Xerox 4112 Queue Checker (SCC) <lan@tamu.edu>
  To: jrafferty@tamu.edu
  Subject: #{subject}
  MIME-Version: 1.0
  #{ "Content-type: text/html" if html }
  
  #{body}
  MESSAGE_END
  
  Net::SMTP.start('smtp-relay.tamu.edu') do |smtp|
    smtp.send_message message, 'Xerox 4112 Queue Checker (SCC) <lan@tamu.edu>', 
                               'jrafferty@tamu.edu'
  end
end

def send_email_to_lss_with_reg(subject, body)
  message = <<-MESSAGE.gsub('            ', '')
    #{body}
    
    Current registry status:
    
    <span style="font-family:monospace">#{build_table_of_registry_values}</span>
  MESSAGE
  
  send_email_to_lss(subject, message, true)
end


def build_table_of_registry_values
  s = "In SYSTEM\\CurrentControlSet\\Control\\Print\\Monitors\\Pcounter Port\\Ports:\n"
  s += (0..(s.length)).map { "=" }.join + "\n"
  HOSTS.each do |host|
    QUEUES.each do |queue|
      begin
        t = (get_key_path(host, queue).gsub(KEY_PREFIX, '') + ": ").ljust(60, '.') + get_status_of_host_for_queue(host, queue) + "\n"
        t += (0..(t.length)).map { "-" }.join + "\n"
        s += t
      rescue Exception => e
        s += "#{host}\\#{queue}: Error - #{e}" + "\n"
      end
    end
  end
  s
end
    

puts ""
puts "  #{"Host".ljust(30)}#{"Queue".ljust(15)}#{"Accepting?".ljust(15)}#{"Releasing?".ljust(15)}"
puts (0..75).map { "=" }.join

HOSTS.each do |host|
  begin
    @doc = fetch_host_html(host)
  
    if @doc
      queue_values = @doc.xpath('//table/tr').map { |r| r.css('td[class = "QJFrameListText"]').map { |c| c.text.strip } }
    
      raise TableNotFound unless queue_values.count > 0
    
      queues = {}
    
      queue_values.each do |q|
        tempq = hashify_values_with_keys(q, TABLE_FORMAT)
        queues[ tempq["queue"] ] = tempq
      end
    
      QUEUES.each do |key|
        begin
          if queues[key]
            if queues[key]["accepts"] == "Yes" && queues[key]["releases"] == "Yes"
              result = enable_host_for_queue(host, key)
            else
              result = disable_host_for_queue(host, key)
            end
          else
            raise QueueNotFound, key
          end
          puts ( (result ? "* " : "  ") + host ).ljust(30) + key.ljust(15) + queues[key]["accepts"].ljust(15) + queues[key]["releases"].ljust(15)
        rescue QueueNotFound => e
          puts "#{host}\\#{e.message}: #{e.class}"
          message = "Parsed the HTML response, but did not find the queue named #{e.message}."

          send_email_to_lss_with_reg "Parse error on #{host}", message
        end
      end
    end
    
  rescue FetchError
  rescue TableNotFound => e
    puts "#{host}: #{e.class}"
    send_email_to_lss_with_reg "Parse error on #{host}", "Parsed the HTML response, but didn't find the table structure we were expecting.\nHTML:\n\n#{@doc}"
  end
  
  puts (0..75).map { "-" }.join
end

puts ""
puts "* = Indicates that a queue status changed"
