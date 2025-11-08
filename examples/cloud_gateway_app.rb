#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Cloud Gateway Application (Modular Pattern)
#
# This example demonstrates the modular pattern using Takagi::Controller
# and Takagi::Application for high-scale cloud/gateway servers.
#
# Use case: Cloud server handling thousands of devices with uneven load
#
# Run with: ruby examples/cloud_gateway_app.rb

require_relative '../lib/takagi'

# High-throughput telemetry ingestion
class TelemetryController < Takagi::Controller
  configure do
    mount '/telemetry'
    profile :high_throughput  # 8 processes × 4 threads = 32 workers
  end

  # POST /telemetry/data - High-volume sensor data ingestion
  post '/data' do |request|
    data = request.data

    # Simulate data processing
    {
      received: true,
      device_id: data['device_id'],
      timestamp: Time.now.to_i,
      points: data['points']&.length || 0
    }
  end

  # GET /telemetry/stats - Telemetry statistics
  get '/stats' do
    {
      total_devices: 1523,
      points_per_second: 15_234,
      avg_latency_ms: 12
    }
  end
end

# Observable streams for real-time monitoring
class ObservableController < Takagi::Controller
  configure do
    mount '/observe'
    profile :long_lived  # 2 processes × 8 threads = 16 workers (for long connections)
  end

  # OBSERVE /observe/devices/:id - Stream device data
  observable '/devices/:id' do |_request, params|
    device_id = params[:id]

    {
      device_id: device_id,
      status: 'online',
      last_seen: Time.now.to_i,
      temperature: rand(20..30),
      battery: rand(50..100)
    }
  end

  # OBSERVE /observe/alerts - Stream system alerts
  observable '/alerts' do
    {
      timestamp: Time.now.to_i,
      severity: %w[info warning error].sample,
      message: 'Sample alert message'
    }
  end
end

# Device management API
class DeviceManagementController < Takagi::Controller
  configure do
    mount '/devices'
    profile :low_traffic  # 1 process × 2 threads = 2 workers
  end

  # GET /devices - List all devices
  get '/' do
    {
      devices: [
        { id: 'device-001', name: 'Sensor 1', status: 'online' },
        { id: 'device-002', name: 'Sensor 2', status: 'online' },
        { id: 'device-003', name: 'Sensor 3', status: 'offline' }
      ],
      total: 3
    }
  end

  # GET /devices/:id - Get device details
  get '/:id' do |_request, params|
    {
      id: params[:id],
      name: "Device #{params[:id]}",
      status: 'online',
      firmware: '2.1.0',
      last_seen: Time.now.to_i
    }
  end

  # POST /devices/:id/command - Send command to device
  post '/:id/command' do |request, params|
    command = request.data

    {
      device_id: params[:id],
      command: command['action'],
      status: 'queued'
    }
  end
end

# Configuration API
class ConfigController < Takagi::Controller
  configure do
    mount '/config'
    profile :low_traffic
  end

  # GET /config/global - Get global configuration
  get '/global' do
    {
      telemetry_interval: 60,
      max_devices: 10_000,
      retention_days: 30
    }
  end

  # PUT /config/global - Update global configuration
  put '/global' do |request|
    config = request.data

    {
      updated: true,
      config: config
    }
  end
end

# Firmware update API (large payloads)
class FirmwareController < Takagi::Controller
  configure do
    mount '/firmware'
    profile :large_payloads  # 2 processes × 2 threads, 10MB buffer
  end

  # GET /firmware/latest - Get latest firmware info
  get '/latest' do
    {
      version: '2.1.0',
      size_bytes: 5_242_880,
      checksum: 'abc123...',
      release_date: '2025-01-15'
    }
  end

  # POST /firmware/upload - Upload new firmware
  post '/upload' do |request|
    # Simulate firmware processing
    {
      uploaded: true,
      size: request.payload&.bytesize || 0,
      checksum: 'processing...'
    }
  end
end

# Main application
class CloudGatewayApp < Takagi::Application
  configure do
    load_controllers(
      TelemetryController,
      ObservableController,
      DeviceManagementController,
      ConfigController,
      FirmwareController
    )
  end
end

if __FILE__ == $PROGRAM_NAME
  puts "Starting Cloud Gateway App..."
  puts "CoAP server running on port 5683"
  puts ""
  puts "Architecture:"
  puts "  /telemetry  - High throughput (32 workers) - Sensor data ingestion"
  puts "  /observe    - Long-lived (16 workers)    - Real-time streams"
  puts "  /devices    - Low traffic (2 workers)    - Device management"
  puts "  /config     - Low traffic (2 workers)    - Configuration API"
  puts "  /firmware   - Large payloads (4 workers) - Firmware updates"
  puts ""
  puts "Example commands:"
  puts "  # High-volume telemetry"
  puts "  coap-client -m post coap://localhost/telemetry/data -e '{\"device_id\":\"dev-001\",\"points\":[{\"temp\":25}]}'"
  puts ""
  puts "  # Observable streams"
  puts "  coap-client -m get -s 10 coap://localhost/observe/devices/dev-001"
  puts "  coap-client -m get -s 10 coap://localhost/observe/alerts"
  puts ""
  puts "  # Device management"
  puts "  coap-client -m get coap://localhost/devices"
  puts "  coap-client -m get coap://localhost/devices/dev-001"
  puts "  coap-client -m post coap://localhost/devices/dev-001/command -e '{\"action\":\"reboot\"}'"
  puts ""
  puts "  # Configuration"
  puts "  coap-client -m get coap://localhost/config/global"
  puts ""
  puts "  # Firmware"
  puts "  coap-client -m get coap://localhost/firmware/latest"
  puts ""

  CloudGatewayApp.run!(port: 5683, protocols: [:udp, :tcp])
end
