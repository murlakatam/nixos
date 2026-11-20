## Goal-Driven Execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]

**After every edit**, check the changed files for type errors with the project's own checker before claiming the step is done. Zero new errors is the type-safety bar. Type checks catch type errors only — they do NOT verify behaviour. Behavioural verification (run the binary, exercise the API, drive the browser) is separate and equally required.
