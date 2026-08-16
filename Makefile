SHELL := /bin/bash

include project.mk

export APP_ID
export APPLE_TEAM_ID
export APP_NAME
export ANDROID_APPLICATION_ID
export ANDROID_NAMESPACE
export IOS_BUNDLE_ID
export MACOS_BUNDLE_ID
export TEST_BUNDLE_SUFFIX

FLUTTER ?= flutter
CARGO ?= cargo
CARGO_NDK ?= cargo ndk
RUST_DIR := rust
ANDROID_JNILIBS := android/app/src/main/jniLibs
ANDROID_ARM64_DIR := $(ANDROID_JNILIBS)/arm64-v8a
RUST_RELEASE_DIR := $(RUST_DIR)/target/release
SETUP_SCRIPT := tool/setup-project.sh
APPLE_BUILD_SCRIPT := tool/build-apple-native.sh
CONFIGURE_IDS_SCRIPT := tool/configure-identifiers.sh
W4_VALIDATION_SCRIPT := tool/w4-desktop-validation.sh
DEVICE ?=

.PHONY: help doctor show-config configure-identifiers setup setup-common setup-android setup-apple bootstrap \
	pub-get format-check analyze test-fast flutter-test rust-fetch rust-format-check rust-clippy rust-check rust-test rust-build \
	scripts-check ci-fast preflight test check validate \
	w4-validation-preflight w4-validation-automated \
	android-arm64 android-native macos-native ios-native apple-native \
	run run-android run-macos run-ios ios-build-nosign \
	clean clean-rust clean-flutter distclean

.DEFAULT_GOAL := help

help: ## Show available targets
	@echo "Nixin Studio V8 - Flutter + Rust FFI"
	@echo
	@echo "Usage: make <target> [DEVICE=<flutter-device-id>] [APP_ID=...] [APPLE_TEAM_ID=...]"
	@echo
	@awk 'BEGIN {FS = ":.*## "; printf "Targets:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

show-config: ## Show resolved project identifiers
	@echo "APP_NAME=$(APP_NAME)"
	@echo "APP_ID=$(APP_ID)"
	@echo "ANDROID_APPLICATION_ID=$(ANDROID_APPLICATION_ID)"
	@echo "ANDROID_NAMESPACE=$(ANDROID_NAMESPACE)"
	@echo "IOS_BUNDLE_ID=$(IOS_BUNDLE_ID)"
	@echo "MACOS_BUNDLE_ID=$(MACOS_BUNDLE_ID)"
	@echo "APPLE_TEAM_ID=$(APPLE_TEAM_ID)"
	@echo "TEST_BUNDLE_SUFFIX=$(TEST_BUNDLE_SUFFIX)"

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
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		echo; echo "== Xcode =="; xcodebuild -version; \
	fi
	@echo
	@echo "== Flutter devices =="
	@$(FLUTTER) devices

configure-identifiers: ## Apply identifiers/signing from project.mk or command-line overrides
	@bash $(CONFIGURE_IDS_SCRIPT)

setup: ## Bootstrap project dependencies and native tooling for this host
	@bash $(SETUP_SCRIPT) all

bootstrap: setup ## Alias for setup

setup-common: ## Bootstrap Flutter/Rust dependencies only
	@bash $(SETUP_SCRIPT) common

setup-android: ## Install/check cargo-ndk and Rust Android arm64 target
	@bash $(SETUP_SCRIPT) android

setup-apple: ## Configure signing and install/check macOS+iOS Rust/Xcode tools
	@bash $(SETUP_SCRIPT) apple

pub-get: ## Run flutter pub get
	$(FLUTTER) pub get

format-check: ## Check Dart formatting without modifying files
	@paths="lib test"; if [ -d integration_test ]; then paths="$$paths integration_test"; fi; dart format --output=none --set-exit-if-changed $$paths

analyze: ## Run Flutter static analysis
	$(FLUTTER) analyze --fatal-infos

test-fast: ## Run fast Flutter unit/widget tests
	$(FLUTTER) test test

flutter-test: ## Run all standard Flutter tests
	$(FLUTTER) test

rust-fetch: ## Download Rust dependencies without building
	cd $(RUST_DIR) && $(CARGO) fetch

rust-format-check: ## Check Rust formatting without modifying files
	cd $(RUST_DIR) && $(CARGO) fmt --all -- --check

rust-clippy: ## Run Rust clippy with warnings denied
	cd $(RUST_DIR) && $(CARGO) clippy --locked --all-targets -- -D warnings

rust-check: ## Run cargo check for raw-engine
	cd $(RUST_DIR) && $(CARGO) check --locked

rust-test: ## Run Rust unit tests
	cd $(RUST_DIR) && $(CARGO) test --locked

rust-build: ## Build native Rust library in release mode for the host
	cd $(RUST_DIR) && $(CARGO) build --release --locked

scripts-check: ## Syntax-check repository shell scripts
	@bash -n tool/*.sh

ci-fast: pub-get scripts-check format-check analyze test-fast rust-format-check rust-clippy rust-check ## Match the cheap PR gate locally
	@echo
	@echo "Fast CI preflight PASS"

preflight: ci-fast ## Recommended command before pushing


test: rust-test flutter-test ## Run all Rust and Flutter tests

check: rust-format-check rust-clippy rust-check analyze ## Run Rust + Flutter static checks

validate: pub-get scripts-check format-check rust-format-check rust-clippy rust-check rust-test analyze flutter-test ## Full local validation gate
	@echo
	@echo "Nixin validation PASS"

w4-validation-preflight: ## Record host/toolchain evidence before W4 physical desktop validation
	@FLUTTER_CMD="$(FLUTTER)" CARGO_CMD="$(CARGO)" bash $(W4_VALIDATION_SCRIPT) preflight

w4-validation-automated: ## Run focused W4 automated gates and capture evidence
	@FLUTTER_CMD="$(FLUTTER)" CARGO_CMD="$(CARGO)" bash $(W4_VALIDATION_SCRIPT) automated

android-arm64: configure-identifiers ## Build raw-engine .so for Android arm64-v8a
	@command -v cargo-ndk >/dev/null 2>&1 || { echo "ERROR: cargo-ndk is required. Run: make setup-android"; exit 1; }
	@mkdir -p $(ANDROID_ARM64_DIR)
	cd $(RUST_DIR) && $(CARGO_NDK) -t arm64-v8a -o ../$(ANDROID_JNILIBS) build --release
	@test -f $(ANDROID_ARM64_DIR)/libraw_engine.so || { echo "ERROR: $(ANDROID_ARM64_DIR)/libraw_engine.so was not produced"; exit 1; }
	@echo "Built $(ANDROID_ARM64_DIR)/libraw_engine.so"

android-native: android-arm64 ## Alias for the currently validated Android ABI

macos-native: configure-identifiers ## Build universal macOS Rust static library
	@bash $(APPLE_BUILD_SCRIPT) macos

ios-native: configure-identifiers ## Build iOS device + simulator Rust static libraries
	@bash $(APPLE_BUILD_SCRIPT) ios

apple-native: configure-identifiers ## Build all macOS and iOS Rust native libraries
	@bash $(APPLE_BUILD_SCRIPT) all

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

run-macos: macos-native ## Build/link Rust static library, then run macOS app
	@if [ "$$(uname -s)" != "Darwin" ]; then echo "ERROR: run-macos requires macOS"; exit 1; fi
	$(FLUTTER) run -d macos

run-ios: ios-native ## Build/link Rust libraries, then run iOS device/simulator; DEVICE required
	@if [ -z "$(DEVICE)" ]; then \
		echo "ERROR: pass the iOS device id, e.g. make run-ios DEVICE=<id>"; \
		$(FLUTTER) devices; \
		exit 1; \
	fi
	$(FLUTTER) run -d "$(DEVICE)"

ios-build-nosign: ios-native ## Build iOS app without code signing to validate native linkage
	$(FLUTTER) build ios --release --no-codesign

clean-rust: ## Remove Rust build artifacts
	cd $(RUST_DIR) && $(CARGO) clean

clean-flutter: ## Remove Flutter build artifacts
	$(FLUTTER) clean

clean: clean-flutter clean-rust ## Clean Flutter, Rust and generated native libraries
	@rm -f ./libraw_engine.dylib ./libraw_engine.so ./raw_engine.dll
	@rm -rf $(ANDROID_JNILIBS) ios/Native macos/Native

distclean: clean ## Clean generated dependencies as well
	@rm -rf .dart_tool
	@echo "distclean complete"
