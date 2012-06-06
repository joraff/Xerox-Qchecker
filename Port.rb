require File.join File.dirname(__FILE__), 'Registry.rb'

@@bogus_host = "bogus.continuum.tamu.edu"
@@reg_prefix = "SYSTEM\\CurrentControlSet\\Control\\Print\\Monitors\\Pcounter Port\\Ports"

class Port
  def initialize(args)
    @name = args[:name]
    @host = args[:host]
    @queue = args[:queue]
    @accepting = nil
    @releasing = nil
    
    @in_error_state = false
    @unresolved_error_types = nil
    
    @regkey = Registry.new( :key_path => Registry.join( @@reg_prefix, @name ) )
  end

  def accepting=(val)
    changed = false
    
    if val == "No" and self.enabled?
      @accepting = false
      disable
      changed = true
    elsif val == "Yes" and not self.enabled?
      @accepting = true
      enable
      changed = true
    end
    
    return changed
  end
  
  def enabled?
    begin
      return registry_hostname != @host ? false : true
    rescue RegistryReadError => e
      # TODO: ErrorHandler.handle(e, self)
    else
      # TODO: ErrorHandler.clear(RegistryReadError, self)
    end
  end
  
  def to_s
    s = "#<#{self.class}:#{self.object_id}>\n"
    s += "Name => #{@name}\n"
    s += "Host => #{@host}\n"
    s += "Queue => #{@queue}\n"
    s += "Accepting? => #{@accepting}\n"
    s += "Releasing? => #{@releasing}\n"
    s += "Registry Key => #{@regkey}\n"
  end
  
  private
  
  def enable
    begin
      @regkey.write_key(:key => "hostname", :value => @host)
    rescue RegistryReadError, RegistryWriteError => e
      # TODO: handle exception
    end
  end
  
  def disable
    begin
      @regkey.write_key(:key => "hostname", :value => @@bogus_host)
    rescue RegistryReadError, RegistryWriteError => e
      # TODO: handle exception
    end
  end
  
  def registry_hostname
    @regkey.read_key(:key => "hostname")
  end
end