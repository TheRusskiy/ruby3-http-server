require 'socket'
require_relative 'request_parser'
require_relative 'http_responder'

class ThreadPool
  attr_accessor :queue, :running

  def initialize(size:)
    self.queue = Queue.new

    size.times do
      Thread.new(self.queue) do |queue|
        loop do
          task = queue.pop
          task.call
        end
      end
    end
  end

  def perform(&block)
    self.queue << block
  end
end

class MultiThreadedServer
  PORT = ENV.fetch('PORT', 3000)
  HOST = ENV.fetch('HOST', '127.0.0.1').freeze
  SOCKET_READ_BACKLOG = ENV.fetch('TCP_BACKLOG', 12).to_i
  WORKERS_COUNT = ENV.fetch('WORKERS', 4).to_i

  attr_accessor :app

  # app: Rack app
  def initialize(app)
    self.app = app
  end

  def start
    pool = ThreadPool.new(size: WORKERS_COUNT)
    socket = Socket.new(:INET, :STREAM)
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
    socket.bind(Addrinfo.tcp(HOST, PORT))
    socket.listen(SOCKET_READ_BACKLOG)
    loop do
      conn, _addr_info = socket.accept
      pool.perform do
        begin
          request = RequestParser.new(conn).parse
          status, headers, body = app.call(request)
          HttpResponder.call(conn, status, headers, body)
        ensure
          conn&.close
        end
      end
    end
  end
end
