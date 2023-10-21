#!/bin/sh

# MAC addresses to monitor (space-separated)
# Add your mac addresses to monitor and prevent evasion here
MAC_ADDRESSES="00:00:00:00:00:00 11:11:11:11:11:11"

# Directory for storing temporary files
TEMP_DIR="/tmp/limiter-evasion-mitigator"

# Create the directory
mkdir -p $TEMP_DIR

# Path to the arpwatch databases directory
ARP_DB_PATH="/usr/local/arpwatch/"

# Name of the firewall alias to update
ALIAS_NAME="5MB_Limiter"

# Check for dry-run mode using command line flags
DRY_RUN="false"
if [ "$1" == "--dry-run" ] || [ "$1" == "-d" ]; then
  DRY_RUN="true"
fi

# Temporary files
COMBINED_ARP_FILE="$TEMP_DIR/arp.dat"
CURRENT_IPS_FILE="$TEMP_DIR/5MB_Limiter.tmp"
TMP_PROPOSED_IPS="$TEMP_DIR/5MB_Limiter_new.tmp"

# Function to combine ARP database files into a single file
combine_arp_files() {
  cat "${ARP_DB_PATH}"*.dat > $COMBINED_ARP_FILE
}

# Function to update the firewall alias with proposed changes
update_firewall_alias() {
  # Flush the old addresses
  pfctl -t $ALIAS_NAME -T flush

  # Add the new addresses from the file
  pfctl -t $ALIAS_NAME -T add -f $TMP_PROPOSED_IPS

  # Reload all configurations to ensure changes are applied
  /etc/rc.reload_all
  echo "Changes applied to the firewall alias."
}

# Check if the arpwatch databases exist
if [ -d "$ARP_DB_PATH" ]; then
  # Combine ARP database files
  combine_arp_files

  # Initialize a flag for changes
  CHANGES_MADE="false"

  # Initialize the temporary file for proposed IPs
  touch "$TMP_PROPOSED_IPS"

  # Extract current IPs from the firewall alias table and remove leading spaces
  CURRENT_IPS=$(pfctl -t $ALIAS_NAME -T show 2>/dev/null | awk '{$1=$1};1' | sort)
  echo "$CURRENT_IPS" > $CURRENT_IPS_FILE

  # Display MAC addresses and IPs found in the ARP database for specified MACs
  echo "MAC addresses and IPs found in ARP database:"
  for MAC_ADDRESS in $MAC_ADDRESSES; do
    awk -v mac="$MAC_ADDRESS" '$1 == mac {print}' $COMBINED_ARP_FILE
  done

  # Display the current IPs in the firewall alias table
  echo "Current IP addresses in the rule:"
  echo "$CURRENT_IPS"

  # Loop through the MAC addresses and populate TMP_PROPOSED_IPS
  for MAC_ADDRESS in $MAC_ADDRESSES; do
      # Extract MAC and IP from the ARP database
      ARP_ENTRY=$(awk -v mac="$MAC_ADDRESS" '$1 == mac {print}' $COMBINED_ARP_FILE)
      IP=$(echo "$ARP_ENTRY" | awk '{print $2}')

      # Add the IP to TMP_PROPOSED_IPS if not already present
      if [ ! -z "$IP" ] && ! grep -q -w "$IP" "$TMP_PROPOSED_IPS"; then
          echo "$IP" >> "$TMP_PROPOSED_IPS"
      fi
  done

  # Sort and remove duplicates from TMP_PROPOSED_IPS
  sort -u $TMP_PROPOSED_IPS -o $TMP_PROPOSED_IPS

  # Check for changes by comparing the files
  DIFF_COUNT=$(diff $CURRENT_IPS_FILE $TMP_PROPOSED_IPS | wc -l)
  if [ "$DIFF_COUNT" -ne "0" ]; then
      CHANGES_MADE="true"
  fi

  # Display proposed IPs in the rule
  echo "Proposed IP addresses in the rule:"
  cat "$TMP_PROPOSED_IPS"

  # Check if changes were made
  if [ "$CHANGES_MADE" = "true" ] && [ "$DRY_RUN" == "false" ]; then
      # Update the firewall alias
      update_firewall_alias
  elif [ "$CHANGES_MADE" = "true" ]; then
      echo "Changes not applied (dry run mode)."
  else
      echo "No changes to apply."
  fi
else
  echo "ERROR: arpwatch databases directory not found."
fi
