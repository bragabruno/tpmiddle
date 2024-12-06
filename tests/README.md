# Testing Guidelines

This directory contains all test-related files for the TPMiddle application, organized by test type.

## Directory Structure

- `unit/` - Unit tests for individual components
- `integration/` - Integration tests for component interactions
- `e2e/` - End-to-end tests for complete workflows

## Testing Guidelines

### Unit Tests

- Test individual components in isolation
- Use mocks for external dependencies
- Focus on single responsibility
- Follow AAA pattern (Arrange-Act-Assert)
- Place tests in same directory structure as source code

### Integration Tests

- Test interaction between components
- Verify correct communication between modules
- Test database interactions
- Test external service integrations
- Focus on component boundaries

### End-to-End Tests

- Test complete user workflows
- Verify system behavior from user perspective
- Test UI interactions
- Validate system integration
- Focus on critical user paths

## Running Tests

```bash
# Run all tests
make test

# Run specific test suites
make test-unit
make test-integration
make test-e2e

# Run with coverage
make test-coverage
```

## Test Configuration

- Test configurations are stored in `config/test/`
- Mock data is stored in `tests/fixtures/`
- Use environment variables for sensitive data

## Best Practices

1. Write tests before code (TDD) when possible
2. Keep tests focused and concise
3. Use meaningful test names
4. Maintain test independence
5. Clean up test data
6. Don't test implementation details
7. Use appropriate assertions
8. Document test requirements

## Code Coverage

- Aim for minimum 80% coverage
- Focus on critical paths
- Don't sacrifice test quality for coverage
- Generate coverage reports during CI

## Continuous Integration

Tests are automatically run:

- On every pull request
- Before merging to main branch
- On release branches

Failed tests block merging to protected branches.
