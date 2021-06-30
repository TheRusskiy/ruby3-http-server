require 'socket'
require_relative 'request_parser'

class RactorServer
  PORT = ENV.fetch('PORT', 3000)
  BIND = ENV.fetch('BIND', '127.0.0.1').freeze
  READ_QUEUE = ENV.fetch('QUEUE', 12).to_i
  WORKERS_COUNT = ENV.fetch('WORKERS', 4).to_i

  attr_accessor :app

  def initialize(app)
    self.app = app
  end

  def start
    queue = Ractor.new do
      loop do
        conn = Ractor.recv
        Ractor.yield(conn, move: true)
      end
    end

    WORKERS_COUNT.times.map do
      Ractor.new(queue, self) do |queue, server|
        loop do
          conn = queue.take
          request = RequestParser.new(conn).parse
          status, headers, body = server.app.call(
             'REQUEST_METHOD' => request.method,
             'PATH_INFO' => request.path,
             'QUERY_STRING' => request.query
           )
          server.respond(conn, status, headers, body)
        ensure
          conn&.close
        end
      end
    end

    listener = Ractor.new(queue) do |queue|
      socket = Socket.new(:INET, :STREAM)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      socket.bind(Addrinfo.tcp(BIND, PORT))
      socket.listen(READ_QUEUE)
      loop do
        conn, _addr_info = socket.accept
        queue.send(conn, move: true)
      end
    end

    Ractor.select(listener)
  end

  def respond(conn_sock, status, headers, body)
    status_text = {
      200 => 'OK',
      404 => 'Not Found'
    }[status]
    conn_sock.send("HTTP/1.1 #{status} #{status_text}\r\n", 0)
    conn_sock.send("Content-Length: #{body.sum(&:length)}\r\n", 0)
    headers.each_pair do |name, value|
      conn_sock.send("#{name}: #{value}\r\n", 0)
    end
    conn_sock.send("Connection: close\r\n", 0)
    conn_sock.send("\r\n", 0)
    body.each do |chunk|
      conn_sock.send(chunk, 0)
    end
  end
end
