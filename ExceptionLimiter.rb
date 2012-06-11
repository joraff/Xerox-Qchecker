class ExceptionLimiter
  
  def initialize
    @current_exceptions = []
  end
  
  def should_raise?(e)
    if contains? e
      return false
    else
      add e
      return true
    end
  end
  
  def clear(e)
    @current_exceptions.delete [e.object.host, e.class]
  end
  
  private
  
  def contains?(e)
    @current_exceptions.include? [e.object.host, e.class]
  end
  
  def add(e)
    @current_exceptions << [e.object.host, e.class]
  end
end