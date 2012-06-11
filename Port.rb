require File.join File.dirname(__FILE__), 'Registry.rb'
require File.join File.dirname(__FILE__), 'Exceptions.rb'

require 'yaml'

@@bogus_host = "bogus.continuum.tamu.edu"
@@reg_prefix = "SYSTEM\\CurrentControlSet\\Control\\Print\\Monitors\\Pcounter Port\\Ports"

class Port
  
  attr_reader :host, :queue, :recently_changed, :regkey, :accepting
  
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
    @recently_changed = false
    
    
    if val and self.disabled?
      @accepting = true
      enable
      @recently_changed = true
    elsif not val and self.enabled?
      @accepting = false
      disable
      @recently_changed = true
    end
    
    return @recently_changed
  end
  
  def enabled?
    begin
      return registry_hostname != @host ? false : true
    rescue RegistryReadError => e
      e.object = self
      raise
    else
      $notification_center.clear RegistryReadError.new(nil, self)
    end
  end
  
  def disabled?
    !enabled?
  end
  
  def to_s
    self.to_yaml
  end
  
  def self.bogus_host
    @@bogus_host
  end
  
  private
  
  def enable
    begin
      @regkey.write_key(:key => "hostname", :value => @host)
    rescue RegistryReadError, RegistryWriteError => e
      e.object = self
      raise
    else
      $notification_center.clear RegistryReadError.new(nil, self)
      $notification_center.clear RegistryWriteError.new(nil, self)
    end
  end
  
  def disable
    begin
      @regkey.write_key(:key => "hostname", :value => @@bogus_host)
    rescue RegistryReadError, RegistryWriteError => e
      e.object = self
      raise
    else
      $notification_center.clear RegistryReadError.new(nil, self)
      $notification_center.clear RegistryWriteError.new(nil, self)
    end
  end
  
  def registry_hostname
    @regkey.read_key(:key => "hostname")
  end
end