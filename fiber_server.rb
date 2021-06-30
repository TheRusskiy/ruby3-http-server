require 'socket'
require 'libev_scheduler'
require_relative 'request_parser'
require_relative 'http_responder'

class FiberServer
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
    Fiber.set_scheduler(Libev::Scheduler.new)

    Fiber.schedule do
      server = TCPServer.new(BIND, PORT)
      loop do
        conn, _addr_info = server.accept
        Fiber.schedule do
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
