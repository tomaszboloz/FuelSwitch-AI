# Contributing to FuelSwitch AI

Thank you for your interest in contributing to **FuelSwitch AI**!

## Code of Conduct
This project and everyone participating in it is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Development Setup
FuelSwitch AI is built with Swift 6 and SwiftUI for macOS 14.0+.

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0 (Sequoia)
- Xcode 15+ or Swift 6 toolchain
- Git

### Building & Testing
1. Clone the repository:
   ```bash
   git clone https://github.com/damtox/fuelswitch-ai.git
   cd fuelswitch-ai
   ```
2. Run the test suite:
   ```bash
   swift test
   ```
3. Build the macOS application bundle:
   ```bash
   make app
   ```
4. Run the local build:
   ```bash
   make run
   ```

## Development Guidelines
- **Clean Architecture**: Maintain clear separation between `FuelSwitchCore` (domain logic, networking, crypto, tokens) and `FuelSwitch` (SwiftUI views, AppKit status item & floating panels).
- **Naming Strictness**: Zero occurrences of legacy names. All identifiers and user-facing assets must use FuelSwitch naming.
- **Security First**: Never log plain access tokens or refresh tokens. Use `0600` POSIX permissions for local credential caches.
- **Test Coverage**: Write unit tests for any new parser, state machine, or CLI switcher logic.

## Submitting Pull Requests
1. Create a descriptive feature branch (`feature/your-feature-name`).
2. Verify all tests pass locally (`swift test`).
3. Verify legacy naming check passes:
   ```bash
   make test
   ```
4. Open a Pull Request referencing related issues.
