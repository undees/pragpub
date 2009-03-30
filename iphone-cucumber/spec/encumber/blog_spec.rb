require File.join(File.dirname(__FILE__), "/../spec_helper")

module SampleHelperMethods
  def sample(name)
    IO.read(File.join(File.dirname(__FILE__),
                      "#{name}.plist")).strip
  end
end

module Encumber
  describe Blog do
    include SampleHelperMethods

    it 'can count a list of blogs' do
      command  = sample 'view_command'
      response = sample 'blogs_response'

      Net::HTTP.should_receive(:post_quick).
        with('http://localhost:50000/', command).
        and_return(response)

      Blog.count.should == 1
    end
  end
end
