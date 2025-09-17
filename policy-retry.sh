#!/bin/bash

# ============================================
# macOS Policy Retry Script for Enterprise MDM
#
# Retries failed or pending MDM policies using native macOS tools.
# Works with any MDM solution (Jamf, Intune, Kandji, etc.) by 
# triggering standard macOS policy refresh mechanisms.
# Includes intelligent retry logic with exponential backoff.
#
# Common use cases:
# - Retry failed configuration profiles
# - Force policy refresh after network connectivity issues
# - Recover from incomplete MDM enrollment states
# ============================================

# === Configuration ===
MAX_RETRIES=5                           # Maximum number of retry attempts
INITIAL_DELAY=10                        # Initial delay in seconds
MAX_DELAY=300                           # Maximum delay between retries (5 minutes)
CHECK_INTERVAL=30                       # Interval to check policy status
FORCE_REFRESH=false                     # Force refresh even if policies appear current
VERBOSE=false                           # Enable verbose logging

# === Logging ===
log() { echo "[policy-retry] $1"; }
verbose_log() { [[ "$VERBOSE" == true ]] && echo "[policy-retry] [VERBOSE] $1"; }
error_log() { echo "[policy-retry] [ERROR] $1" >&2; }

# === Utility Functions ===
show_usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Options:
  -r, --retries NUM     Maximum number of retry attempts (default: $MAX_RETRIES)
  -d, --delay SECONDS   Initial delay between retries (default: $INITIAL_DELAY)
  -i, --interval SEC    Interval to check policy status (default: $CHECK_INTERVAL)
  -f, --force           Force refresh even if policies appear current
  -v, --verbose         Enable verbose logging
  -h, --help           Show this help message

Examples:
  $0                    # Run with default settings
  $0 -r 3 -d 5         # 3 retries with 5 second initial delay
  $0 -f -v             # Force refresh with verbose logging
EOF
}

# === Parse Command Line Arguments ===
while [[ $# -gt 0 ]]; do
  case $1 in
    -r|--retries)
      MAX_RETRIES="$2"
      shift 2
      ;;
    -d|--delay)
      INITIAL_DELAY="$2"
      shift 2
      ;;
    -i|--interval)
      CHECK_INTERVAL="$2"
      shift 2
      ;;
    -f|--force)
      FORCE_REFRESH=true
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      error_log "Unknown option: $1"
      show_usage
      exit 1
      ;;
  esac
done

# === Validation ===
if ! command -v profiles >/dev/null 2>&1; then
  error_log "profiles command not found. This script requires macOS 10.7+."
  exit 1
fi

# === Policy Status Check Functions ===
check_mdm_status() {
  verbose_log "Checking MDM enrollment status..."
  profiles status -type enrollment 2>/dev/null | grep -q "Enrolled via DEP"
  return $?
}

get_pending_profiles() {
  verbose_log "Checking for pending configuration profiles..."
  profiles show -type configuration 2>/dev/null | grep -c "ProfileInstallationState: Pending" || echo "0"
}

get_failed_profiles() {
  verbose_log "Checking for failed configuration profiles..."
  profiles show -type configuration 2>/dev/null | grep -c "ProfileInstallationState: Failed" || echo "0"
}

# === Policy Refresh Functions ===
trigger_mdm_refresh() {
  log "Triggering MDM policy refresh..."
  
  # Method 1: Use profiles command to renew
  if profiles renew -type enrollment 2>/dev/null; then
    verbose_log "Successfully triggered enrollment renewal"
    return 0
  fi
  
  # Method 2: Touch MDM configuration to trigger refresh
  local mdm_config="/Library/Application Support/com.apple.TCC/MDMOverrides.plist"
  if [[ -f "$mdm_config" ]]; then
    verbose_log "Touching MDM configuration file"
    touch "$mdm_config" 2>/dev/null
  fi
  
  # Method 3: Trigger configuration profile refresh
  profiles -P 2>/dev/null || true
  
  return 0
}

force_policy_refresh() {
  log "Forcing comprehensive policy refresh..."
  
  # Refresh all profile types
  for profile_type in enrollment configuration; do
    verbose_log "Refreshing $profile_type profiles..."
    profiles renew -type "$profile_type" 2>/dev/null || true
  done
  
  # Trigger system policy refresh
  verbose_log "Triggering system policy refresh..."
  killall -HUP cfprefsd 2>/dev/null || true
  
  return 0
}

# === Retry Logic with Exponential Backoff ===
retry_policies() {
  local attempt=1
  local delay=$INITIAL_DELAY
  
  while [[ $attempt -le $MAX_RETRIES ]]; do
    log "Attempt $attempt of $MAX_RETRIES..."
    
    # Check current status
    local pending_count
    local failed_count
    pending_count=$(get_pending_profiles)
    failed_count=$(get_failed_profiles)
    
    verbose_log "Found $pending_count pending and $failed_count failed profiles"
    
    # If no issues and not forcing, we're done
    if [[ $pending_count -eq 0 && $failed_count -eq 0 && "$FORCE_REFRESH" != true ]]; then
      log "No pending or failed profiles found. Policy refresh not needed."
      return 0
    fi
    
    # Trigger appropriate refresh
    if [[ "$FORCE_REFRESH" == true ]]; then
      force_policy_refresh
    else
      trigger_mdm_refresh
    fi
    
    # Wait for policies to process
    log "Waiting $CHECK_INTERVAL seconds for policies to process..."
    sleep "$CHECK_INTERVAL"
    
    # Check if successful
    local new_pending
    local new_failed
    new_pending=$(get_pending_profiles)
    new_failed=$(get_failed_profiles)
    
    verbose_log "After attempt $attempt: $new_pending pending, $new_failed failed"
    
    if [[ $new_pending -eq 0 && $new_failed -eq 0 ]]; then
      log "Policy refresh successful! All profiles applied."
      return 0
    elif [[ $new_pending -lt $pending_count || $new_failed -lt $failed_count ]]; then
      log "Progress made. Continuing with next attempt..."
    else
      verbose_log "No improvement detected."
    fi
    
    # Prepare for next attempt
    ((attempt++))
    if [[ $attempt -le $MAX_RETRIES ]]; then
      log "Waiting $delay seconds before next attempt..."
      sleep "$delay"
      
      # Exponential backoff (double the delay, up to max)
      delay=$((delay * 2))
      if [[ $delay -gt $MAX_DELAY ]]; then
        delay=$MAX_DELAY
      fi
    fi
  done
  
  error_log "Policy retry failed after $MAX_RETRIES attempts"
  return 1
}

# === Main Execution ===
main() {
  log "Starting macOS policy retry process..."
  
  if [[ "$VERBOSE" == true ]]; then
    log "Configuration: retries=$MAX_RETRIES, initial_delay=${INITIAL_DELAY}s, check_interval=${CHECK_INTERVAL}s, force=$FORCE_REFRESH"
  fi
  
  # Check if we're enrolled in MDM
  if ! check_mdm_status; then
    verbose_log "Device not enrolled via DEP/MDM, but continuing with profile refresh..."
  fi
  
  # Run the retry logic
  if retry_policies; then
    log "Policy retry completed successfully"
    
    # Show final status
    if [[ "$VERBOSE" == true ]]; then
      log "Final profile status:"
      profiles status 2>/dev/null || true
    fi
    
    exit 0
  else
    error_log "Policy retry process failed"
    exit 1
  fi
}

# Run main function
main "$@"