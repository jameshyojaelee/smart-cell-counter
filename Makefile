DEST ?= platform=iOS Simulator,name=iPhone 16 Pro

.PHONY: generate build test open

generate:
	xcodegen generate

build: generate
	xcodebuild -project SmartCellCounter.xcodeproj -scheme SmartCellCounter -destination '$(DEST)' -quiet build

test: generate
	xcodebuild -project SmartCellCounter.xcodeproj -scheme SmartCellCounter -destination '$(DEST)' -quiet test

open: generate
	open SmartCellCounter.xcodeproj

