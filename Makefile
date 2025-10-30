DEST ?= platform=iOS Simulator,name=iPhone 16 Pro

.PHONY: generate build test lint ci open

generate:
	xcodegen generate

build: generate
	xcodebuild -project SmartCellCounter.xcodeproj -scheme SmartCellCounter -destination '$(DEST)' -quiet build

test: generate
	xcodebuild -project SmartCellCounter.xcodeproj -scheme SmartCellCounter -destination '$(DEST)' -quiet test

lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint --strict; \
	else \
		echo "swiftlint not installed; skipping"; \
	fi
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat Sources Tests --lint --swiftversion 5.9; \
	else \
		echo "swiftformat not installed; skipping"; \
	fi

ci: generate lint
	set -euo pipefail; \
	xcodebuild -project SmartCellCounter.xcodeproj -scheme SmartCellCounter -resolvePackageDependencies; \
	xcodebuild -project SmartCellCounter.xcodeproj \
		-scheme SmartCellCounter \
		-destination '$(DEST)' \
		-derivedDataPath DerivedData \
		-enableCodeCoverage YES \
		test; \
	xcrun xccov view --report --json DerivedData/Logs/Test/*.xcresult > coverage.json; \
	echo "Coverage report written to coverage.json"

open: generate
	open SmartCellCounter.xcodeproj
