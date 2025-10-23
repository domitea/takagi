#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating the unified Takagi::Client API with multiple protocols
#
# This example shows the new unified API that supports:
# 1. Protocol auto-detection from URI scheme
# 2. Explicit protocol specification
# 3. Block-based auto-close pattern (recommended)
# 4. Manual lifecycle management

require_relative '../lib/takagi'

puts "Demonstrating Unified Takagi::Client API\n\n"

# Pattern 1: Protocol auto-detection from URI
puts "Pattern 1: Protocol Auto-Detection from URI"
puts "=" * 50

# UDP client (coap:// scheme)
puts "Creating UDP client from coap:// URI:"
client_udp = Takagi::Client.new('coap://localhost:5683')
puts "  Protocol: UDP (auto-detected)"
puts "  Implementation: #{client_udp.instance_variable_get(:@impl).class}"
client_udp.close

# TCP client (coap+tcp:// scheme)
puts "\nCreating TCP client from coap+tcp:// URI:"
client_tcp = Takagi::Client.new('coap+tcp://localhost:5683')
puts "  Protocol: TCP (auto-detected)"
puts "  Implementation: #{client_tcp.instance_variable_get(:@impl).class}"
client_tcp.close
puts

# Pattern 2: Explicit protocol specification
puts "Pattern 2: Explicit Protocol Specification"
puts "=" * 50

# Explicitly specify TCP
puts "Creating TCP client with protocol parameter:"
client = Takagi::Client.new('localhost:5683', protocol: :tcp)
puts "  Protocol: TCP (explicit)"
puts "  Implementation: #{client.instance_variable_get(:@impl).class}"
client.close

# Explicitly specify UDP
puts "\nCreating UDP client with protocol parameter:"
client = Takagi::Client.new('localhost:5683', protocol: :udp)
puts "  Protocol: UDP (explicit)"
puts "  Implementation: #{client.instance_variable_get(:@impl).class}"
client.close
puts

# Pattern 3: Block-based auto-close (RECOMMENDED)
puts "Pattern 3: Block-Based Auto-Close (RECOMMENDED)"
puts "=" * 50
initial_threads = Thread.list.size
puts "Initial thread count: #{initial_threads}"

Takagi::Client.new('coap://localhost:5683') do |client|
  puts "Inside block. Thread count: #{Thread.list.size}"
  puts "Client protocol: UDP"
  # Use the client...
  # client.get('/resource')
end # Client automatically closed here

sleep 0.2 # Give thread time to stop
puts "After block. Thread count: #{Thread.list.size}"
puts

# Pattern 4: Multiple protocols with thread leak prevention
puts "Pattern 4: Multiple Protocols - Thread Leak Test"
puts "=" * 50
initial_threads = Thread.list.size
puts "Initial thread count: #{initial_threads}"

# Create and close multiple clients with different protocols
3.times do |i|
  Takagi::Client.new('coap://localhost:5683') do |_client|
    # UDP client work...
  end
  puts "  UDP Client #{i + 1} closed"
end

2.times do |i|
  Takagi::Client.new('localhost:5683', protocol: :tcp) do |_client|
    # TCP client work...
  end
  puts "  TCP Client #{i + 1} closed"
end

sleep 0.5 # Give threads time to stop
final_threads = Thread.list.size
puts "Final thread count: #{final_threads}"
puts "Thread leak prevented: #{final_threads <= initial_threads + 1 ? 'YES ✓' : 'NO ✗'}"
puts

# Pattern 5: Error handling with auto-close
puts "Pattern 5: Auto-Close Even With Errors"
puts "=" * 50
begin
  Takagi::Client.new('coap://localhost:5683') do |client|
    puts "Inside block. Client open: #{!client.closed?}"
    raise 'Simulated error'
  end
rescue StandardError => e
  puts "Caught error: #{e.message}"
  puts "Client was still closed despite error"
end
puts

puts "\nSummary of New Unified API:"
puts "- Single Takagi::Client class for all protocols"
puts "- Auto-detects protocol from URI scheme (coap:// = UDP, coap+tcp:// = TCP)"
puts "- Explicit protocol selection with protocol: parameter"
puts "- Block-based initialization for automatic cleanup"
puts "- Consistent API across UDP and TCP transports"
puts "- Thread-safe with proper resource cleanup"
