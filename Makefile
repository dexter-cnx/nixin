SHELL := /bin/bash

FLUTTER ?= flutter
CARGO ?= cargo
CARGO_NDK ?= cargo ndk
RUST_DIR := rust
ANDROID_JNILIBS := android/app/src/main/jniLibs
ANDROID_ARM64_DIR := $(ANDROID_JNILIBS)/arm64-v8a
RUST_RELEASE_DIR := $(RUST_DIR)/target/release
SETUP_SCRIPT := tool/setup-project.sh
DEVICE ?=

.PHONY: help doctor setup setup-common setup-android bootstrap pub-get rust-fetch rust-check rust-test rust-build \
	analyze flutter-test test check validate \
	android-arm64 android-native run run-android run-macos \
	clean clean-rust clean-flutter distclean

.DEFAULT_GOAL := help

help: ## Show available targets
	@echo "Nixin Studio V8 - Flutter + Rust FFI"
	@echo
	@echo "Usage: make <target> [DEVICE=<flutter-device-id>]"
	@echo
	@awk 'BEGIN {FS = ":.*## "; printf "Targets:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

doctor: ## Show Flutter/Rust/native build tool versions
	@echo "== Flutter =="
	@$(FLUTTER) --version
	@echo
	@echo "== Rust =="
	@$(CARGO) --version
	@rustc --version
	@echo
	@echo "== cargo-ndk =="
	@if command -v cargo-ndk >/dev/null 2>&1; then cargo-ndk --version; else echo "cargo-ndk not installed (needed for Android native builds)"; fi
	@echo
	@echo "== Flutter devices =="
	@$(FLUTTER) devices

setup: ## Bootstrap project dependencies and Android native tooling
	@bash $(SETUP_SCRIPT) all

bootstrap: setup ## Alias for setup

setup-common: ## Bootstrap Flutter/Rust dependencies without Android cargo-ndk
	@bash $(SETUP_SCRIPT) common

setup-android: ## Install/check cargo-ndk and Rust Android arm64 target
	@bash $(SETUP_SCRIPT) android

pub-get: ## Run flutter pub get
	$(FLUTTER) pub get

rust-fetch: ## Download Rust dependencies without building
	cd $(RUST_DIR) && $(CARGO) fetch

rust-check: ## Run cargo check for raw-engine
	cd $(RUST_DIR) && $(CARGO) check

rust-test: ## Run Rust unit tests
	cd $(RUST_DIR) && $(CARGO) test

rust-build: ## Build native Rust library in release mode for the host
	cd $(RUST_DIR) && $(CARGO) build --release

analyze: ## Run Flutter static analysis
	$(FLUTTER) analyze

flutter-test: ## Run Flutter tests
	$(FLUTTER) test

test: rust-test flutter-test ## Run all Rust and Flutter tests

check: rust-check analyze ## Run fast Rust + Flutter checks

validate: pub-get rust-check rust-test analyze flutter-test ## Full local validation gate
	@echo
	@echo "Nixin validation PASS"

android-arm64: ## Build raw-engine .so for Android arm64-v8a
	@command -v cargo-ndk >/dev/null 2>&1 || { echo "ERROR: cargo-ndk is required. Run: make setup-android"; exit 1; }
	@mkdir -p $(ANDROID_ARM64_DIR)
	cd $(RUST_DIR) && $(CARGO_NDK) -t arm64-v8a -o ../$(ANDROID_JNILIBS) build --release
	@test -f $(ANDROID_ARM64_DIR)/libraw_engine.so || { echo "ERROR: $(ANDROID_ARM64_DIR)/libraw_engine.so was not produced"; exit 1; }
	@echo "Built $(ANDROID_ARM64_DIR)/libraw_engine.so"

android-native: android-arm64 ## Alias for the currently validated Android ABI

run: ## Run Flutter; optionally pass DEVICE=<id>
	@if [ -n "$(DEVICE)" ]; then \
		$(FLUTTER) run -d "$(DEVICE)"; \
	else \
		$(FLUTTER) run; \
	fi

run-android: android-arm64 ## Build Android Rust library, then run Flutter; DEVICE optional
	@if [ -n "$(DEVICE)" ]; then \
		$(FLUTTER) run -d "$(DEVICE)"; \
	else \
		$(FLUTTER) run; \
	fi

run-macos: rust-build ## Build host Rust library and run macOS Flutter app
	@if [ "$$(uname -s)" != "Darwin" ]; then echo "ERROR: run-macos requires macOS"; exit 1; fi
	@if [ ! -f "$(RUST_RELEASE_DIR)/libraw_engine.dylib" ]; then echo "ERROR: Rust dylib not found"; exit 1; fi
	@cp "$(RUST_RELEASE_DIR)/libraw_engine.dylib" ./libraw_engine.dylib
	$(FLUTTER) run -d macos

clean-rust: ## Remove Rust build artifacts
	cd $(RUST_DIR) && $(CARGO) clean

clean-flutter: ## Remove Flutter build artifacts
	$(FLUTTER) clean

clean: clean-flutter clean-rust ## Clean Flutter and Rust build artifacts
	@rm -f ./libraw_engine.dylib ./libraw_engine.so ./raw_engine.dll
	@rm -rf $(ANDROID_JNILIBS)

distclean: clean ## Clean generated dependencies as well
	@rm -rf .dart_tool
	@echo "distclean complete"
