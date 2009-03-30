Feature: blog posting

  As a blogger
  I want to post from my iPhone
  So that I don't need to drag my laptop everywhere

  Scenario: short posts

    Given the blog "example" with user "me" and password "secret"

    When I add a post entitled "First post!"
    And I add a post entitled "Shark jump"

    # START:then
    Then the blog should have the following posts:
     | title       |
     | Shark jump  |
     | First post! |
    # END:then
