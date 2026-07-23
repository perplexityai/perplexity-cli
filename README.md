# pplx

Perplexity's Search API in your terminal. `pplx` gives you grounded web search results and clean page content as JSON, built for both humans and coding agents.

## Install

```sh
curl -fsSL https://github.com/perplexityai/perplexity-cli/releases/latest/download/install.sh | sh
```

The installer downloads the binary for your platform, verifies its SHA-256 checksum, and installs it to `~/.local/bin/pplx`. No sudo. Set `PPLX_INSTALL_PATH` to install somewhere else.

### Manual install

Download the binary for your platform and `SHA256SUMS` from the [latest release](https://github.com/perplexityai/perplexity-cli/releases/latest), then verify and install:

```sh
grep pplx-aarch64-apple-darwin.bin SHA256SUMS | shasum -a 256 -c -
chmod +x pplx-aarch64-apple-darwin.bin
mv pplx-aarch64-apple-darwin.bin ~/.local/bin/pplx
```

On Linux, use `sha256sum -c -` instead of `shasum -a 256 -c -`.

### Supported platforms

| Platform              | Release asset                   |
| --------------------- | ------------------------------- |
| macOS (Apple Silicon) | `pplx-aarch64-apple-darwin.bin` |
| Linux x86_64          | `pplx-x86_64-linux-gnu.bin`     |
| Linux arm64           | `pplx-aarch64-linux-gnu.bin`    |

## Authentication

Get an API key at [perplexity.ai/account/api](https://www.perplexity.ai/account/api). Then either export it:

```sh
export PERPLEXITY_API_KEY=pplx-...
```

or store it once:

```sh
pplx auth login
```

`PERPLEXITY_API_KEY` takes precedence over the stored key when both are set.

## Usage

Every command prints JSON to stdout, so results pipe cleanly into `jq` and drop straight into agent tool calls.

### Web search

```sh
pplx search web "rust async runtimes"
pplx search web "rust programming" -n 5
pplx search web "query" "related query 1" "related query 2"
pplx search web "model releases" --domains wikipedia.org,arxiv.org
pplx search web "openai news" --recency-filter week
pplx search web "openai news" --published-after-date 3/1/2026 --published-before-date 3/5/2026
```

Output is `{ hits: [{ url, title, domain, snippet, ... }], total }`. Common flags (see `pplx search web --help` for the full list):

| Flag                                                  | Effect                                        |
| ----------------------------------------------------- | --------------------------------------------- |
| `-n, --limit <LIMIT>`                                  | Number of results (default: 10)               |
| `--country <COUNTRY>`                                  | Country code (default: US)                    |
| `--domains` / `--excluded-domains`                     | Comma-separated domain filters                |
| `--recency-filter <WINDOW>`                            | Relative window: hour, day, week, month, year |
| `--published-after-date` / `--published-before-date`   | Publication-date bounds (MM/DD/YYYY)          |
| `--search-context-size <SIZE>`                         | low, medium, or high                          |
| `--output-dir <DIR>`                                   | Also save the full result set to a JSON file  |
| `--stdout-preview[=<CHARS>]`                           | Truncate long string fields in stdout         |

### Content fetch

```sh
pplx content fetch https://example.com
pplx content fetch https://example.com --html
pplx content fetch https://example.com --no-cache
```

Returns cleaned page content plus metadata: title, description, authors, published date, domain, and paywall/cache flags. `--html` adds the raw page source in a `raw_html` field, and `--no-cache` forces a live fetch instead of a cache lookup.

## Updating

Re-run the install one-liner to get the latest version; it replaces the installed binary in place.

## Environment variables

| Variable                | Purpose                                                            |
| ----------------------- | ------------------------------------------------------------------ |
| `PERPLEXITY_API_KEY`    | API key; takes precedence over the key stored by `pplx auth login` |
| `PPLX_OUTPUT_DIR`       | Default directory for saved search and fetch results               |
| `PPLX_INSTALL_PATH`     | `install.sh`: install target (default: `~/.local/bin/pplx`)        |
| `PPLX_INSTALL_BASE_URL` | `install.sh`: release repository base URL                          |

## Versioning

Releases in this repository are semver-tagged (`vX.Y.Z`). `pplx --version` prints a date-stamped build version in the form `YYYY.MM.DD.<build>+<sha>` (for example `2026.07.20.1784555998+174b21c`) identifying the exact build. Each release's `manifest.json` asset ties the two together by recording the build version alongside the release tag.

## Uninstall

```sh
rm ~/.local/bin/pplx ~/.config/pplx/pplx-receipt.json
```

If present, also remove the stored API key in `~/.config/perplexity/credentials.json` (Linux) or `~/Library/Application Support/perplexity/credentials.json` (macOS).
