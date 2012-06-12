require 'bundler/setup'
require 'net/http'
require 'json'
Bundler.require(:default)

FAYE_URL = 'http://hackchat.in:9292/faye'
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
        :ext => {:auth_token => FAYE_TOKEN}
      }
      uri = URI.parse(FAYE_URL)
      Net::HTTP.post_form(uri, :message => message.to_json) if uri
    end
  end
end


class ClientEvent
  MONITORED_CHANNELS = [ '/meta/subscribe', '/meta/disconnect' ]

  def incoming(message, callback)
    return callback.call(message) unless MONITORED_CHANNELS.include? message['channel']

    faye_msg = Hashie::Mash.new(message)
    faye_action = faye_msg.channel.split('/').last

    if name = get_client(faye_msg.clientId, faye_action)
      faye_client.publish('/messages/new', build_hash(name, faye_action))
    end
    callback.call(message)
  end

  def connected_clients
    @connected_clients ||= { }
  end

  def push_client(client_id)
    connected_clients[client_id] = "Guest #{rand(10000)}"
  end

  def pop_client(client_id)
    connected_clients.delete(client_id)
  end

  def get_client(client_id, action)
    if action == 'subscribe'
      push_client(client_id)
    elsif action == 'disconnect'
      pop_client(client_id)
    end
  end

  def faye_client
    @faye_client ||= Faye::Client.new(FAYE_URL)
  end

  def build_hash(name, action)
    message_hash = {}
    if action == 'subscribe'
      message_hash['message'] = { 'content' => "#{name} entered."}
    elsif action == 'disconnect'
      message_hash['message'] = { 'content' => "#{name} left." }
    end

    message_hash
  end
end

Faye::WebSocket.load_adapter('thin')
faye_server = Faye::RackAdapter.new(:mount => '/faye', :timeout => 45)
faye_server.add_extension(ServerAuth.new)
faye_server.add_extension(ClientEvent.new)
run faye_server