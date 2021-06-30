require_relative 'request'

class RequestParser
  def initialize(conn_sock)
    @conn_sock = conn_sock
    @buffer = ''
  end

  def parse
    request_line = @conn_sock.gets("\012", 2083)  # 2083 is max URI length

    raise StandardError, "EOF" unless request_line

    method, full_path, _http_version = request_line.split(' ', 3)
    path, query = full_path.split('?', 2)
    headers = {}
    loop do
      line = @conn_sock.gets("\012", (112 * 1024))&.sub("\r\n", '')
      break if line.nil? || line.empty?
      key, value = line.split(/:\s/, 2)
      headers[key] = value
    end
    Request.new(method, path, query, headers)
  end
end
