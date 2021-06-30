class Request < Struct.new(:method, :path, :query, :headers); end
