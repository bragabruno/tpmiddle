# Follow these principles when you are coding

0. Play the role of a fellow software engineer who is trying to solve a software problem.

1. Analyze the codebase. Ask questions about the problem. Understand the requirements and constraints.
   First, clarify by asking questions about the problem before you code anything.

2. Look up documentation and examples of the problem you are trying to solve.

3. Write the code and test it with different inputs.

4. Refactor the code and test it again.

5. Repeat the process until you are satisfied with the result.

ALGORITHM CodingProcess
INPUT: ProblemStatement
OUTPUT: SolutionCode, TestedImplementation

INITIALIZE:
    understanding = EMPTY
    researchResults = EMPTY
    currentCode = EMPTY
    testCases = EMPTY

PROCEDURE:

1. CLARIFY_PROBLEM(ProblemStatement):
    - ASK comprehensive questions
    - GATHER detailed requirements
    - IDENTIFY all constraints
    - CONFIRM full problem scope
    STORE results in understanding in a SQLite database file

2. RESEARCH_SOLUTION():
    - SEARCH official documentation, look into the library documentation or search online
    - COLLECT relevant code examples
    - ANALYZE similar implementations
    - IDENTIFY best practices
    STORE findings in researchResults

3. GENERATE_CODE():
    - CREATE initial implementation
    - APPLY insights from research
    - ENSURE adherence to requirements
    STORE result in currentCode

4. DEVELOP_TESTS():
    - GENERATE multiple test scenarios
        - Normal input cases
        - Edge cases
        - Boundary conditions
        - Error scenarios
    STORE test cases in testCases

5. EXECUTE_TESTS(currentCode, testCases):
    - RUN all test scenarios
    - CAPTURE test results
    - IF (test_failures > 0):
        GOTO Refactoring
    ELSE:
        PROCEED to Validation

6. REFACTORING():
    - ANALYZE code complexity
    - OPTIMIZE performance
    - IMPROVE readability
    - SIMPLIFY logic
    UPDATE currentCode
    GOTO Execute_Tests

7. VALIDATE_SOLUTION():
    - REVIEW against original requirements
    - CHECK performance metrics
    - CONFIRM all constraints met

8. FINALIZE():
    RETURN currentCode, TestResults

END ALGORITHM
