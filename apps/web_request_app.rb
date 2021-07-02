require 'open-uri'

class WebRequestApp
  def call(env)
    body = URI.open('http://example.com').read
    [200, { "Content-Type" => "text/html" }, [body]]
  end
end
