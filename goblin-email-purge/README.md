# Goblin Email Purge — Safe Starter Pack

A developer-oriented tool that scans IMAP inboxes for dating-related messages, identifies candidate services, and generates a safe cleanup plan. Designed to be non-destructive by default (dry run). Use with caution.

Features:
- IMAP scanning for dating provider emails
- List-Unsubscribe automation (GET/POST with fallback)
- OAuth token revocation for Google, Facebook, Apple (manual for Apple)
- Interactive review and decision persistence
- JSON reports and cleanup plans

Files:

- `cli.py` — Argparse CLI entrypoint
- `imap_scanner.py` — IMAP scan helper
- `oauth_revocation.py` — OAuth revocation helpers (Google/FB programmatic, Apple manual)
- `unsubscribe_helpers.py` — List-Unsubscribe parsing and HTTP/POST automation
- `cleanup_helpers.py` — Local device cleanup hints (macOS stubs)
- `report_generator.py` — Writes JSON report to ./reports/
- `config.example.yaml` — Example config file

Quickstart:

1. Copy files into a folder and cd there.
2. python -m venv venv && source venv/bin/activate
3. pip install -r requirements.txt
4. Copy `config.example.yaml` -> `config.yaml` and fill required vars
5. Run the app:

```bash
# Recommended: use the included run.sh to create a venv and install deps
./run.sh audit --config config.yaml
```

Or run directly if you already have a Python venv:

```bash
python cli.py audit --config config.yaml
```

Examples:

- Run interactively and confirm actions manually:

```bash
./run.sh audit --config config.yaml --interactive
```

- Attempt automatic unsubscribes (dry-run unless --force provided):

```bash
./run.sh audit --config config.yaml --auto-unsubscribe --force

Advanced tips:

- To apply decisions automatically (auto unsubscribe and revoke tokens for providers you pre-approved):

```bash
# You must create decisions.json; you can use the interactive review flow to produce it
./run.sh audit --config config.yaml --apply-approved --decisions-file decisions.json --force
Automate deletion and revocation only when you're confident: the tool is destructive when you pass `--force` and `--apply-approved`.

Safety:

- By default revocation and OS-cleanup steps run in dry-run; pass `--force` to actually attempt revocations.
- You are responsible for providing credentials for APIs per service.
Interactive and automation flags:

- `--interactive` — Start a guided interactive mode where you can open deletion links, perform unsubscribes, and confirm revocations.
- `--auto-unsubscribe` — Attempt automatic unsubscribes for messages with a List-Unsubscribe header. Respectful throttling and caution expected.

PyYAML & macOS notes:

- The project can optionally use `PyYAML` for parsing YAML config files. Some Python versions or macOS setups may require `libyaml` or a build toolchain to be installed to build the library from source.
- The included `run.sh` attempts to install `libyaml` via Homebrew to avoid building PyYAML from source on macOS. If you still encounter problems, run:

```bash
# Install system dependency (macOS)
brew install libyaml
python -m pip install --upgrade pip setuptools wheel
python -m pip install PyYAML
```

If PyYAML still doesn't install, it's optional — the CLI includes a fallback minimal parser for simple key:value configs.

Environment variables:

- `GMAIL_APP_PW` — Gmail app password for IMAP access. If using OAuth for Gmail, provide saved OAuth creds per provider.
- `GMAIL_ACCESS_TOKEN` — Optional OAuth access token that will be used to attempt revocation if present.
- `FB_ACCESS_TOKEN` — Facebook user access token used to delete permissions if present.

Set env vars before running the CLI if you want to attempt revocation on those providers:

```bash
export GMAIL_APP_PW="your-app-password"
export FB_ACCESS_TOKEN="your-facebook-user-token"
./run.sh audit --config config.yaml
```

Legal:

- This tool only automates allowed actions. It does not bypass authentication.
- It only scans inboxes you have access to and only attempts revocation via official SDKs/APIs.
