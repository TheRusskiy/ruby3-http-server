require 'socket'
require_relative 'request_parser'
require_relative 'http_responder'

class SingleThreadedServer
  PORT = ENV.fetch('PORT', 3000)
  BIND = ENV.fetch('BIND', '127.0.0.1').freeze
  SOCKET_READ_BACKLOG = ENV.fetch('TCP_BACKLOG', 12).to_i

  attr_accessor :app

  # app: Rack app
  def initialize(app)
    self.app = app
  end

  def start
    listener = Thread.new do
      socket = Socket.new(:INET, :STREAM)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      socket.bind(Addrinfo.tcp(BIND, PORT))
      socket.listen(SOCKET_READ_BACKLOG)
      loop do
        conn, _addr_info = socket.accept
        request = RequestParser.new(conn).parse
        # in a real app there would be a whole lot more information
        # about the request, but we are gonna keep it simple
        status, headers, body = app.call(
          'REQUEST_METHOD' => request.method,
          'PATH_INFO' => request.path,
          'QUERY_STRING' => request.query
        )
        HttpResponder.call(conn, status, headers, body)
      ensure
        conn&.close
      end
    end

    listener.join
  end
end
