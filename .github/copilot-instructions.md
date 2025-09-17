# macOS Scripts Repository

This repository contains lightweight, MDM-agnostic shell scripts designed for macOS enterprise environments. The scripts are modular, adaptable, and work with various MDM tools (Jamf, Intune, Kandji) or as standalone solutions.

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Repository Structure and Navigation
- **Root directory**: Contains shell scripts (.sh files) and documentation
- **Key files**:
  - `README.md` - Repository overview and purpose
  - `tailscale-automated-join.sh` - Main Tailscale automation script for macOS
- **No build system**: This is a collection of standalone shell scripts, not a compiled application

### Script Validation and Testing
- **ALWAYS validate scripts before committing changes**:
  - `shellcheck *.sh` - Takes <1 second, run with 60+ second timeout
  - `bash -n *.sh` - Syntax check, takes <1 second, run with 60+ second timeout
- **Script permissions**: Ensure executable scripts have proper permissions (`chmod +x script.sh`)
- **NEVER CANCEL validation commands** - they complete quickly but use conservative timeouts

### Development Workflow
- **No dependencies to install**: Scripts use standard Unix/macOS utilities
- **No build process**: Scripts are ready to run as-is
- **Testing approach**: Manual validation of script logic and syntax checking

### Required System Tools for Script Functionality
The scripts in this repository depend on macOS-specific commands and utilities:
- `scutil` - macOS system configuration utility
- `open` - macOS command to open applications
- `lsregister` - LaunchServices framework tool
- Standard Unix tools: `curl`, `sed`, `pgrep`, `pkill`, `sleep`

**IMPORTANT**: These scripts are designed for macOS and will not run properly on Linux development environments.

## Validation and Testing

### Script Validation Process
Always run these validation steps before making changes or commits:

1. **Syntax validation**: `bash -n script.sh` (immediate, use 60+ second timeout)
2. **Linting**: `shellcheck script.sh` (immediate, use 60+ second timeout)  
3. **Permission check**: `ls -la *.sh` to verify executable permissions

### Manual Testing Guidelines
**CRITICAL**: Since these are macOS-specific scripts, complete functional testing requires a macOS environment with:
- macOS 10.15+ with appropriate system permissions
- Tailscale application installed (for tailscale-automated-join.sh)
- Network access to Tailscale APIs
- Valid Tailscale OAuth credentials or auth keys

**Testing scenarios for tailscale-automated-join.sh**:
1. **Syntax and static analysis** (can be done in any environment):
   - Run `shellcheck tailscale-automated-join.sh`
   - Run `bash -n tailscale-automated-join.sh`
2. **Functional testing** (requires macOS):
   - Test with valid AUTH_KEY: Set AUTH_KEY variable and run script
   - Test OAuth flow: Set CLIENT_ID and CLIENT_SECRET and run script
   - Verify Tailscale connection: Check `tailscale status` after script completion
   - Test browser killing functionality during auth flow

### Common Development Tasks

#### Adding New Scripts
- Create script with `.sh` extension
- Add shebang: `#!/bin/bash`
- Make executable: `chmod +x script.sh`
- Add comprehensive header comments explaining purpose and usage
- Validate with shellcheck and syntax check

#### Modifying Existing Scripts
- **ALWAYS run syntax validation first**: `bash -n script.sh`
- **ALWAYS run shellcheck**: `shellcheck script.sh`
- Preserve existing functionality unless specifically changing it
- Update comments if logic changes
- Test on macOS if functional changes are made

## Timing and Performance Expectations

### Validation Commands (immediate execution)
- `shellcheck *.sh`: <1 second - **NEVER CANCEL, use 60+ second timeout**
- `bash -n *.sh`: <1 second - **NEVER CANCEL, use 60+ second timeout**
- File operations (ls, cat, etc.): Immediate

### Script Execution Times (macOS only)
- `tailscale-automated-join.sh`: 30-60 seconds depending on network and auth method
  - LaunchServices cache clear: 2-5 seconds
  - OAuth token retrieval: 5-15 seconds
  - Tailscale authentication: 10-30 seconds

## Repository Knowledge Base

### File Inventory
```
.
├── .github/
│   └── copilot-instructions.md (this file)
├── README.md (717 bytes)
└── tailscale-automated-join.sh (3601 bytes, executable)
```

### Key Script Details

#### tailscale-automated-join.sh
- **Purpose**: Automates Tailscale setup on macOS with MDM compatibility
- **Dependencies**: macOS system utilities, Tailscale app, network access
- **Configuration**: Supports AUTH_KEY or OAuth (CLIENT_ID/CLIENT_SECRET)
- **Key features**: 
  - Browser suppression to prevent GUI auth dialogs
  - LaunchServices cache clearing (avoids reboot requirement)
  - Ephemeral device registration with tags
- **Validation**: Passes shellcheck with no warnings

### Common Validation Commands
```bash
# Validate all scripts (run these before committing)
shellcheck *.sh
bash -n *.sh

# Check file permissions
ls -la *.sh

# View script without executing (safe on any platform)
cat tailscale-automated-join.sh
```

### Repository Patterns
- Scripts use consistent logging: `log() { echo "[script-name] $1"; }`
- Error handling with proper exit codes
- Configuration variables at top of scripts
- Comprehensive header comments with context links
- MDM-agnostic design principles

## Critical Notes

- **Platform specificity**: All scripts are macOS-specific and require macOS for functional testing
- **No CI/CD**: Repository has no automated testing or build pipelines
- **Manual validation required**: Changes must be tested manually on macOS systems
- **Network dependencies**: Scripts may require external API access (Tailscale, etc.)
- **Permissions**: Scripts may require elevated privileges or special macOS permissions

Always validate changes with shellcheck and syntax checking before committing, even if full functional testing isn't possible in the development environment.