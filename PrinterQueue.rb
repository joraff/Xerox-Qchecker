require 'nokogiri'
require 'open-uri'
require 'timeout'
require File.join File.dirname(__FILE__), 'Exceptions.rb'

# Class representing a queue on a 4112 printer
class PrinterQueue
  attr_reader :host, :queue
  
  # Format or order of the columns expected in the HTML table for a printer
  @@table_format = [
    :printer,
    :queue,
    :accepts,
    :releases,
    :show_jobs_link,
    :properties_link,
    :details_link
  ]
  
  # Initialized a new PrinterQueue object.
  # @param [Hash] args Arguments to init the object with
  # @option args [String] :host The hostname of the printer this queue is on
  # @option opts [String] :queue The name of the queue on the printer
  def initialize(args)
    @host = args[:host]
    @queue = args[:queue]
  end
  
  # Queries the printer for and returns the current accepting status of the queue. 
  # @return [boolean] accepting status
  def accepting?
    query_host
    @accepting
  end
  
  # Queries the printer for and returns the current releasing status of the queue. 
  # @return [boolean] releasing status
  def releasing?
    query_host
    @releasing
  end
  
  private
  
  # Convenience method that fetches the HTML from the printer server and parses the response
  def query_host
    return unless fetch_host_html
    parse_response
  end
  
  # Fetches the response for a particular URL that contains information about the queue
  def fetch_host_html
    begin
      url = "http://#{@host}/isgw/ListQueues.do?method=byPrinterName"
      Timeout::timeout(5) do
        @html = Nokogiri::HTML( open(url) )
      end
    rescue OpenURI::HTTPError => e
      code = e.io.status[0]
      raise HttpError.new(code, self)
    rescue Timeout::Error, SocketError, Exception => e
      raise ConnectionTimeout.new(nil, self)
    end
    
    $notification_center.clear(HttpError.new(nil, self))
    $notification_center.clear(ConnectionTimeout.new(nil, self))
    
    return true
  end
  
  # Parses an HTML encoded response containing information about the queue using a particular XPath
  def parse_response
    if @html
      
      # xpath('//table/tr') => gets all the <tr> elements that are a child of a <table>
      # 1st .map { } => iterates over the above <tr>'s
      # css('td[class = "QJFrameListText"]') => further matches only the <td class="QJFrameListText"> elements within each <tr>
      # 2nd .map { } => Extracts the inner text of the <td> and strips any border whitespace.
      
      table_array = @html.xpath('//table/tr').map { |r| r.css('td[class = "QJFrameListText"]').map { |c| c.text.strip } }
      
      raise StructureNotFound.new(nil, self) unless table_array.count > 0
      
      queues = {}
      
      table_array.each do |q|
        tempq = hashify_values_with_keys(q, @@table_format)
        queues[ tempq[:queue] ] = tempq
      end
      
      
      begin
        if queues.has_key? @queue
          queue_hash = queues[@queue]
        else
          raise QueueNotFound.new(nil, self)
        end
      # If a queue is not found on the printer, then it WILL NOT ACCEPT JOBS
      # Disable the printer, still also raise an exception 'cause this is kind of a big deal
      rescue QueueNotFound => e
        @accepting = false
        raise
      end
      
      status = ( queue_hash.has_key? :accepts ) ? queue_hash[:accepts] : ''
      
      begin
        if [ "Yes", "No" ].include? status
          @accepting = ( status == "Yes" ) ? true : false
        else
          raise UnknownStatusValue.new(status, self) # TODO: message here
        end
      # If the queue's status is not Yes or No, then we don't know what that really means!
      # Disable the printer, still also raise an exception 'cause this is kind of a big deal
      rescue UnknownStatusValue => e 
        @accepting = false
      end
    
    else
      raise EmptyResponse.new(nil, self)
    end
    
    $notification_center.clear StructureNotFound.new(nil, self)
    $notification_center.clear QueueNotFound.new(nil, self)
    $notification_center.clear UnknownStatusValue.new(nil, self)
    $notification_center.clear EmptyResponse.new(nil, self)
  end
  
  def hashify_values_with_keys(values, keys)
    hash = {}
    keys.each_with_index do |k,i|
      hash[k] = values[i]
    end
    hash
  end
  
end