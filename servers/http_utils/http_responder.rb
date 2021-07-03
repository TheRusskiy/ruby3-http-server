# frozen_string_literal: true

class HttpResponder
  STATUS_MESSAGES = {
    100 => 'Continue',
    101 => 'Switching Protocols',
    200 => 'OK',
    201 => 'Created',
    202 => 'Accepted',
    203 => 'Non-Authoritative Information',
    204 => 'No Content',
    205 => 'Reset Content',
    206 => 'Partial Content',
    207 => 'Multi-Status',
    300 => 'Multiple Choices',
    301 => 'Moved Permanently',
    302 => 'Found',
    303 => 'See Other',
    304 => 'Not Modified',
    305 => 'Use Proxy',
    307 => 'Temporary Redirect',
    400 => 'Bad Request',
    401 => 'Unauthorized',
    402 => 'Payment Required',
    403 => 'Forbidden',
    404 => 'Not Found',
    405 => 'Method Not Allowed',
    406 => 'Not Acceptable',
    407 => 'Proxy Authentication Required',
    408 => 'Request Timeout',
    409 => 'Conflict',
    410 => 'Gone',
    411 => 'Length Required',
    412 => 'Precondition Failed',
    413 => 'Request Entity Too Large',
    414 => 'Request-URI Too Large',
    415 => 'Unsupported Media Type',
    416 => 'Request Range Not Satisfiable',
    417 => 'Expectation Failed',
    422 => 'Unprocessable Entity',
    423 => 'Locked',
    424 => 'Failed Dependency',
    426 => 'Upgrade Required',
    428 => 'Precondition Required',
    429 => 'Too Many Requests',
    431 => 'Request Header Fields Too Large',
    451 => 'Unavailable For Legal Reasons',
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    505 => 'HTTP Version Not Supported',
    507 => 'Insufficient Storage',
    511 => 'Network Authentication Required',
  }.freeze

  # status: int
  # headers: Hash
  # body: array of strings
  def self.call(conn, status, headers, body)
    # status line
    status_text = STATUS_MESSAGES[status]
    conn.send("HTTP/1.1 #{status} #{status_text}\r\n", 0)

    # headers
    # we need to tell how long the body is before sending anything,
    # this way the remote client knows when to stop reading
    conn.send("Content-Length: #{body.sum(&:length)}\r\n", 0)
    headers.each_pair do |name, value|
      conn.send("#{name}: #{value}\r\n", 0)
    end

    # tell that we don't want to keep the connection open
    conn.send("Connection: close\r\n", 0)

    # separate headers from body with an empty line
    conn.send("\r\n", 0)

    # body
    body.each do |chunk|
      conn.send(chunk, 0)
    end
  end
end
