require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'timeout'
require 'win32/registry'

# These are the hosts we should check queues for
HOSTS = [
  "kyle.continuum.tamu.edu",
  "stan.continuum.tamu.edu",
  "cartman.continuum.tamu.edu",
  "timmy.continuum.tamu.edu"
  ]

# These are the lpr queues on each host we should check for
QUEUES = [ "scc", "large" ]


# This is a map of information about the printer's lpr queues
#  Expected keys are:
#    "load_balance_port" => the name of the port on the print server that is configured as the load balance port
#    "print_queues" => name of the child print queues that should be in the load balance port, in the format "hostname" => "queue name"

QUEUE_INFO = {
  "scc" => {
    "load_balance_port" => "PCOUNT_TEST-SCC-SCC-LoadBalance",
    "print_queues" => {
      "cartman.continuum.tamu.edu"  => "TEST-SCC-cartman.continuum.tamu.edu",
      "kyle.continuum.tamu.edu"     => "TEST-SCC-kyle.continuum.tamu.edu",
      "stan.continuum.tamu.edu"     => "TEST-SCC-stan.continuum.tamu.edu",
      "timmy.continuum.tamu.edu"    => "TEST-SCC-timmy.continuum.tamu.edu"
    }
  },
  "large" => {
    "load_balance_port" => "PCOUNT_TEST-SCC-LARGE-LoadBalance",
    "print_queues" => {
      "cartman.continuum.tamu.edu"  => "TEST-SCC-LARGE-cartman.continuum.tamu.edu",
      "kyle.continuum.tamu.edu"     => "TEST-SCC-LARGE-kyle.continuum.tamu.edu",
      "stan.continuum.tamu.edu"     => "TEST-SCC-LARGE-stan.continuum.tamu.edu",
      "timmy.continuum.tamu.edu"    => "TEST-SCC-LARGE-timmy.continuum.tamu.edu"
    }
  }
}

# This is the order of the table elements on the printer's webpage
TABLE_FORMAT = [
  "printer",
  "queue",
  "accepts",
  "releases",
  "show_jobs_link",
  "properties_link",
  "details_link"
  ]

# Method to add or remove entries in the registry for a given load balance port
# params:
# => action: add or delete
# => host:   the host to remove - will be used to lookup the host's queue name
# => queue:  the printer lpr queue to modify the load balance port for

def mod_reg(action, host, queue)
  
  action = "push" if action == :add
  action = "delete" if action == :delete
  
  queue_info =  QUEUE_INFO[queue]
  
  raise "No Load Balance Port name defined!" unless key_name = queue_info["load_balance_port"]
  
  key_path = "SYSTEM\\CurrentControlSet\\Control\\Print\\Monitors\\Pcounter Port\\Ports\\#{key_name}"
  
  access = Win32::Registry::KEY_ALL_ACCESS
  begin
    Win32::Registry::HKEY_LOCAL_MACHINE.open(key_path, access) do |reg|
      current_printers = reg["LoadBalancePrinters"]
      raise "No child queues defined for #{queue}" unless queues = queue_info["print_queues"]
      raise "No queue name defined for host: #{host}" unless queues[host]
      current_printers.send(action, queues[host])
      current_printers.uniq!
    	reg["LoadBalancePrinters"] = current_printers
    end
  rescue Win32::Registry::Error => e
    puts "Error reading the registry key #{key_path}: #{e.message}"
  end
end

def remove_host_from_loadbalance(host, queue)
  mod_reg(:delete, host, queue)
end

def add_host_to_loadbalance(host, queue)
  mod_reg(:add, host, queue)
end


def fetch_host_html(host)
  begin
    url = "http://#{host}/isgw/ListQueues.do?method=byPrinterName"
    Timeout::timeout(5) do
      Nokogiri::HTML( open(url) )
    end
  rescue OpenURI::HTTPError => e
    puts "Looks like a URL is misconfigured! got a #{e.message} when trying to read #{url}"
    return nil
  rescue Timeout::Error => e
    puts "Timeout when trying to connect to #{host}"
    return nil
  end
end

def hashify_values_with_keys(values, keys)
  hash = {}
  keys.each_with_index do |k,i|
    hash[k] = values[i]
  end
  hash
end

HOSTS.each do |host|
  puts "Evaluating: #{host}"
  
  @doc = fetch_host_html(host)
  
  if @doc
    queue_values = @doc.xpath('//table/tr').map { |r| r.css('td[class = "QJFrameListText"]').map { |c| c.text.strip } }
    queues = {}
    
    queue_values.each do |q|
      tempq = hashify_values_with_keys(q, TABLE_FORMAT)
      queues[ tempq["queue"] ] = tempq
    end
    
    QUEUES.each do |key|
      if queues[key]
        if queues[key]["accepts"] == "Yes" && queues[key]["releases"] == "Yes"
          puts "Queue #{key} on #{host} is accepting and releasing, adding to load balance port"
          add_host_to_loadbalance(host, key)
        else
          puts "Queue #{key} on #{host} is either not accepting or not releasing, removing from load balance port"
          remove_host_from_loadbalance(host, key)
        end
      else
        puts "#{host} has no queue named #{key}! Removing from #{key} load balance port"
        remove_host_from_loadbalance(host, key)
      end
    end
  else
    # remove_all
  end
end

