require 'socket'
require 'uri'
require_relative 'request_parser'
require_relative 'http_responder'

class RactorServer
  PORT = ENV.fetch('PORT', 3000)
  HOST = ENV.fetch('HOST', '127.0.0.1').freeze
  SOCKET_READ_BACKLOG = ENV.fetch('TCP_BACKLOG', 12).to_i
  WORKERS_COUNT = ENV.fetch('WORKERS', 4).to_i

  attr_accessor :app

  # app: Rack app
  def initialize(app)
    self.app = app
    # this is hack to make URI parsing work,
    # right now it's broken because this variable
    # is not marked as shareable
    Ractor.make_shareable(URI::RFC3986_PARSER)
    Ractor.make_shareable(URI::DEFAULT_PARSER)
  end

  def start
    # the queue is going to be used to
    # fairly dispatch incoming requests,
    # we pass the queue into workers
    # and the first free worker gets
    # the yielded request
    queue = Ractor.new do
      loop do
        conn = Ractor.receive
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
          request = RequestParser.call(conn)
          status, headers, body = server.app.call(request)
          HttpResponder.call(conn, status, headers, body)

          # I have found that not rescuing errors does not only kill the ractor,
          # but causes random `allocator undefined for Ractor::MovedObject` errors
          # which crashes the whole program
        rescue => e
          puts e.message
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
      socket = TCPServer.new(HOST, PORT)
      socket.listen(SOCKET_READ_BACKLOG)
      loop do
        conn, _addr_info = socket.accept
        queue.send(conn, move: true)
      end
    end

    Ractor.select(listener)
  end
end
