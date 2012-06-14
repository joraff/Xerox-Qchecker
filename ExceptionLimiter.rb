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
    begin
      @current_exceptions.include? [e.object.host, e.class]
    rescue NoMethodError
      return false
    end
  end
  
  def add(e)
    begin
      @current_exceptions << [e.object.host, e.class]
    rescue NoMethodError
      
    end
  end
end