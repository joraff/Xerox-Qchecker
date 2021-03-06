##
# QChecker - A program to enable/disable Pcounter ports based on a printer's document accepting status.
# 
# @author Joseph Rafferty, Texas A&M University

require File.join File.dirname(__FILE__), 'Port.rb'
require File.join File.dirname(__FILE__), 'PrinterQueue.rb'
require File.join File.dirname(__FILE__), 'Notifier.rb'


# Prints a table of queues on a host and their accepting status
# @param [Array] ports an array of Port objects
# 
def print_status(ports)
  puts ""
  puts "  #{"Host".ljust(30)}#{"Queue".ljust(15)}#{"Accepting?".ljust(15)}"
  puts (0..62).map { "=" }.join
  
  ports.each do |port|
    puts (port.recently_changed ? " *" : "  ") + "#{port.host.ljust(30)}#{port.queue.ljust(15)}#{port.enabled?}"
  end
end

# An array of port objects
# @see Port
PORTS = [
  
  # SCC-Main Queues
  Port.new( :name => "PCOUNT_SCC-SCC-cartman.continuum.tamu.edu",   :host => "cartman.continuum.tamu.edu", :queue => "scc"   ),
  Port.new( :name => "PCOUNT_SCC-SCC-kyle.continuum.tamu.edu",      :host => "kyle.continuum.tamu.edu",    :queue => "scc"   ),
  Port.new( :name => "PCOUNT_SCC-SCC-stan.continuum.tamu.edu",      :host => "stan.continuum.tamu.edu",    :queue => "scc"   ),
  Port.new( :name => "PCOUNT_SCC-SCC-timmy.continuum.tamu.edu",     :host => "timmy.continuum.tamu.edu",   :queue => "scc"   ),
                                                                                                                            
  # SCC-Large Queues                                                                                                        
  Port.new( :name => "PCOUNT_SCC-LARGE-cartman.continuum.tamu.edu", :host => "cartman.continuum.tamu.edu", :queue => "large" ),
  Port.new( :name => "PCOUNT_SCC-LARGE-kyle.continuum.tamu.edu",    :host => "kyle.continuum.tamu.edu",    :queue => "large" ),
  Port.new( :name => "PCOUNT_SCC-LARGE-stan.continuum.tamu.edu",    :host => "stan.continuum.tamu.edu",    :queue => "large" ),
  Port.new( :name => "PCOUNT_SCC-LARGE-timmy.continuum.tamu.edu",   :host => "timmy.continuum.tamu.edu",   :queue => "large" ),
  
]

# Init a Notifier class to handle our exceptions
$notification_center = Notifier.new

# Debug mode sends more notifications 
$debug = true


# Checks the accepting status of a queue and sets the port to the same
# @param [Array] ports array of Port objects
def check(ports)
  threads = []
  
  ports.each do |port|
    threads << Thread.new do

      begin
        queue = PrinterQueue.new( :host => port.host, :queue => port.queue)
        status = queue.accepting?
        # If status is nil, make no change to the port
        port.accepting = status
=begin
  TODO Add integration with the windows event log here.
=end
      rescue Exception => e
        $notification_center.raise_e(e)
      end

    end
  end
  
  threads.each { |t| t.join }
end


# MAIN LOOP #

while true do
  check(PORTS)
  sleep 60
end