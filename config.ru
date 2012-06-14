require 'bundler/setup'
require 'net/http'
require 'json'
Bundler.require(:default)

FAYE_TOKEN = "suppppyallll"

class ServerAuth

  def faye_client
    @faye_client ||= Faye::Client.new('http://hackchat.dev:9292/faye')
  end

  def incoming(message, callback)
    if message['channel'] !~ %r{^/meta/}
      if message['ext']
        if message['ext']['auth_token'] != FAYE_TOKEN
          message['error'] = 'Invalid authentication token'
        end
      end
    end
    callback.call(message)
  end

end

Faye::WebSocket.load_adapter('thin')
faye_server = Faye::RackAdapter.new(:mount => '/faye', :timeout => 45)
faye_server.add_extension(ServerAuth.new)
run faye_server