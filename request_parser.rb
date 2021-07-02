require 'stringio'
require 'uri'

class RequestParser
  MAX_URI_LENGTH = 2083
  MAX_HEADER_LENGTH = (112 * 1024)
  CF = "\012".freeze
  CR   = "\x0d".freeze
  LF   = "\x0a".freeze
  CRLF = "\x0d\x0a".freeze

  def initialize(conn_sock)
    @conn_sock = conn_sock
    @buffer = ''
  end

  def parse
    method, full_path, path, query = read_request_line

    headers = read_headers
    # in a real app there would be a whole lot more information
    # about the request, but we are gonna keep it simple

    body = read_body(method: method, headers: headers)

    peeraddr = @conn_sock.respond_to?(:peeraddr) ? @conn_sock.peeraddr : []
    addr = @conn_sock.respond_to?(:addr) ? @conn_sock.addr : []
    _host, port = addr[2], addr[1]
    remote_address = peeraddr[3]
    remote_host = peeraddr[2]
    request_uri = URI::parse(full_path)
    request_uri.scheme = 'http'
    request_uri.host = remote_host
    request_uri.port = port
    {
      'REQUEST_METHOD' => method,
      'PATH_INFO' => path,
      'QUERY_STRING' => query,
      "rack.input" => body ? StringIO.new(body) : nil,
      "REMOTE_ADDR" => remote_address,
      "REMOTE_HOST" => remote_host,
      "REQUEST_URI" => request_uri.to_s
    }.merge(rake_headers(headers))
  end

  private

  def read_request_line
    # e.g. "POST /some-path?query HTTP/1.1"
    request_line = @conn_sock.gets(CF, MAX_URI_LENGTH)

    raise StandardError, "EOF" unless request_line

    method, full_path, _http_version = request_line.strip.split(' ', 3)

    path, query = full_path.split('?', 2)

    [method, full_path, path, query]
  end

  def read_headers
    headers = {}
    loop do
      line = @conn_sock.gets(LF, MAX_HEADER_LENGTH)&.strip

      break if line.nil? || line.strip.empty?

      # header name and value are separated by colon and space
      key, value = line.split(/:\s/, 2)

      # rack expects all headers to be prefixed with HTTP_
      # and upper cased
      headers[key] = value
    end

    headers
  end

  def read_body(method:, headers:)
    return nil unless ['POST', 'PUT'].include?(method)

    remaining_size = headers['content-length'].to_i

    @conn_sock.read(remaining_size)
  end

  def rake_headers(headers)
    headers.transform_keys do |key|
      "HTTP_#{key.upcase}"
    end
  end
end
