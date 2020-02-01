# Custom exception class with an "object" attribute
class ExceptionWithObject < StandardError
  attr_accessor :object
  
  def initialize(message = nil, object = nil)
    super(message)
    self.object = object
  end
end

# List of custom exceptions that can be raised in QChecker

# Exception to be raised if the HTML structure returned by a printer's web server is not recognized.
class StructureNotFound < ExceptionWithObject; end

# Exception to be raised if a certain queue was not listed by a printer
class QueueNotFound < ExceptionWithObject; end

# Exception to be raised if the printer web server returned an empty respone
class EmptyResponse < ExceptionWithObject; end

# Exception to be raised if there was a connection error when attempting to connect to a printer web server
class FetchError < ExceptionWithObject; end

# Exception to be raised if an HTTP status code was 4xx or 5xx when trying to read the web server url
class HttpError < ExceptionWithObject; end

# Exception to be raised if the connection to the printer web server timed out
class ConnectionTimeout < ExceptionWithObject; end

# Exception to be raised if the "Accepting" status for a port is not understood (yes or no)
class UnknownStatusValue < ExceptionWithObject; end

# Exception to be raised if there was an error raised when trying to read the windows registry
class RegistryReadError < ExceptionWithObject; end

# Exception to be raised if there was an error raised when trying to write to the windows registry
class RegistryWriteError < ExceptionWithObject; end


