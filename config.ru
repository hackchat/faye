require 'bundler/setup'
require 'net/http'
require 'json'
Bundler.require(:default)

FAYE_TOKEN = "suppppyallll"
REDIS_URI = URI.parse("redis://redistogo:b8a6ecd52bed232f3d391126f0a9471c@dogfish.redistogo.com:9010")
REDIS = Redis.new(host: REDIS_URI.host, port: REDIS_URI.port, password: REDIS_URI.password)

class ServerAuth
  def incoming(message, callback)
    if message['channel'] !~ %r{^/meta/}
      if message['ext']['auth_token'] != FAYE_TOKEN
        message['error'] = 'Invalid authentication token'
      end
    end
    callback.call(message)
  end
end


Thread.new do
  REDIS.subscribe("create") do |s|
    s.message do |c, m|
      parsed = JSON.parse(m)
      message = {
                 :channel => "/messages/#{parsed["message"]["room_id"]}",
                 :data => parsed["message"],
                 :ext => {:auth_token => "suppppyallll"}
                 }
      uri = URI.parse("http://hackchat.in:9292/faye")
      Net::HTTP.post_form(uri, :message => message.to_json) if uri
    end
  end
end

Faye::WebSocket.load_adapter('thin')
faye_server = Faye::RackAdapter.new(:mount => '/faye', :timeout => 45)
faye_server.add_extension(ServerAuth.new)
run faye_server