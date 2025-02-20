Feature: Test a variety of gherkin features

    Rule: Cucumber works only when implemented
    
    Background:
        * I am a background step
    
    Scenario Outline: Docstring and Examples
        Given a/an <implemented> cucumber
        Given a docstring:
        """
        Some long text
        """
        And a data table:
        | example_data |
        | whatever     |
        | 0            |
        When cucumber reads this file
        Then it should <work>
        Examples:
        | implemented   | work           |
        | unimplemented | print snippets |
        | pending       | be pending     |
        | flawed        | fail           |
        | implemented   | work           |

    Scenario: No Bullshit
        Given a/an implemented cucumber
        When cucumber reads this file
        Then it should work
