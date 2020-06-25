# frozen_string_literal: true

require "async/websocket/connection"
class WebSocketConnection < Async::WebSocket::Connection
  def read
    if buffer = super
      parse(buffer)
    end
  end

  def write(object)
    super(dump(object))
  end

  def parse(buffer)
    buffer
  end

  def dump(object)
    object
  end
end
