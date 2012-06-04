#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

HOSTS = [
  "kyle.continuum.tamu.edu",
  "stan.continuum.tamu.edu",
  "cartman.continuum.tamu.edu",
  "timmy.continuum.tamu.edu"
  ]

# This is the order of the table elements on the printer's webpage
TABLE_FORMAT = [
  "printer",
  "queue",
  "accepts",
  "releases",
  "show_jobs_link",
  "properties_link",
  "details_link"
  ]
  
  
def fetch_host_html(host)
  url = "http://#{host}/isgw/ListQueues.do?method=byPrinterName"
  Nokogiri::HTML( open(url) )
end

def hashify_values_with_keys(values, keys)
  hash = {}
  keys.each_with_index do |k,i|
    hash[k] = values[i]
  end
  hash
end


@doc = fetch_host_html("kyle.continuum.tamu.edu")


queue_values = @doc.xpath('//table/tr').map { |r| r.css('td[class = "QJFrameListText"]').map { |c| c.text.strip } }
queues = {}

queue_values.each do |q|
  tempq = hashify_values_with_keys(q, TABLE_FORMAT)
  queues[ tempq["queue"] ] = tempq
end

puts queues


