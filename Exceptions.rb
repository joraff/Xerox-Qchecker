# For class PrinterQueue

class ExceptionWithObject < StandardError
  attr_accessor :object
  
  def initialize(message = nil, object = nil)
    super(message)
    self.object = object
  end
end


class StructureNotFound < ExceptionWithObject; end

class QueueNotFound < ExceptionWithObject; end

class EmptyResponse < ExceptionWithObject; end

class FetchError < ExceptionWithObject; end

class HttpError < ExceptionWithObject; end

class ConnectionTimeout < ExceptionWithObject; end

class UnknownStatusValue < ExceptionWithObject; end

class RegistryReadError < ExceptionWithObject; end

class RegistryWriteError < ExceptionWithObject; end

class MaintenanceMode < ExceptionWithObject; end

