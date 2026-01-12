#!/usr/bin/env bash
# Quick Start Guide for DuckDNS Setup
# Run this script to see step-by-step instructions

cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║              DuckDNS Setup - Quick Start Guide                       ║
║         Give Your Goblin Assistant a Public Domain                   ║
╚══════════════════════════════════════════════════════════════════════╝

📋 Prerequisites:
   • Goblin Assistant backend running (see launchd/README.md)
   • Internet connection
   • 5 minutes of your time

🚀 Quick Start (4 Easy Steps):

   Step 1: Get Your DuckDNS Account
   ─────────────────────────────────
   1. Go to: https://www.duckdns.org
   2. Sign in with GitHub, Google, Twitter, or Reddit
   3. Create a subdomain (e.g., "goblinos-assistant")
   4. Copy your token from the top of the page

   Step 2: Run the Setup Wizard
   ─────────────────────────────
   $ ./duckdns_setup.sh setup

   You'll be asked for:
   • Your subdomain name (without .duckdns.org)
   • Your DuckDNS token

   Step 3: Update Your IP Address
   ───────────────────────────────
   $ ./duckdns_setup.sh update

   Step 4: Enable Auto-Updates
   ────────────────────────────
   Choose ONE:

   macOS:    $ ./duckdns_setup.sh launchd
   Linux:    $ ./duckdns_setup.sh cron

   ✓ Done! Your domain will auto-update every 5 minutes.

🌐 Accessing Your Goblin Assistant:

   Local:    http://127.0.0.1:8000
   Public:   http://your-subdomain.duckdns.org:8000

   ⚠️  For public access, you MUST:
      1. Configure port forwarding on your router
      2. Update backend to listen on 0.0.0.0 (not 127.0.0.1)

📖 Need More Help?

   • Full documentation: DUCKDNS_SETUP.md
   • Check status: ./duckdns_setup.sh status
   • Get help: ./duckdns_setup.sh help

🔧 Advanced Options:

   • Port forwarding guide in DUCKDNS_SETUP.md
   • SSL/TLS setup with Let's Encrypt
   • Backend configuration updates
   • Troubleshooting common issues

💡 Suggested Domain Names (if available):

   • goblinos-assistant
   • goblinOS-assistant  
   • goblin-ai-assistant
   • goblin-forge-api
   • goblinos-api
   • forge-goblin
   • my-goblin-assistant

🎉 That's it! You're ready to give your Goblin Assistant a public domain!

EOF
