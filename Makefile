SHELL_FILES := $(shell find bin config lib manifests scripts tests -type f -name '*.sh' 2>/dev/null)
JSON_FILES := $(shell find config -type f -name '*.json' 2>/dev/null)

.PHONY: check lint test integration verify-releases

check: lint test

lint:
	shellcheck $(SHELL_FILES) bootstrap.sh install.sh
	@for file in $(JSON_FILES); do jq -e . "$$file" >/dev/null; done
	@awk -F '\t' '!/^#/ && NF && NF != 11 { print FILENAME ":" FNR ": expected 11 TSV fields, got " NF; failed=1 } END { exit failed }' manifests/release-tools.tsv

test:
	./tests/test-cli.sh
	./tests/test-idempotence.sh
	./tests/test-azure-source.sh
	./tests/test-checkout.sh
	./tests/test-release-source.sh
	./tests/test-manifests.sh
	python3 ./tests/test-renovate.py

integration:
	./tests/integration.sh

verify-releases:
	./tests/test-release-urls.sh
