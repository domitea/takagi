# Takagi – Lightweight CoAP Framework for Ruby

[![Gem Version](https://badge.fury.io/rb/takagi.svg)](https://rubygems.org/gems/takagi)
[![Build Status](https://github.com/domitea/takagi/actions/workflows/main.yml/badge.svg)](https://github.com/domitea/takagi/actions)

## About Takagi

**Takagi** is a **Sinatra-like CoAP framework** for IoT and microservices in Ruby.  
It provides a lightweight way to build **CoAP APIs**, handle **IoT messaging**, and process sensor data efficiently.

🔹 **Minimalistic DSL** – Define CoAP endpoints just like in Sinatra.  
🔹 **CoRE discovery helpers** – Configure link-format metadata inline or at boot.  
🔹 **Efficient and fast** – Runs over UDP, ideal for IoT applications.  
🔹 **Reliable transport** – Supports CoAP over TCP (RFC 8323).

## Why "Takagi"?
The name **Takagi** is inspired by **Riyoko Takagi**, as a nod to the naming convention of Sinatra.
Just like Sinatra simplified web applications in Ruby, Takagi aims to simplify CoAP-based IoT communication in Ruby. It embodies minimalism, efficiency, and a straightforward approach to handling CoAP requests.
Additionally, both Sinatra and Takagi share a connection to **jazz music**, as Riyoko Takagi is a known jazz pianist, much like how Sinatra was named after the legendary Frank Sinatra.

---

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'takagi'
```

Or install it manually:

```sh
gem install takagi
```

---

## Getting Started

### **Create a new Takagi API**
```ruby
require 'takagi'

class SensorAPI < Takagi::Base
  get '/sensor/:id' do |request, params|
    { id: params[:id], value: 22.5 }
  end

  post '/sensor' do |request|
    payload = JSON.parse(request.payload || '{}')
    { created: payload['id'] }
  end
end

SensorAPI.run!
# To serve CoAP over TCP instead of UDP:
# SensorAPI.run!(protocols: [:tcp])
# To serve both TCP and UDP simultaneously:
# SensorAPI.run!(protocols: [:udp, :tcp])
```
To perform requests over TCP you can use the built-in `TcpClient`:

```ruby
client = Takagi::TcpClient.new('coap+tcp://localhost:5683')
client.get('/ping') { |resp| puts Takagi::Message::Inbound.new(resp).payload }
```
🔥 **Boom! You just built a CoAP API in Ruby.**

### **Configure CoRE discovery metadata**

Expose meaningful attributes in `/.well-known/core` either inline or after registration:

```ruby
class SensorAPI < Takagi::Base
  get '/metrics' do
    core do
      title 'Environment Metrics'
      rt %w[sensor.metrics sensor.temp]
      interface 'core.s'
      sz 256 # expected size of data
    end

    { temp: 21.4, humidity: 0.48 }
  end
end

# Configure discovery data separately (e.g. in an initializer):
SensorAPI.core '/metrics' do
  title 'Environment Metrics'
  ct 'application/cbor'
end
```

Both approaches share the same DSL, so you can keep route handlers focused while still
publishing rich metadata.

### **But CoAP is not only GET, POST, PUT and DELETE. There is also Observe!**
```ruby
require 'takagi'

class SensorAPI < Takagi::Base
  reactor do
    observable "/sensors/temp" do |request|
      core do
        title 'Temperature Stream'
        rt 'sensor.temp.streaming'
      end

      { temp: 42.0 }
    end

    observe "coap://temp_server/temp" do |request, params|
      Takagi.logger.info "Remote temperature update: #{params.inspect}"
    end
  end
end

SensorAPI.run!
```
🔥 **Takagi is also Observe (RFC 7641) enabled**

---

## Sending Requests

### **Using `coap-client`**
```sh
coap-client -m get coap://localhost:5683/sensor/1
```
```sh
coap-client -m post coap://localhost:5683/sensor -e '{"value":42}'
```

---

## Features & Modules

| Feature                          | Description | Status |
|----------------------------------|-------------|--------|
| **CoAP API (RFC 7252)**          | Define REST-like CoAP routes | ✅ Ready |
| **CoRE metadata DSL (RFC 6690)** | Describe discovery attributes inline or at boot | ✅ Ready |
| **Observe (RFC 7641)**           | Offer server push and subscribe to remote feeds | ✅ Ready |
| **CoAP over TCP (RFC 8323)**     | Reliable transport for constrained clients | ✅ Ready |

---

## Contributing

Want to help? Fork the repo and submit a PR!

```sh
git clone https://github.com/domitea/takagi.git
cd takagi
bundle install
```

Run tests:
```sh
bundle exec rspec
```

---

## License

**MIT License**

---
