#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Simple Device Application (IoT Device Pattern)
#
# This example demonstrates the simple pattern using Takagi::Base
# for constrained IoT devices with minimal resources.
#
# Use case: Raspberry Pi, ESP32, or edge device with 1-10 endpoints
#
# Run with: ruby examples/simple_device_app.rb

require_relative '../lib/takagi'

# Simple device application using global router pattern
class DeviceApp < Takagi::Base
  # GET /sensor - Read sensor data
  get '/sensor' do
    {
      temperature: 25.5,
      humidity: 60,
      timestamp: Time.now.to_i
    }
  end

  # POST /command - Execute device command
  post '/command' do |request|
    command = request.data

    case command['action']
    when 'reboot'
      { status: 'rebooting' }
    when 'update'
      { status: 'updating' }
    else
      { status: 'unknown_command' }
    end
  end

  # OBSERVE /status - Stream device status (CoAP Observe)
  observable '/status' do
    {
      online: true,
      uptime: Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i,
      memory_used: `ps -o rss= -p #{Process.pid}`.to_i
    }
  end

  # GET /config - Device configuration
  get '/config' do
    {
      device_id: 'device-001',
      firmware_version: '1.0.0',
      update_interval: 60
    }
  end
end

if __FILE__ == $PROGRAM_NAME
  puts "Starting Simple Device App..."
  puts "CoAP server running on port 5683"
  puts ""
  puts "Try these commands:"
  puts "  coap-client -m get coap://localhost/sensor"
  puts "  coap-client -m post coap://localhost/command -e '{\"action\":\"reboot\"}'"
  puts "  coap-client -m get -s 10 coap://localhost/status  # Observe for 10s"
  puts "  coap-client -m get coap://localhost/config"
  puts ""

  DeviceApp.run!(port: 5683, protocols: [:udp])
end
