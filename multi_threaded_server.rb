require 'socket'
require_relative 'request_parser'
require_relative 'http_responder'

class ThreadPool
  attr_accessor :queue, :running, :size

  def initialize(size:)
    self.size = size

    # threadsafe queue to manage work
    self.queue = Queue.new

    size.times do
      Thread.new(self.queue) do |queue|
        # "catch" in Ruby is a lesser known
        # way to change flow of the program,
        # similar to propagating exceptions
        catch(:exit) do
          loop do
            # `pop` blocks until there's
            # something in the queue
            task = queue.pop
            task.call
          end
        end
      end
    end
  end

  def perform(&block)
    self.queue << block
  end

  def shutdown
    size.times do
      # this is going to make threads
      # break out of the infinite loop
      perform { throw :exit }
    end
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
    socket = TCPServer.new(HOST, PORT)
    socket.listen(SOCKET_READ_BACKLOG)
    loop do
      conn, _addr_info = socket.accept
      # execute the request in one of the threads
      pool.perform do
        begin
          request = RequestParser.call(conn)
          status, headers, body = app.call(request)
          HttpResponder.call(conn, status, headers, body)
        rescue => e
          puts e.message
        ensure
          conn&.close
        end
      end
    end
  ensure
    pool&.shutdown
  end
end
