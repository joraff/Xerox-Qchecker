require 'win32/registry'

class Registry
  
  # CLASS METHODS
  
  def self.join(*args)
    s = args.join("\\").gsub('\\\\', '\\').chomp('\\')
  end
  
  # INSTANCE METHODS
  
  def initialize(args)
    @key_path = args[:key_path]
  end
  
  def read_key(args)
    begin      
      Win32::Registry::HKEY_LOCAL_MACHINE.open(@key_path, Win32::Registry::KEY_ALL_ACCESS) do |reg|
        reg[args[:key]]
      end
    rescue Win32::Registry::Error => e
      raise RegistryReadError, e.message + " " + self.class.join(@key_path, args[:key])
    end
  end
  
  def write_key(args)
    begin
      Win32::Registry::HKEY_LOCAL_MACHINE.open(@key_path, Win32::Registry::KEY_ALL_ACCESS) do |reg|
        begin
          reg[args[:key]] = args[:value]
        rescue Win32::Registry::Error => e
          raise RegistryWriteError, e.message + " Could not set #{self.class.join(@key_path, args[:key])} to '#{args[:value]}'."
        end
      end
    rescue Win32::Registry::Error => e
      raise RegistryReadError, e.message + " " + self.class.join(@key_path, args[:key])
    end
  end
  
  def to_s
    s = "#<#{self.class}:#{self.object_id}>\n"
    s += "Key path => #{@key_path}\n"
  end
end

class RegistryReadError < Exception; end

class RegistryWriteError < Exception; end
