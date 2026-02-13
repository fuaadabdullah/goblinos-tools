---
title: DuckDNS Setup Guide
description: "How to configure DuckDNS for Goblin Assistant"
---

# DuckDNS Setup for Goblin Assistant

This guide explains how to give your Goblin Assistant backend a public domain using DuckDNS.

## What is DuckDNS?

DuckDNS is a free dynamic DNS service that provides you with a subdomain (e.g., `goblinos-assistant.duckdns.org`) that automatically points to your current public IP address. This is perfect for:

- Accessing your Goblin Assistant from anywhere
- Sharing your assistant with others
- Setting up webhooks that need a stable URL
- Testing SSL/TLS certificates

## Prerequisites

- A running Goblin Assistant backend (see `launchd/README.md`)
- Internet connection
- Port forwarding configured on your router (if needed)

## Quick Start

### 1. Get Your DuckDNS Subdomain and Token

1. Go to [https://www.duckdns.org](https://www.duckdns.org)
2. Sign in with GitHub, Google, Twitter, or Reddit
3. Create a new subdomain in the "domains" section
   - Suggested names: `goblinos-assistant`, `goblinOS-assistant`, `goblin-ai`, etc.
   - Choose any available name you like
4. Copy your token from the top of the page (you'll need this in the next step)

### 2. Run the Setup Wizard

```bash
./duckdns_setup.sh setup
```

The wizard will ask you for:
- Your DuckDNS subdomain (e.g., `goblinos-assistant`)
- Your DuckDNS token (from step 1)

### 3. Update Your IP Address

After setup, update DuckDNS with your current public IP:

```bash
./duckdns_setup.sh update
```

You should see:
```
[SUCCESS] DuckDNS updated successfully!
[INFO] Domain: goblinos-assistant.duckdns.org
[INFO] Public IP: xxx.xxx.xxx.xxx
```

### 4. Set Up Automatic Updates

Choose one of the following methods to keep your IP address updated:

#### Option A: Cron (Linux/macOS)

```bash
./duckdns_setup.sh cron
```

This creates a cron job that updates your IP every 5 minutes.

#### Option B: Launchd (macOS)

```bash
./duckdns_setup.sh launchd
```

This creates a launchd service that updates your IP every 5 minutes and survives reboots.

## Available Commands

```bash
# Run initial setup
./duckdns_setup.sh setup

# Manually update IP address
./duckdns_setup.sh update

# Check domain status and current IP
./duckdns_setup.sh status

# Install auto-update via cron (every 5 minutes)
./duckdns_setup.sh cron

# Install auto-update via launchd (macOS, every 5 minutes)
./duckdns_setup.sh launchd

# Show help
./duckdns_setup.sh help
```

## Port Forwarding

To make your Goblin Assistant accessible from the internet, you need to configure port forwarding on your router:

1. Find your router's admin interface (usually at 192.168.1.1 or 192.168.0.1)
2. Look for "Port Forwarding" or "Virtual Server" settings
3. Create a new port forwarding rule:
   - **External Port**: 8000 (or your preferred port)
   - **Internal Port**: 8000
   - **Internal IP**: Your computer's local IP address
   - **Protocol**: TCP

Now your assistant will be accessible at: `http://your-subdomain.duckdns.org:8000`

## SSL/TLS Setup (Optional)

For HTTPS access, you can use Let's Encrypt with certbot:

```bash
# Install certbot (example for Ubuntu/Debian)
sudo apt-get install certbot

# Get a certificate (standalone mode)
sudo certbot certonly --standalone -d your-subdomain.duckdns.org

# Or use DNS challenge for DuckDNS
# Install certbot-dns-duckdns plugin first
```

Then configure your backend to use the SSL certificate.

## Troubleshooting

### "Domain IP does not match your current public IP"

This is normal if:
- You just set up DuckDNS (DNS takes a few minutes to propagate)
- Your IP recently changed
- You haven't run the update command yet

Run `./duckdns_setup.sh update` to sync.

### Update returns "KO"

This usually means:
- Incorrect token
- Incorrect domain name
- Network connectivity issues

Run `./duckdns_setup.sh setup` again to reconfigure.

### Cannot access from internet

Check:
1. Port forwarding is correctly configured on your router
2. Your firewall allows incoming connections on port 8000
3. Your backend is listening on `0.0.0.0:8000` not `127.0.0.1:8000`
   - Update the launchd plist to use `--host 0.0.0.0` instead of `--host 127.0.0.1`

### Check if DNS is working

```bash
# Check what IP your domain points to
dig your-subdomain.duckdns.org

# Or use nslookup
nslookup your-subdomain.duckdns.org

# Test the domain
curl http://your-subdomain.duckdns.org:8000
```

## Configuration Files

- `.duckdns.conf` - Your DuckDNS credentials (not committed to git)
- `.duckdns.log` - Update history log
- `~/Library/LaunchAgents/com.goblinos.duckdns.plist` - macOS launchd service (if installed)

## Security Notes

⚠️ **Important Security Considerations:**

1. **Never commit `.duckdns.conf`** - It contains your DuckDNS token
2. **Protect your token** - Anyone with your token can update your domain
3. **Use HTTPS** - Set up SSL/TLS for secure communication
4. **Consider authentication** - Add authentication to your backend API
5. **Firewall rules** - Only expose necessary ports
6. **Rate limiting** - Implement rate limiting on your backend

## Suggested Domain Names

Available DuckDNS subdomain names you might try:
- `goblinos-assistant`
- `goblinOS-assistant`
- `goblin-ai-assistant`
- `goblin-forge-api`
- `goblinos-api`
- `forge-goblin`
- `my-goblin-assistant`

DuckDNS will tell you if a name is already taken.

## Advanced: Updating Backend Configuration

Once DuckDNS is set up, you may want to update your backend configuration:

1. Edit `launchd/com.forge.goblinos.backend.plist`
2. Change `--host 127.0.0.1` to `--host 0.0.0.0` to accept external connections
3. Add environment variable for your domain:
   ```bash
   export PUBLIC_DOMAIN=your-subdomain.duckdns.org
   ```
4. Reload the service:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.forge.goblinos.backend.plist
   launchctl load ~/Library/LaunchAgents/com.forge.goblinos.backend.plist
   ```

## Resources

- [DuckDNS Official Site](https://www.duckdns.org)
- [DuckDNS API Documentation](https://www.duckdns.org/spec.jsp)
- [Let's Encrypt](https://letsencrypt.org)
- [Port Forwarding Guide](https://portforward.com)

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review logs in `.duckdns.log`
3. Test manually with `curl` commands
4. Check DuckDNS status at https://www.duckdns.org

## Example Workflow

Here's a complete example of setting up DuckDNS for your Goblin Assistant:

```bash
# 1. Go to duckdns.org and create subdomain "goblinos-assistant"
# 2. Copy your token

# 3. Run setup (from repository root)
./duckdns_setup.sh setup
# Enter subdomain: goblinos-assistant
# Enter token: <your-token>

# 4. Update IP
./duckdns_setup.sh update

# 5. Check status
./duckdns_setup.sh status

# 6. Install auto-update (choose one)
./duckdns_setup.sh launchd  # macOS
# OR
./duckdns_setup.sh cron     # Linux/macOS

# 7. Configure port forwarding on your router
# External: 8000 -> Internal: 8000 (your computer's IP)

# 8. Update backend to accept external connections
# Edit launchd/com.forge.goblinos.backend.plist
# Change: --host 127.0.0.1 to --host 0.0.0.0

# 9. Test access
curl http://goblinos-assistant.duckdns.org:8000

# 10. Success! Your Goblin Assistant is now publicly accessible
```
