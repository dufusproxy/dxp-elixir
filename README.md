# dxp-elixir

## Running Tests

Tests are located in `core/test/`. From the project root:

```bash
# Run all tests
cd core && mix test

# Run a specific test file
cd core && mix test test/core/some_test.exs

# Run tests with coverage
cd core && mix test.coverage

# Run tests matching a pattern
cd core && mix test --only test_name_pattern
```

The test suite uses ExUnit and includes property-based tests via StreamData.