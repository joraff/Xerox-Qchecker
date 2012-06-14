require File.join File.dirname(__FILE__), 'Port.rb'
require File.join File.dirname(__FILE__), 'PrinterQueue.rb'
require File.join File.dirname(__FILE__), 'Notifier.rb'

def print_status(ports)
  puts ""
  puts "  #{"Host".ljust(30)}#{"Queue".ljust(15)}#{"Accepting?".ljust(15)}"
  puts (0..62).map { "=" }.join
  
  ports.each do |port|
    puts (port.recently_changed ? " *" : "  ") + "#{port.host.ljust(30)}#{port.queue.ljust(15)}#{port.enabled?}"
  end
end

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

$notification_center = Notifier.new


def check(ports)
  threads = []
  
  ports.each do |port|
    threads << Thread.new do

      begin
        queue = PrinterQueue.new( :host => port.host, :queue => port.queue)
        status = queue.accepting?
        # If status is nil, make no change to the port
        port.accepting = status if status
=begin
  TODO Add integration with the windows event log here.
=end
      rescue Exception => e
        $notification_center.notify(e)
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