# macOS Scripts by Adam Baali

This repository is a collection of lightweight, MDM-agnostic scripts designed to solve real-world problems on macOS.

The focus is on simplicity, portability, and practical use in enterprise environments. These scripts are modular and adaptable useful whether you're managing devices with Jamf, Intune, Kandji, or just need something standalone.

## Scripts

### `policy-retry.sh`
Retries failed or pending MDM policies using native macOS tools. Features intelligent retry logic with exponential backoff, works with any MDM solution, and includes comprehensive logging.

**Use cases:**
- Retry failed configuration profiles  
- Force policy refresh after network connectivity issues
- Recover from incomplete MDM enrollment states

**Usage:** `./policy-retry.sh [OPTIONS]` - Run with `--help` for full options.

### `tailscale-automated-join.sh`
Automated Tailscale setup script for macOS with MDM compatibility. Supports OAuth or direct auth keys, prevents GUI prompts, and includes LaunchServices cache workarounds.

## Why This Exists

MDM tools don’t always handle timing, app behavior, or edge cases well and sometimes scripting is the cleanest way to get something done reliably.

These scripts are here to help with that.

## Contributions

Feel free to fork, adapt, and use as needed. PRs welcome for anything that’s proven and useful.

— Adam
