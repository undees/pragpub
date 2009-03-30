require 'tagz'
require 'rexml/document'
require 'enumerator'

module Encumber
  class Blog
    # Wraps a blog by its position on the list
    # (1st, 2nd, etc.)
    def initialize(order)
      @order = order
    end

    Posts   = '//UITableViewCell[text="Posts"]'
    NewPost = '/./descendant::UIPushButton[2]'
    BlogTitle = '/./descendant::UITextField[3]'
    BlogText = '/./descendant::UITextField[5]'
    Done = '//UINavigationButton[title="Done"]'
    Save = '//UINavigationButton[title="Save"]'
    OK =  '//UIThreePartButton[title="OK"]'
    BackToBlog = '//WPNavigationLeftButtonView[title="Blog"]'
    BackHome = '//WPNavigationLeftButtonView[title="Home"]'

    def post(params)
      title = params[:title] || raise('Need title')

      Blog.press Blog.nth_blog(@order),
                 Posts,
                 NewPost

      Blog.set_field BlogTitle, title

      Blog.set_field BlogText,
                     '',
                     Done

      Blog.press Save,
                 OK,
                 BackToBlog,
                 BackHome
    end

    LocalDrafts = '//UITableViewCell[text="Local Drafts"]'
    Back = '//UINavigationItemButtonView'

    def posts
      Blog.press Blog.nth_blog(@order),
                 Posts,
                 LocalDrafts

      response = Blog.command 'outputView'

      doc = REXML::Document.new response

      result = REXML::XPath.match(doc, '//UITableViewCell').map do |e|
        {'title' => e.elements['text'].text}
      end

      Blog.press Back,
                 BackToBlog,
                 BackHome

      result
    end

    # START:empty
    BlogSettings  = '/./descendant::UIButton[1]'
    RemoveBlog    = '/./descendant::UIRoundedRectButton'
    ConfirmRemove = '//UIThreePartButton[title="Remove"]'

    def Blog.empty!
      count.times do
        press BlogSettings,
              RemoveBlog,
              ConfirmRemove
      end
    end
    # END:empty

    SetupBlog = '//WPActivityIndicatorTVCell[text="Set up your blog"]'
    ConfirmAdd = '//UINavigationButton'

    def Blog.add(params)
      values = [:host, :user, :pass].map do |key|
        params[key] || raise("Need #{key}")
      end

      press SetupBlog

      values.each_with_index do |value, index|
        set_field Blog.nth_field(index + 1), value
      end

      press ConfirmAdd

      sleep 5
    end

    def Blog.first
      Blog.new 1
    end

    BlogButtons = '//UIActivityIndicatorView/following-sibling::UILabel[position()=1]'

    def Blog.count
      response = command 'outputView'

      doc = REXML::Document.new response

      REXML::XPath.match(doc, BlogButtons).reject do |e|
        e.elements['text'].text == '(null)'
      end.length
    end

    private

    # Assembles an XML snippet representing a Bromine command,
    # and sends it to the iPhone.
    def Blog.command(name, *params)
      command = Tagz.tagz do
        plist_(:version => 1.0) do
          dict_ do
            key_ 'command'
            string_ name
            params.each_cons(2) do |k, v|
              key_ k
              string_ v
            end
          end
        end
      end

      Net::HTTP.post_quick \
        'http://localhost:50000/', command
    end

    # Taps a series of GUI elements, each of which
    # is represented by an XPath expression.
    def Blog.press(*args)
      args.each do |xpath|
        command 'simulateTouch', 'viewXPath', xpath
        sleep 1
      end
    end

    # Sets the specified XPath text field
    # to the given value, with an optional
    # custom return key.
    def Blog.set_field(xpath, text, accept = '//UIKeyboardReturnKeyView')
      press xpath
      command 'setText', 'viewXPath', xpath, 'text', text
      sleep 1
      press accept
    end

    # Returns an XPath expression
    # for a top-level blog control.
    def Blog.nth_blog(n)
      "/./descendant::UILabel[#{n}]"
    end

    # Returns an XPath expression
    # for a text field in the UI.
    def Blog.nth_field(n)
      "/./descendant::UITextField[#{n}]"
    end
  end
end
