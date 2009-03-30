require File.join(File.dirname(__FILE__), "/../spec_helper")

module Net
  describe HTTP, 'post_quick' do
    before :all do
      server = File.join(File.dirname(__FILE__), 'server.rb')
      Thread.new { systemu("ruby #{server}") }
      sleep 5
    end

    it 'makes it easy to post' do
      Net::HTTP.post_quick(
        'http://localhost:4567/path',
        'data').should == 'response'
    end

    after :all do
      begin
        Net::HTTP.get_response 'localhost', '/halt', 4567
      rescue Interrupt
        # ok
      end
    end
  end
end
