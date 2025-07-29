prefix ?= /usr/local
bindir = $(prefix)/bin
DOCC_TARGET = SwiftLI
DOCC_DIR = ./docs

build:
	swift build -c release --disable-sandbox

install: build
	sudo install -d "$(bindir)"
	sudo install ".build/release/sclt" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/sclt"

clean:
	rm -rf .build

.PHONY: build install uninstall clean
