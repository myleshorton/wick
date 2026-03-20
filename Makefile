VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT  ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
DATE    ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS := -X github.com/myleshorton/wick/pkg/version.Version=$(VERSION) \
           -X github.com/myleshorton/wick/pkg/version.Commit=$(COMMIT) \
           -X github.com/myleshorton/wick/pkg/version.Date=$(DATE)

# Default: purego mode (requires libcronet at runtime, not at compile time)
TAGS ?= with_purego

.PHONY: build build-cgo clean test download-lib

build:
	go build -tags "$(TAGS)" -ldflags "$(LDFLAGS)" -o wick ./cmd/wick

# CGO build — links libcronet at compile time (macOS CI)
build-cgo:
	CGO_ENABLED=1 go build -ldflags "$(LDFLAGS)" -o wick ./cmd/wick

clean:
	rm -f wick

test:
	go test -tags "$(TAGS)" ./...

download-lib:
	bash scripts/download-libcronet.sh .
