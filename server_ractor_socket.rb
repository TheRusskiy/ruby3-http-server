require 'socket'
require 'puma'

PORT = ENV.fetch('PORT', 3000)
BIND = ENV.fetch('BIND', '127.0.0.1').freeze
READ_QUEUE = ENV.fetch('QUEUE', 12).to_i
WORKERS_COUNT = ENV.fetch('WORKERS', 4).to_i

class RactorServer
  def start
    queue = Ractor.new do
      loop do
        req = Ractor.recv
        puts "dispatching #{req}"
        Ractor.yield(req, move: true)
      end
    end

    workers = WORKERS_COUNT.times.map do
      Ractor.new(queue) do |queue|
        loop do
          conn = queue.take
          puts "received connection: #{conn}"
          request = RequestParser.new(conn).parse
          puts "request: #{request}"
          respond_for_request(conn, request)
          puts "responded"
        ensure
          puts "closing #{conn}"
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
        conn, addr_info = socket.accept
        puts "new connection: #{conn}"
        queue.send(conn, move: true)
      end
    end

    Ractor.select(listener)
  end
end

def respond_for_request(conn, request)
  path = Dir.getwd + request.path
  if File.exist?(path)
    content = File.read(path)
    status_code = 200
  else
    content = ''
    status_code = 404
  end
  status_code = 200
  respond(conn, status_code, content)
end

def respond(conn_sock, status_code, content)
  status_text = {
    200 => 'OK',
    404 => 'Not Found'
  }[status_code]
  conn_sock.send("HTTP/1.1 #{status_code} #{status_text}\r\n", 0)
  conn_sock.send("Content-Length: #{content.length}\r\n", 0)
  conn_sock.send("\r\n", 0)
  conn_sock.send(content, 0)
end

class Request < Struct.new(:method, :path, :query, :headers); end

class RequestParser
  def initialize(conn_sock)
    @conn_sock = conn_sock
    @buffer = ''
  end

  def parse
    request_line = @conn_sock.gets("\012", 2083)  # 2083 is max URI length

    raise StandardError, "EOF" unless request_line

    method, full_path, version = request_line.split(' ', 3)
    path, query = full_path.split('?', 2)
    headers = {}
    puts "reading headers..."
    loop do
      line = @conn_sock.gets("\012", (112 * 1024))&.sub("\r\n", '')
      puts "line: '#{line}'"
      break if line.nil? || line.empty?
      key, value = line.split(/:\s/, 2)
      headers[key] = value
    end
    puts "building a request"
    Request.new(method, path, query, headers)
  end
end

RactorServer.new.start
