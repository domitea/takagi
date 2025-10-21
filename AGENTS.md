# Repository Guidelines

## Project Structure & Module Organization
Takagi ships as a Ruby gem. Core runtime lives in `lib/`, with `lib/takagi/` grouping features by concern: networking (`network/`), server loops (`server/`, `reactor.rb`), message codecs (`message/`), and middleware helpers. Entry points such as `lib/takagi.rb` and `lib/takagi/client.rb` wire the API. CLI utilities reside in `bin/` (`bin/takagi-client`, `bin/takagi-test`, `bin/setup`). Specs live under `spec/`, with fast unit coverage in `spec/unit/` and interoperability notes in `spec/rfc/`. Shared type signatures are captured in `sig/` and governed by `Steepfile`. Configuration metadata lives in `takagi.gemspec`.

## Build, Test, and Development Commands
Run `bin/setup` once to install Bundler and project gems. Use `bundle exec rake spec` (Rake default) for the full RSpec suite. `bundle exec rubocop` enforces style, and `bundle exec rubocop -A` may auto-correct trivial issues. Type-check before publishing with `bundle exec steep check`. The sample clients in `bin/takagi-client` and `bin/takagi-test` illustrate running the networking stack against fixtures.

## Coding Style & Naming Conventions
Follow Ruby community defaults: two-space indentation, trailing commas only when RuboCop suggests, and snake_case for filenames plus CamelCase for classes/modules. Organize new files under the closest matching namespace in `lib/takagi/`. Prefer keyword arguments for clarity in public APIs, and keep log messages routed through `Takagi::Logger`. Always run RuboCop prior to opening a PR.

## Testing Guidelines
Author specs alongside code in the matching `spec/unit/` subtree; mirror the module path (`lib/takagi/network/socket.rb` → `spec/unit/network/socket_spec.rb`). Write behavior-focused `describe` blocks and ensure new observers or protocols also receive an integration example in `spec/rfc/`. Use `bundle exec rspec spec/unit/<path>` for quick feedback. Keep existing shared contexts up to date and add fixtures under `spec/support` when needed.

## Commit & Pull Request Guidelines
Commits use short, present-tense subjects (`Fix specs`, `Allow running TCP and UDP servers together`). Group related changes and include rationale in the body if behavior shifts. PRs should link the relevant roadmap or issue entry, summarize observable effects, note new commands or config toggles, and attach logs or screenshots when altering network flows. Confirm RuboCop, Steep, and the spec suite all pass before requesting review.
