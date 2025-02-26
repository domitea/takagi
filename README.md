# Takagi – Lightweight CoAP Framework for Ruby

<!---
[![Gem Version](https://badge.fury.io/rb/takagi.svg)](https://rubygems.org/gems/takagi)
-->
[![Build Status](https://github.com/domitea/takagi/actions/workflows/main.yml/badge.svg)](https://github.com/domitea/takagi/actions)

## About Takagi

**Takagi** is a **Sinatra-like CoAP framework** for IoT and microservices in Ruby.  
It provides a lightweight way to build **CoAP APIs**, handle **IoT messaging**, and process sensor data efficiently.

🔹 **Minimalistic DSL** – Define CoAP endpoints just like in Sinatra.  
🔹 **Efficient and fast** – Runs over UDP, ideal for IoT applications.  
🔹 **Database-ready** – Seamless integration with **Sequel** for storing device data.

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
  get "/sensor/:id" do |params|
    Sensor[params[:id].to_i].to_json
  end

  post "/sensor" do |params|
    Sensor.create(params).to_json
  end
end

Takagi.run!
```
🔥 **Boom! You just built a CoAP API in Ruby.**

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

| Feature         | Description                                    | Status |
|-----------------|--------------------------------|--------|
| **CoAP API**  | Define REST-like CoAP routes | ✅ Ready |
| **Sequel DB** | Store IoT data in PostgreSQL, SQLite, etc. | ✅ Ready |
| **Notifications** | Redis, HTTP, ZeroMQ messaging | 🔄 WIP |
| **Buffering** | Store messages before processing | 🔄 Planned |
| **Compression** | Reduce payload size | 🔄 Planned |

---

## Roadmap

✅ **Core framework (CoAP, Sequel, notifications)**   
🔜 **Web UI for data visualization**  
🔜 **More integrations: NATS, MQTT...**

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
rspec
```

---

## License

**MIT License**

---
