require 'stringio'
require 'uri'

class RequestParser
  MAX_URI_LENGTH = 2083
  MAX_HEADER_LENGTH = (112 * 1024)

  class << self
    def call(conn)
      method, full_path, path, query = read_request_line(conn)

      headers = read_headers(conn)

      body = read_body(conn: conn, method: method, headers: headers)

      peeraddr = conn.peeraddr
      addr = conn.addr
      port = addr[1]
      remote_host = peeraddr[2]
      remote_address = peeraddr[3]
      {
        'REQUEST_METHOD' => method,
        'PATH_INFO' => path,
        'QUERY_STRING' => query,
        "rack.input" => body ? StringIO.new(body) : nil,
        "REMOTE_ADDR" => remote_address,
        "REMOTE_HOST" => remote_host,
        "REQUEST_URI" => make_request_uri(
          full_path: full_path,
          port: port,
          remote_host: remote_host
        )
      }.merge(rack_headers(headers))
    end

    private

    def read_request_line(conn)
      # e.g. "POST /some-path?query HTTP/1.1"

      # read until we encounter a newline, max length is MAX_URI_LENGTH
      request_line = conn.gets("\n", MAX_URI_LENGTH)

      raise StandardError, "EOF" unless request_line

      method, full_path, _http_version = request_line.strip.split(' ', 3)

      path, query = full_path.split('?', 2)

      [method, full_path, path, query]
    end

    def read_headers(conn)
      headers = {}
      loop do
        line = conn.gets("\n", MAX_HEADER_LENGTH)&.strip

        break if line.nil? || line.strip.empty?

        # header name and value are separated by colon and space
        key, value = line.split(/:\s/, 2)

        # rack expects all headers to be prefixed with HTTP_
        # and upper cased
        headers[key] = value
      end

      headers
    end

    def read_body(conn:, method:, headers:)
      return nil unless ['POST', 'PUT'].include?(method)

      remaining_size = headers['content-length'].to_i

      conn.read(remaining_size)
    end

    def rack_headers(headers)
      # rack expects all headers to be prefixed with HTTP_
      # and upper cased
      headers.transform_keys do |key|
        "HTTP_#{key.upcase}"
      end
    end

    def make_request_uri(full_path:, port:, remote_host:)
      request_uri = URI::parse(full_path)
      request_uri.scheme = 'http'
      request_uri.host = remote_host
      request_uri.port = port
      request_uri.to_s
    end
  end
end
