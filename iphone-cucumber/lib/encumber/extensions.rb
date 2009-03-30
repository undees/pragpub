require 'net/http'

module Net
  class HTTP
    def self.post_quick(url, body)
      url = URI.parse url
      req = Net::HTTP::Post.new url.path
      req.body = body

      http = Net::HTTP.new(url.host, url.port)

      res = http.start do |sess|
        sess.request req
      end

      res.body
    end
  end
end
