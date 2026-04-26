.PHONY: install install-dry install-force install-clean test test-unit test-integration lint help

BOOTSTRAP := ./bootstrap.sh

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Install"
	@echo "  install          Interactive install"
	@echo "  install-dry      Preview install (--dry-run --yes)"
	@echo "  install-force    Reinstall everything (--force --yes)"
	@echo "  install-clean    Wipe ~/.claude and reinstall (--clean --yes)"
	@echo ""
	@echo "Test"
	@echo "  test             Run full test suite"
	@echo "  test-unit        Run unit tests only"
	@echo "  test-integration Run integration tests only"
	@echo ""
	@echo "Lint"
	@echo "  lint             Run shellcheck on all scripts and hooks"

install:
	$(BOOTSTRAP)

install-dry:
	$(BOOTSTRAP) --dry-run --yes

install-force:
	$(BOOTSTRAP) --force --yes

install-clean:
	$(BOOTSTRAP) --clean --yes

test:
	@bash tests/run_tests.sh

test-unit:
	@bash tests/run_tests.sh --unit

test-integration:
	@bash tests/run_tests.sh --integration

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck not found. Install: brew install shellcheck"; exit 1; }
	@echo "Running shellcheck..."
	@shellcheck -x -S warning bootstrap.sh scripts/*.sh lib/common.sh hooks/*.sh
	@echo "All checks passed."
