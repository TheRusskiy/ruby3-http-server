require 'socket'
require_relative 'request_parser'
require_relative 'http_responder'

class RactorServer
  PORT = ENV.fetch('PORT', 3000)
  BIND = ENV.fetch('BIND', '127.0.0.1').freeze
  SOCKET_READ_BACKLOG = ENV.fetch('TCP_BACKLOG', 12).to_i
  WORKERS_COUNT = ENV.fetch('WORKERS', 4).to_i

  attr_accessor :app

  # app: Rack app
  def initialize(app)
    self.app = app
  end

  def start
    # the queue is going to be used to
    # fairly dispatch incoming requests,
    # we pass the queue into workers
    # and the first free worker gets
    # the yielded request
    queue = Ractor.new do
      loop do
        conn = Ractor.recv
        Ractor.yield(conn, move: true)
      end
    end

    # workers determine concurrency
    WORKERS_COUNT.times.map do
      # we need to pass the queue and the server so they are available
      # inside Ractor
      Ractor.new(queue, self) do |queue, server|
        loop do
          # this method blocks until the queue yields a connection
          conn = queue.take
          request = RequestParser.new(conn).parse
          # in a real app there would be a whole lot more information
          # about the request, but we are gonna keep it simple
          status, headers, body = server.app.call(
             'REQUEST_METHOD' => request.method,
             'PATH_INFO' => request.path,
             'QUERY_STRING' => request.query
           )
          HttpResponder.call(conn, status, headers, body)
        ensure
          conn&.close
        end
      end
    end

    # the listener is going to accept new connections
    # and pass them onto the queue,
    # we make it a separate Ractor, because `yield` in queue
    # is a blocking operation, we wouldn't be able to accept new connections
    # until all previous were processed, and we can't use `send` to send
    # connections to workers because then we would send requests to workers
    # that might be busy
    listener = Ractor.new(queue) do |queue|
      socket = Socket.new(:INET, :STREAM)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      socket.bind(Addrinfo.tcp(BIND, PORT))
      socket.listen(SOCKET_READ_BACKLOG)
      loop do
        conn, _addr_info = socket.accept
        queue.send(conn, move: true)
      end
    end

    Ractor.select(listener)
  end
end
