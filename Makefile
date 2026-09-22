# tiny-g2p -- the Rust half of the model: a zero-dependency library, a CLI, and a
# wasm module, from one core with the weights embedded.
#
# The weights are exported by the training repo (github.com/robertbak/tiny_g2p),
# which is expected to sit beside this one; see README.md.

# Where the MFA dictionary lives. The training repo fetches it (`make lexicon`),
# so it is read from there rather than downloaded twice.
LEXICON ?= ../tiny_g2p/data/lexicons/polish_mfa.dict
BIN     := target/release/tinyg2p

.DEFAULT_GOAL := help

.PHONY: help
help: ## show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## build the binary (1.0 MiB, static)
	cargo build --release

.PHONY: test
test: ## unit, examples, parity and doc tests
	cargo test --release --workspace

.PHONY: check
check: ## the lints, as CI would run them
	cargo clippy --workspace --all-targets -- -D warnings

.PHONY: example
example: build ## what the tool does to real speech (examples/)
	$(BIN) predict --explain --lexicon examples/names.dict < examples/utterances.txt

.PHONY: miss-lexicon
miss-lexicon: build ## regenerate the exception dictionaries from the model's misses
	@test -f $(LEXICON) || { \
		echo "no lexicon at $(LEXICON)"; \
		echo "run 'make lexicon' in the training repo first, or set LEXICON=..."; \
		exit 1; }
	$(BIN) miss-lexicon --gold data/test_gold.tsv --out data/seed.dict
	$(BIN) miss-lexicon --lexicon $(LEXICON) --gold data/test_gold.tsv --out data/base.dict

.PHONY: wasm
wasm: ## build the wasm package and exercise it under node
	wasm-pack build --release --target nodejs --out-name tiny_g2p -d pkg-nodejs wasm
	node smoke.mjs

.PHONY: clean
clean: ## remove build artefacts
	cargo clean
	rm -rf pkg-nodejs
