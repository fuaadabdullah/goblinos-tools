#!/bin/bash
cd /Users/fuaadabdullah/ForgeMonorepo/tools/goblin-email-purge
source venv/bin/activate
export GMAIL_APP_PW='Atilla2025?#!'
python cli.py audit --config config.yaml --auto-unsubscribe
