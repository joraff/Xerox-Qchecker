require File.join File.dirname(__FILE__), 'Exceptions.rb'

require 'win32/registry'
require 'yaml'

class Registry
  attr_reader :key_path
  
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
      raise RegistryReadError.new(nil, self)
    end
  end
  
  def write_key(args)
    begin
      Win32::Registry::HKEY_LOCAL_MACHINE.open(@key_path, Win32::Registry::KEY_ALL_ACCESS) do |reg|
        begin
          reg[args[:key]] = args[:value]
        rescue Win32::Registry::Error => e
          raise RegistryWriteError.new(nil, self)
        end
      end
    rescue Win32::Registry::Error => e
      raise RegistryReadError.new(nil, self)
    end
  end
  
  def to_s
    self.to_yaml
  end
end

