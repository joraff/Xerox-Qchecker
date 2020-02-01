require File.join File.dirname(__FILE__), 'Registry.rb'
require File.join File.dirname(__FILE__), 'Exceptions.rb'

require 'yaml'

@@bogus_host = "bogus.continuum.tamu.edu"
@@reg_prefix = "SYSTEM\\CurrentControlSet\\Control\\Print\\Monitors\\Pcounter Port\\Ports"

# Class representing a Pcounter port for a printer
class Port
  
  # @return [String] Name of the port
  attr_reader :name
  
  # @return [String] Real, resolvable hostname of the printer this port corresponds to
  attr_reader :host
  
  # @return [String] Queue on a printer this port corresponds to
  attr_reader :queue
  
  # @return [String] Flag indicating a recent change in accepting or releasing status
  attr_reader :recently_changed
  
  # @return [String] Registry key for this port
  attr_reader :regkey
  
  # @return [String] Flag indicating the current accepting status. May be nil after initialization
  attr_reader :accepting
  
  # @param [Hash] args
  # @option args [String] :name 
  # @option args [String] :host
  # @option args [String] :queue
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

  # Sets the status of the pcounter port
  # @param [bool] Status that the port should be set to
  # @return [bool] Flag indicating whether or not the port's status value changed
  def accepting=(val)
    @recently_changed = false
    
    if val and disabled?
      @accepting = true
      enable
      $notification_center.notify("Port #{name} has been enabled.") if $debug
      @recently_changed = true
    elsif (not val) and enabled?
      @accepting = false
      disable
      $notification_center.notify("Port #{name} has been disabled.") if $debug
      @recently_changed = true
    end
    
    return @recently_changed
  end
  
  
  # Returns whether or not the port is enabled
  # @return [bool] Returns whether or not the port is enabled
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
  
  
  # Returns whether or not the port is disabled
  # @return [bool] Returns whether or not the port is disabled
  def disabled?
    !enabled?
  end
  
  
  # @return [String] a yaml representation of the current object
  def to_s
    self.to_yaml
  end
  
  # @return [string] the bogus hostname used to disable a port
  def self.bogus_host
    @@bogus_host
  end
  
  private
  
  # Enables a port
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
  
  # Disables a port
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
  
  # @return [String] the current hostname in the registry for the port
  def registry_hostname
    @regkey.read_key(:key => "hostname")
  end
end