#!/bin/sh

################################################################################
# IP Limiter Evasion Mitigator
#
# Overview:
# This script safeguards your network against users who might change their IP 
# addresses to bypass firewall rules, QoS settings, or bandwidth limiters.
#
# How It Works:
# 1. Monitors specified MAC addresses.
# 2. Queries the ARP database to retrieve the current IP addresses linked to 
#    the specified MAC addresses.
# 3. Updates a firewall alias with the retrieved IP addresses.
#
# Usage:
# Execute: ./firewall-evasion-protection.sh [--dry-run|-d]
# Options:
#   --dry-run or -d: Executes the script in dry-run mode, displaying the 
#                    proposed changes without implementing them.
#
# Prerequisites & Setup:
# 1. Install the arpwatch service on pfSense.
# 2. Install the cron service on pfSense.
# 3. Identify the MAC addresses of devices you wish to monitor.
# 4. Set up the desired firewall rule and create an alias for it.
# 5. Modify the CONFIGURATION SECTION of this script as per your requirements.
# 6. Test the configuration using the --dry-run or -d option.
# 7. Schedule the script to run at desired intervals using pfSense's cron job.
#    Example: To run the script every hour, configure the cron job as:
#             Minute: 0, Hour: *, Day: *, Month: *, Weekday: *
################################################################################

################################################################################
# CONFIGURATION SECTION
# Update the following settings as per your requirements.
################################################################################

# MAC Addresses Configuration:
# Specify the MAC addresses you want to monitor. These are the addresses of the
# devices that you suspect might change their IP to evade firewall rules.
# List them in a space-separated format.
MAC_ADDRESSES="AA:AA:AA:AA:AA:AA 11:11:11:11:11:11"

# Firewall Alias Configuration:
# Specify the name of the firewall alias that you want to update with the IP
# addresses associated with the above MAC addresses.
ALIAS_NAME="5MB_Limiter"

################################################################################
# END OF CONFIGURATION SECTION
# You shouldn't need to change anything below this line.
################################################################################

# Directory for storing temporary files
TEMP_DIR="/tmp/firewall-evasion-protection"
mkdir -p $TEMP_DIR

# Path to the arpwatch databases directory
ARP_DB_PATH="/usr/local/arpwatch/"


# Check for dry-run mode using command line flags
DRY_RUN="false"
if [ "$1" == "--dry-run" ] || [ "$1" == "-d" ]; then
  DRY_RUN="true"
fi

# Temporary files
COMBINED_ARP_FILE="$TEMP_DIR/arp.dat"
CURRENT_IPS_FILE="$TEMP_DIR/$ALIAS_NAME.tmp"
TMP_PROPOSED_IPS="$TEMP_DIR/$ALIAS_NAME_new.tmp"

# Function to combine ARP database files into a single file
combine_arp_files() {
  cat "${ARP_DB_PATH}"*.dat > $COMBINED_ARP_FILE
}

# Function to update the firewall alias with proposed changes
update_firewall_alias() {
  pfctl -t $ALIAS_NAME -T flush
  pfctl -t $ALIAS_NAME -T add -f $TMP_PROPOSED_IPS
  /etc/rc.reload_all
  echo "Changes applied to the firewall alias."
}

# Main logic
if [ -d "$ARP_DB_PATH" ]; then
  combine_arp_files
  CHANGES_MADE="false"
  touch "$TMP_PROPOSED_IPS"
  CURRENT_IPS=$(pfctl -t $ALIAS_NAME -T show 2>/dev/null | awk '{$1=$1};1' | sort)
  echo "$CURRENT_IPS" > $CURRENT_IPS_FILE
  echo "MAC addresses and IPs found in ARP database:"
  for MAC_ADDRESS in $MAC_ADDRESSES; do
    awk -v mac="$MAC_ADDRESS" '$1 == mac {print}' $COMBINED_ARP_FILE
  done
  echo "Current IP addresses in the rule:"
  echo "$CURRENT_IPS"
  for MAC_ADDRESS in $MAC_ADDRESSES; do
      ARP_ENTRY=$(awk -v mac="$MAC_ADDRESS" '$1 == mac {print}' $COMBINED_ARP_FILE)
      IP=$(echo "$ARP_ENTRY" | awk '{print $2}')
      if [ ! -z "$IP" ] && ! grep -q -w "$IP" "$TMP_PROPOSED_IPS"; then
          echo "$IP" >> "$TMP_PROPOSED_IPS"
      fi
  done
  sort -u $TMP_PROPOSED_IPS -o $TMP_PROPOSED_IPS
  DIFF_COUNT=$(diff $CURRENT_IPS_FILE $TMP_PROPOSED_IPS | wc -l)
  if [ "$DIFF_COUNT" -ne "0" ]; then
      CHANGES_MADE="true"
  fi
  echo "Proposed IP addresses in the rule:"
  cat "$TMP_PROPOSED_IPS"
  if [ "$CHANGES_MADE" = "true" ] && [ "$DRY_RUN" == "false" ]; then
      update_firewall_alias
  elif [ "$CHANGES_MADE" = "true" ]; then
      echo "Changes not applied (dry run mode)."
  else
      echo "No changes to apply."
  fi
else
  echo "ERROR: arpwatch databases directory not found."
fi
