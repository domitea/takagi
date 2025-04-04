# Takagi – Lightweight CoAP Framework for Ruby

[![Gem Version](https://badge.fury.io/rb/takagi.svg)](https://rubygems.org/gems/takagi)
[![Build Status](https://github.com/domitea/takagi/actions/workflows/main.yml/badge.svg)](https://github.com/domitea/takagi/actions)

## About Takagi

**Takagi** is a **Sinatra-like CoAP framework** for IoT and microservices in Ruby.  
It provides a lightweight way to build **CoAP APIs**, handle **IoT messaging**, and process sensor data efficiently.

🔹 **Minimalistic DSL** – Define CoAP endpoints just like in Sinatra.  
🔹 **Efficient and fast** – Runs over UDP, ideal for IoT applications.

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
  get "/sensor/:id" do |params|
    puts params[:id].to_i
  end

  post "/sensor" do |params|
    puts params[:id].to_i
  end
end

SensorAPI.run!
```
🔥 **Boom! You just built a CoAP API in Ruby.**

### **But CoAP is not only GET, POST, PUT and DELETE. There is also Observe!**
```ruby
require 'takagi'

class SensorAPI < Takagi::Base
  get "/sensor/:id" do |params|
    puts params[:id].to_i
  end

  reactor do
      observable "/sensors/temp" do # this endpoint can be observerved in CoAP way
        { temp: 42.0 }
      end
      
      observe "coap://temp_server/temp" do |params| # you can also observe another CoAP endpoints
        puts params.inspect
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

| Feature         | Description                                    | Status |
|-----------------|--------------------------------|--------|
| **CoAP API**  | Define REST-like CoAP routes | ✅ Ready |
| **Sequel DB** | Store IoT data in PostgreSQL, SQLite, etc. | 🔄 Planned |
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
