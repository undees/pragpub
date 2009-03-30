# START:given
Given /^the blog "(.*)" with user "(.*)" and password "(.*)"$/ do
  | blog, user, password |

  Blog.empty!

  Blog.add \
    :host => "#{blog}.wordpress.com",
    :user => user,
    :pass => password
end
# END:given

When /^I add a post entitled "(.*)"$/ do
  | title |

  Blog.first.post :title => title
end

# START:then
Then /^the blog should have the following posts:$/ do
  | posts_table |

  Blog.first.posts.should == posts_table.hashes
end
# END:then
