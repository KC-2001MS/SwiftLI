prefix ?= /usr/local
bindir = $(prefix)/bin
DOCC_TARGET = SwiftLI
DOCC_DIR = ./docs

build:
	swift build -c release --disable-sandbox

install: build
	install -d "$(bindir)"
	install ".build/release/sclt" "$(bindir)"

uninstall:
	rm -rf "$(bindir)/sclt"

clean:
	rm -rf .build

.PHONY: build install uninstall clean

docc:
	swift package --allow-writing-to-directory $(DOCC_DIR) \
		generate-documentation --target $(DOCC_TARGET) \
		--disable-indexing \
		--transform-for-static-hosting \
		--hosting-base-path $(DOCC_TARGET) \
		--output-path $(DOCC_DIR)

docc-preview:
	swift package --disable-sandbox preview-documentation --target $(DOCC_TARGET)

.PHONY: docc-preview docc
