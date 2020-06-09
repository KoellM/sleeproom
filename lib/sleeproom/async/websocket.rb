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
    return buffer
  end
  
  def dump(object)
    return object
  end
end