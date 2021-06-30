require 'socket'
require 'puma'

PORT = ENV.fetch('PORT', 3000).freeze
BIND = ENV.fetch('BIND', '127.0.0.1').freeze
READ_QUEUE = 0
WORKERS_COUNT = 4

LF  = "\012".freeze

def main
  queue = Ractor.new do
    loop do
      con = Ractor.recv
      puts "dispatching #{con}"
      Ractor.yield(con, move: true)
    end
  end

  workers = WORKERS_COUNT.times.map do
    Ractor.new(queue) do |queue|
      loop do
        puts "taking"
        conn = queue.take
        puts "received connection: #{conn}"
        request = read_request(conn)

        if request.nil?
          puts "skipping"
          conn.close
          next
        end
        puts "request: #{request}"
        respond_for_request(conn, request)
        puts "responded: #{request}"
      rescue => e
        puts "Error: #{e.message}"
      end
    end
  end

  listener = Ractor.new(queue) do |queue|
    server = TCPServer.new(BIND, PORT)
    loop do
      conn, add_info = server.accept
      puts "new connection: #{conn}"
      queue.send(conn, move: true)
    end
  end

  Ractor.select(listener)
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

def read_request(conn)
  request_line = conn.gets(LF, 2083) # 2083 is max URI length

  raise StandardError, "EOF" unless request_line

  puts "request_line '#{request_line}'"
  method, full_path, version = request_line.split(' ', 3)
  path, query = full_path.split('?', 2)
  headers = {}
  loop do
    puts "reading..."
    line = conn.gets&.sub("\r\n", '')
    puts "line: '#{line}'"
    break if line.empty?
    key, value = line.split(/:\s/, 2)
    headers[key] = value
  end
  Request.new(rand(100), method, path, query, headers)
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
ensure
  puts "closing"
  conn_sock.close
  puts "closed"
end

class Request < Struct.new(:id, :method, :path, :query, :headers); end

main
