---
name: Feature request
about: Suggest an idea for this project
title: ''
labels: enhancement
assignees: ''

---

SUMMARY: [Quick description of the feature]

MOTIVATION: [Why do we need this feature?]

SCENARII: [Give some scenarii using Gherkin style]

Feature: Guess the word

# The first example has two steps
  Scenario: Maker starts a game
    When the Maker starts a game
    Then the Maker waits for a Breaker to join

# The second example has three steps
  Scenario: Breaker joins a game
    Given the Maker has started a game with the word "silky"
    When the Breaker joins the Maker's game
    Then the Breaker must guess a word with 5 characters
    
    
DETAILED DESIGN: [Describe the design. Any formalism, texts, diagrams, ... are welcome]

ALTERNATIVES: [Do we know alternative to this feature ?]

DRAWBACKS: [Do we know drawbacks to this feature?]

RELATED PRs:
- [ ] PR#1
- [ ] PR#2
