#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Nested API Application
#
# This example demonstrates nested controller mounting for
# organizing complex APIs with versioning and resource hierarchy.
#
# Use case: RESTful API with nested resources
#
# Run with: ruby examples/nested_api_app.rb

require_relative '../lib/takagi'

# --- API v1 ---

# Sensors controller under API v1
class V1SensorsController < Takagi::Controller
  configure do
    mount '/sensors'
    profile :high_throughput
  end

  # GET /api/v1/sensors
  get '/' do
    {
      sensors: [
        { id: 'temp-001', type: 'temperature', location: 'room-1' },
        { id: 'hum-001', type: 'humidity', location: 'room-1' }
      ]
    }
  end

  # GET /api/v1/sensors/:id
  get '/:id' do |_request, params|
    {
      id: params[:id],
      type: 'temperature',
      value: rand(20..30),
      unit: 'celsius',
      timestamp: Time.now.to_i
    }
  end

  # POST /api/v1/sensors/:id/readings
  post '/:id/readings' do |request, params|
    data = request.data

    {
      sensor_id: params[:id],
      reading_id: SecureRandom.uuid,
      value: data['value'],
      stored: true
    }
  end
end

# Users controller under API v1
class V1UsersController < Takagi::Controller
  configure do
    mount '/users'
    profile :low_traffic
  end

  # GET /api/v1/users
  get '/' do
    {
      users: [
        { id: 'user-001', name: 'Alice', role: 'admin' },
        { id: 'user-002', name: 'Bob', role: 'user' }
      ]
    }
  end

  # GET /api/v1/users/:id
  get '/:id' do |_request, params|
    {
      id: params[:id],
      name: "User #{params[:id]}",
      role: 'user',
      created_at: Time.now.to_i
    }
  end
end

# API v1 parent controller
class ApiV1Controller < Takagi::Controller
  configure do
    mount '/api/v1'

    # Nest resource controllers
    nest V1SensorsController, V1UsersController
  end

  # GET /api/v1 - API info
  get '/' do
    {
      version: '1.0',
      endpoints: {
        sensors: '/api/v1/sensors',
        users: '/api/v1/users'
      },
      status: 'stable'
    }
  end
end

# --- API v2 (Improved version) ---

class V2SensorsController < Takagi::Controller
  configure do
    mount '/sensors'
    profile :high_throughput
  end

  # GET /api/v2/sensors
  get '/' do
    {
      sensors: [
        {
          id: 'temp-001',
          type: 'temperature',
          location: { building: 'A', floor: 1, room: 'room-1' },
          metadata: { calibrated: true, accuracy: 0.1 }
        }
      ],
      pagination: { page: 1, total: 1 }
    }
  end

  # GET /api/v2/sensors/:id
  get '/:id' do |_request, params|
    {
      id: params[:id],
      type: 'temperature',
      readings: {
        current: rand(20..30),
        min_24h: 18,
        max_24h: 32,
        avg_24h: 25
      },
      unit: 'celsius',
      timestamp: Time.now.to_i
    }
  end
end

class ApiV2Controller < Takagi::Controller
  configure do
    mount '/api/v2'
    nest V2SensorsController
  end

  # GET /api/v2 - API info
  get '/' do
    {
      version: '2.0',
      endpoints: {
        sensors: '/api/v2/sensors'
      },
      status: 'beta',
      improvements: [
        'Enhanced sensor metadata',
        'Improved response structure',
        'Better pagination'
      ]
    }
  end
end

# --- Admin API (separate hierarchy) ---

class AdminDevicesController < Takagi::Controller
  configure do
    mount '/devices'
  end

  # DELETE /admin/devices/:id
  delete '/:id' do |_request, params|
    {
      deleted: true,
      device_id: params[:id],
      timestamp: Time.now.to_i
    }
  end
end

class AdminController < Takagi::Controller
  configure do
    mount '/admin'
    profile :low_traffic
    nest AdminDevicesController
  end

  # GET /admin/stats
  get '/stats' do
    {
      total_devices: 523,
      active_users: 42,
      api_requests_24h: 15_234,
      storage_used_gb: 125
    }
  end
end

# Main application
class NestedApiApp < Takagi::Application
  configure do
    load_controllers(
      ApiV1Controller,
      ApiV2Controller,
      AdminController
    )
  end
end

if __FILE__ == $PROGRAM_NAME
  puts "Starting Nested API App..."
  puts "CoAP server running on port 5683"
  puts ""
  puts "API Structure:"
  puts "  /api/v1"
  puts "    /api/v1/sensors"
  puts "      GET  /api/v1/sensors"
  puts "      GET  /api/v1/sensors/:id"
  puts "      POST /api/v1/sensors/:id/readings"
  puts "    /api/v1/users"
  puts "      GET  /api/v1/users"
  puts "      GET  /api/v1/users/:id"
  puts ""
  puts "  /api/v2 (Beta)"
  puts "    /api/v2/sensors"
  puts "      GET  /api/v2/sensors"
  puts "      GET  /api/v2/sensors/:id"
  puts ""
  puts "  /admin"
  puts "    GET    /admin/stats"
  puts "    /admin/devices"
  puts "      DELETE /admin/devices/:id"
  puts ""
  puts "Example commands:"
  puts "  # API v1"
  puts "  coap-client -m get coap://localhost/api/v1"
  puts "  coap-client -m get coap://localhost/api/v1/sensors"
  puts "  coap-client -m get coap://localhost/api/v1/sensors/temp-001"
  puts "  coap-client -m post coap://localhost/api/v1/sensors/temp-001/readings -e '{\"value\":25.5}'"
  puts ""
  puts "  # API v2 (Beta)"
  puts "  coap-client -m get coap://localhost/api/v2"
  puts "  coap-client -m get coap://localhost/api/v2/sensors/temp-001"
  puts ""
  puts "  # Admin"
  puts "  coap-client -m get coap://localhost/admin/stats"
  puts "  coap-client -m delete coap://localhost/admin/devices/old-device-001"
  puts ""

  NestedApiApp.run!(port: 5683, protocols: [:udp])
end
