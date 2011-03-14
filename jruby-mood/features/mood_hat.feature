Feature: Mood hat

  In order to get my feelings across
  As a passionate person
  I want to display my mood on my hat

  Scenario Outline: Changing mood
    Given I am <feeling_now>
    When I <change> my happiness
    Then I should be <feeling_next>

    Examples:
      | feeling_now | change   | feeling_next |

      | furious     | increase | unhappy      |
      | furious     | decrease | furious      |
      | unhappy     | increase | neutral      |
      | unhappy     | decrease | furious      |
      | neutral     | increase | happy        |
      | neutral     | decrease | unhappy      |
      | happy       | increase | ecstatic     |
      | happy       | decrease | neutral      |
      | ecstatic    | increase | ecstatic     |
      | ecstatic    | decrease | happy        |
