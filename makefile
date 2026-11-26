.DEFAULT_GOAL := build

CONFIGURATION ?= debug
SWIFT_PATHS ?= Package.swift Sources Tests
APP := .build/WiFiButler.app
SIGN_IDENTITY ?= -

.PHONY: build test run lint complex format fmt apm_ci apm_audit

build:
	swift build --configuration $(CONFIGURATION)
	mkdir -p "$(APP)/Contents/MacOS"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp "$$(swift build --configuration $(CONFIGURATION) --show-bin-path)/WiFiButler" "$(APP)/Contents/MacOS/WiFiButler"
	codesign --force --sign "$(SIGN_IDENTITY)" "$(APP)"

test:
	swift test

run: build
	open "$(APP)"

lint:
	xcrun swift-format lint --strict --recursive $(SWIFT_PATHS)

complex:
	swiftlint lint --config .swiftlint.yml $(SWIFT_PATHS)

fmt format:
	xcrun swift-format format --in-place --recursive $(SWIFT_PATHS)

apm_ci:
	apm install --policy ./apm-policy.yml --frozen

apm_audit:
	apm audit --ci --policy ./apm-policy.yml
