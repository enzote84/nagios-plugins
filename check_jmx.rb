#!/bin/env jruby

### Requirements:
# yum install java -y
# wget https://repo1.maven.org/maven2/org/jruby/jruby-dist/9.1.17.0/jruby-dist-9.1.17.0-bin.tar.gz
# tar xvfz jruby-dist-9.1.17.0-bin.tar.gz -C /opt/
# echo PATH=\$PATH:/opt/jruby-9.1.17.0/bin > /etc/profile.d/jruby.sh
# echo export JRUBY_HOME=/opt/jruby-9.1.17.0 >> /etc/profile.d/jruby.sh
# chmod +x /etc/profile.d/jruby.sh
# rm -f jruby-dist-9.1.17.0-bin.tar.gz
# . /etc/profile.d/jruby.sh
# jruby -S gem install jmx4r
### Some useful documentation: https://github.com/jruby/jruby/wiki/AccessingJMX

# Libraries:
require 'jmx4r'
require 'optparse'
require 'date'

# General variables:
APP_VER = 1
APP_AUTHOR = "BBR SpA"
@options = {
  :host => nil,
  :broker => nil,
  :port => nil,
  :time_warn => 300,
  :time_crit => 600,
  :queue_size_warn => 500,
  :queue_size_crit => 1000,
  :verbose_mode => false
}
@nagios = {
  :ok => 0,
  :warning => 1,
  :critical => 2,
  :unknown => 3
}
performance_metrics = []
exit_codes = [0]
exit_messages = []

# getOptions function: parse command line options
def getOptions

  OptionParser.new do |o|
    o.banner =  "Usage: #{$PROGRAM_NAME} <options>"
    o.on('-H,--host [HOST_NAME]', 'Broker hostname') { |h|
      @options[:host] = h
    }
    o.on('-P,--port [JMX_PORT]', 'JMX Port') { |p|
      @options[:port] = p
    }
    o.on('-B,--broker [BROKER_NAME]', 'Broker\'s name') { |n|
      @options[:broker] = n
    }
    o.on('--time-warn [SECONDS]', 'Time in seconds for a warning level alert (default: 300)') { |t|
      @options[:time_warn] = t.to_i
    }
    o.on('--time-crit [SECONDS]', 'Time in seconds for a critical level alert (default: 600)') { |t|
      @options[:time_crit] = t.to_i
    }
    o.on('--queue-size-warn [SIZE]', 'Queue size for a warning level alert (default: 500)') { |s|
      @options[:queue_size_warn] = s.to_i
    }
    o.on('--queue-size-crit [SIZE]', 'Queue size for a critical level alert (default: 1000)') { |s|
      @options[:queue_size_crit] = s.to_i
    }
    o.on('--verbose-mode', 'Activate verbose mode (default: disabled)') { |v|
      @options[:verbose_mode] = true
    }
    o.on('-v','--version') {
      puts "Version: #{APP_VER}"
      puts "Author: #{APP_AUTHOR}"
      exit @nagios[:ok]
    }
    o.on('-h','--help') {
      puts o
      exit @nagios[:ok]
    }
    o.parse!

    if @options[:host].nil? or @options[:broker].nil? or @options[:port].nil?
      puts "Error: Insuficient arguments"
      puts o
      exit @nagios[:unknown]
    end
  end
end

# printVerbose function for debuging
def printVerbose (text)
  if @options[:verbose_mode]
    puts "DEBUG: #{text}"
  end
end

#
# Main program
#

# Parse parameters:
getOptions

# Connect to JMX server:
begin
  JMX::MBean.establish_connection :host => @options[:host], :port => @options[:port]
  printVerbose "Connection established to #{@options[:host]}:#{@options[:port]}"
rescue
  puts "Error trying to establish connection to #{@options[:host]}:#{@options[:port]}"
  exit @nagios[:unknown]
end

# Find broker:
begin
  mbean  = "org.apache.activemq:type=Broker,brokerName=#{@options[:broker]}"
  broker = JMX::MBean.find_by_name mbean
  printVerbose "Broker #{@options[:broker]} found"
rescue
  puts "Error trying to get broker #{@options[:broker]} from connection"
  exit @nagios[:unknown]
end

# Check if it is slave:
begin
  if broker.slave
    puts "OK - This ActiveMQ Server is in SLAVE mode"
    exit @nagios[:ok]
  end
rescue
  puts "Error trying to get broker #{@options[:broker]} slave status"
  exit @nagios[:unknown]
end

# Get broker metrics:
begin
  memory_percent_usage = broker.memory_percent_usage
  store_percent_usage = broker.store_percent_usage
  temp_percent_usage = broker.temp_percent_usage
  total_message_count = broker.total_message_count
  performance_metrics.push("memory_percent_usage=#{memory_percent_usage}%")
  performance_metrics.push("store_percent_usage=#{store_percent_usage}%")
  performance_metrics.push("temp_percent_usage=#{temp_percent_usage}%")
  performance_metrics.push("total_message_count=#{total_message_count}")
  printVerbose "memory_percent_usage: #{memory_percent_usage}"
  printVerbose "store_percent_usage: #{store_percent_usage}"
  printVerbose "temp_percent_usage: #{temp_percent_usage}"
  printVerbose "total_message_count: #{total_message_count}"
rescue
  puts "Error trying to get broker metrics"
  exit @nagios[:unknown]
end

# Get broker queues:
begin
  queues = broker.queues.to_a.map { |queue|
    queue.to_s.split(',').last.split('=').last
  }
  printVerbose "Queues: #{queues}"
rescue
  puts "Error trying to get broker queues"
  exit @nagios[:unknown]
end

# Get date time from connection:
#current_timestamp = Time.now.to_i # This does not work for servers in a different time zone
#p "Current timestamp: #{current_timestamp}"
begin
  mbean_timestamp  = "com.sun.management:type=DiagnosticCommand"
  broker_timestamp = JMX::MBean.find_by_name mbean_timestamp
  system_properties = broker_timestamp.vm_system_properties
  current_timestamp = system_properties[1, system_properties.index("\n") - 1]
  printVerbose "Broker date time: #{current_timestamp}"
  current_timestamp = DateTime.parse(current_timestamp).strftime('%s').to_i
  printVerbose "Broker timestamp: #{current_timestamp}"
rescue
  puts "Error trying to get date time from connection"
  exit @nagios[:unknown]
end

# Iterate over queues to get metrics:
queues.each { |queue|
  begin
    mbean_queue  = "org.apache.activemq:type=Broker,brokerName=#{@options[:broker]},destinationType=Queue,destinationName=#{queue}"
    broker_queue = JMX::MBean.find_by_name mbean_queue
    # Queue size:
    queue_size = broker_queue.queue_size
    printVerbose "#{queue} queue size: #{queue_size}"
    if queue_size >= @options[:queue_size_crit]
      exit_codes.push(@nagios[:critical])
      exit_messages.push("#{queue} queue_size is #{queue_size}")
    elsif queue_size >= @options[:queue_size_warn]
      exit_codes.push(@nagios[:warning])
      exit_messages.push("#{queue} queue_size is #{queue_size}")
    end
    performance_metrics.push("#{queue}_queue_size=#{queue_size};#{@options[:queue_size_warn]};#{@options[:queue_size_crit]}")
  rescue
    puts "Error trying to get queue metrics from #{queue}"
    exit @nagios[:unknown]
  end
  # Queue message enqueued time:
  enqueued_time = 0
  if queue_size != 0
    begin
      messages = broker_queue.browse
      msg = messages.first
      printVerbose "#{queue} messages quantity: #{messages.length}"
      msg_timestamp = DateTime.parse(msg['JMSTimestamp'].to_s).strftime('%s').to_i
      printVerbose "#{queue} msg timestamp: #{msg_timestamp}"
      enqueued_time = current_timestamp - msg_timestamp
      if enqueued_time >= @options[:time_crit]
        exit_codes.push(@nagios[:critical])
        exit_messages.push("#{queue} enqueued_time #{enqueued_time} seconds")
      elsif enqueued_time >= @options[:time_warn]
        exit_codes.push(@nagios[:warning])
        exit_messages.push("#{queue} enqueued_time #{enqueued_time} seconds")
      end
    rescue => exception
      puts "Error trying to get message timestamp from #{queue}"
      printVerbose exception.backtrace
      exit @nagios[:unknown]
    end
  end
  performance_metrics.push("#{queue}_message_enqueued_time=#{enqueued_time}s;#{@options[:time_warn]};#{@options[:time_crit]}")
}

# Report results:
if exit_codes.max == @nagios[:critical]
  exit_messages.unshift("CRITICAL")
elsif exit_codes.max == @nagios[:warning]
  exit_messages.unshift("WARNING")
else
  exit_messages.unshift("OK, All queues are ok")
end
puts "#{exit_messages.join(', ')}|#{performance_metrics.join(' ')}"

# Disconnect from JMX server:
begin
  JMX::MBean.remove_connection
rescue
  puts "Error disconnecting from #{@options[:host]}:#{@options[:port]}"
  exit @nagios[:unknown]
end

# Return exit status
exit exit_codes.max
