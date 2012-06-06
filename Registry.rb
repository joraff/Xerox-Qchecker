require 'win32/registry'

class Registry
  @@reg_prefix = "SYSTEM\\CurrentControlSet\\Control\\Print\\Monitors\\Pcounter Port\\Ports"
  
  def self.join(*args)
    s = args.join("\\").gsub('\\\\', '\\').chomp('\\')
  end
  
  def initialize(args)
    @name = args[:name]
  end
  
  def key_path
    self.class.join(@@reg_prefix, @name)
  end
  
  # CLASS METHODS
  
  def read_key(args)
    begin      
      Win32::Registry::HKEY_LOCAL_MACHINE.open(self.key_path, Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg[args[:key]]
      end
    rescue Win32::Registry::Error => e
      raise RegistryReadError, e.message + " " + self.class.join(self.key_path, args[:key])
    end
  end
  
  def write_key(args)
    begin
      Win32::Registry::HKEY_LOCAL_MACHINE.open(self.key_path, Win32::Registry::KEY_ALL_ACCESS) do |reg|
        begin
          reg[args[:key]] = args[:value]
        rescue Win32::Registry::Error => e
          raise RegistryWriteError, e.message + " Could not set #{self.class.join(self.key_path, args[:key])} to '#{args[:value]}'."
        end
      end
    rescue Win32::Registry::Error => e
      raise RegistryReadError, e.message + " " + self.class.join(self.key_path, args[:key])
    end
  end
  
end

class RegistryReadError < Exception; end

class RegistryWriteError < Exception; end
