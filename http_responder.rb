class HttpResponder
  def self.call(conn_sock, status, headers, body)
    # status line
    status_text = {
      200 => 'OK',
      404 => 'Not Found'
    }[status]
    conn_sock.send("HTTP/1.1 #{status} #{status_text}\r\n", 0)

    # headers
    conn_sock.send("Content-Length: #{body.sum(&:length)}\r\n", 0)
    headers.each_pair do |name, value|
      conn_sock.send("#{name}: #{value}\r\n", 0)
    end
    conn_sock.send("Connection: close\r\n", 0)
    conn_sock.send("\r\n", 0)

    # body
    body.each do |chunk|
      conn_sock.send(chunk, 0)
    end
  end
end
