require 'open-uri'

class WebRequestApp
  def call(env)
    # unfortunately, URI is not going to work with ractors yet
    # https://bugs.ruby-lang.org/issues/17592

    body = URI.open('http://example.com').read
    [200, { "Content-Type" => "text/html" }, [body]]
  end
end
