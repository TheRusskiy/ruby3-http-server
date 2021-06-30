class RequestParser
  MAX_URI_LENGTH = 2083
  MAX_HEADER_LENGTH = (112 * 1024)
  CF = "\012".freeze

  def initialize(conn_sock)
    @conn_sock = conn_sock
    @buffer = ''
  end

  def parse
    # e.g. "POST /some-path?query HTTP/1.1"
    request_line = @conn_sock.gets(CF, MAX_URI_LENGTH)

    raise StandardError, "EOF" unless request_line

    method, full_path, _http_version = strip(request_line).split(' ', 3)

    path, query = full_path.split('?', 2)

    headers = {}
    loop do
      line = strip(@conn_sock.gets(CF, MAX_HEADER_LENGTH))

      break if line.nil? || line.empty?

      # header name and value are separated by colon and space
      key, value = line.split(/:\s/, 2)

      # rack expects all headers to be prefixed with HTTP_
      # and upper cased
      headers["HTTP_#{key.upcase}"] = value
    end
    # in a real app there would be a whole lot more information
    # about the request, but we are gonna keep it simple
    {
      'REQUEST_METHOD' => method,
      'PATH_INFO' => path,
      'QUERY_STRING' => query
    }.merge(headers)
  end

  def strip(str)
    str&.sub("\r\n", '')
  end
end
