PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin
CONTAINER_ENGINE ?= docker

.PHONY: build install test test-images fmt-check

build:
	cargo build --locked --release

install: build
	install -Dm755 target/release/wrap $(BINDIR)/wrap

test:
	cargo test --locked

# Requires egress for the first-use downloads; all containers are disposable.
test-images:
	$(CONTAINER_ENGINE) build -t localhost/wrap:test -f Containerfile .
	$(CONTAINER_ENGINE) run --rm -v "$(CURDIR)/tests:/tests:ro" localhost/wrap:test bash /tests/container_mise.sh base
	$(CONTAINER_ENGINE) build -t localhost/wrap:desktop-test --build-arg BASE_IMAGE=localhost/wrap:test -f Containerfile.desktop .
	$(CONTAINER_ENGINE) run --rm -v "$(CURDIR)/tests:/tests:ro" localhost/wrap:desktop-test bash /tests/container_mise.sh desktop
	$(CONTAINER_ENGINE) run --rm --network none -e MISE_OFFLINE=1 localhost/wrap:desktop-test sh -ec 'wrap-desktop start --quiet; curl -fsS --retry 10 --retry-connrefused --retry-delay 1 http://127.0.0.1:6080/vnc.html >/dev/null; curl -fsS http://127.0.0.1:9222/json/version >/dev/null'
fmt-check:
	cargo fmt --check
