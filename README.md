# IP Limiter Evasion Mitigator

## Overview
This script is designed to safeguard your network against users who might change their IP addresses to bypass firewall rules, QoS settings, or bandwidth limiters.

### How It Works
1. **Monitor MAC Addresses**: The script keeps an eye on specified MAC addresses.
2. **Query ARP Database**: It then checks the ARP database to retrieve the current IP addresses associated with the specified MAC addresses.
3. **Update Firewall Alias**: Finally, it updates a firewall alias with the retrieved IP addresses.

## Usage
To execute the script:
`./firewall-evasion-protection.sh [--dry-run|-d]`

### Options
- `--dry-run` or `-d`: Executes the script in dry-run mode. This will display the proposed changes without actually implementing them.

## Prerequisites & Setup
1. **Arpwatch Service**: Ensure you have the arpwatch service installed on pfSense.
2. **Cron Service**: Install the cron service on pfSense.
3. **MAC Addresses**: Identify the MAC addresses of devices you wish to monitor.
4. **Firewall Rule & Alias**: Set up the desired firewall rule and create an alias for it.
5. **Script Configuration**: Modify the `CONFIGURATION SECTION` of this script as per your requirements.
6. **Testing**: Before deploying, test the configuration using the `--dry-run` or `-d` option.
7. **Scheduling**: Schedule the script to run at desired intervals using pfSense's cron job. For instance, to run the script every hour, configure the cron job as:
`Minute: 0, Hour: *, Day: *, Month: *, Weekday: *`

## Configuration
Within the script, there's a section named `CONFIGURATION SECTION`. This is where you'll specify the MAC addresses you want to monitor and the firewall alias you want to update.

### MAC Addresses Configuration
Specify the MAC addresses of the devices you suspect might change their IP to bypass firewall rules. List them in a space-separated format.
```bash
# Example: 
MAC_ADDRESSES="01:23:45:ab:cd:ef 67:89:10:fe:dc:ba"
```
### Firewall Alias Configuration

Specify the name of the firewall alias that you want to update with the IP addresses associated with the above MAC addresses.
```bash
# Example: 
ALIAS_NAME="5MB_Limiter"
```

### Troubleshooting

If you encounter the error message ERROR: arpwatch databases directory not found., ensure that the arpwatch service is correctly installed and the database directory exists at `/usr/local/arpwatch/`.
Contribution

Feel free to contribute to this script by submitting pull requests or opening issues for any bugs or enhancements.

### License

This script is open-source. Ensure you comply with your organization's policies and any applicable laws when deploying and using this script.

