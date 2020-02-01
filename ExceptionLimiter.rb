# Limits the frequency of exception/notification emails
#   Keeps an internal array of exceptions that have been previously raised per host.
class ExceptionLimiter
  
  def initialize
    @current_exceptions = []
  end
  
  # Decides if a certain exception/notification should be raised. Adds it if it should be raised.
  # @param [ExceptionWithObject] e Exception to raise
  # @return [bool] 
  def should_raise?(e)
    if contains? e
      return false
    else
      add e
      return true
    end
  end
  
  # Removes an exception from the raised list. To be called after a code block has been cleared with no exceptions
  # @param [ExceptionWithObject] e Exception to clear
  # @note ExceptionWithObject's object is expected to have a host attribute
  def clear(e)
    @current_exceptions.delete [e.object.host, e.class]
  end
  
  private
  
  # Checks if the current exception list contains the exception
  # @param [ExceptionWithObject] e Exception to check
  # @return [boolean]
  def contains?(e)
    begin
      @current_exceptions.include? [e.object.host, e.class]
    rescue NoMethodError
      return false
    end
  end
  
  
  # Adds an exception to the currently raised exceptions list
  # @param [ExceptionWithObject] e Exception to add
  def add(e)
    begin
      @current_exceptions << [e.object.host, e.class]
    rescue NoMethodError
      
    end
  end
end