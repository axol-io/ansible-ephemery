# Validator Alerts System Configuration

This directory contains configuration files for the Validator Alerts System.

## Configuration File Format

The configuration file is in JSON format and contains the following sections:

### Validators

A list of validator IDs to monitor. Replace these with your actual validator IDs.

```json
"validators": [
    "validator_1",
    "validator_2",
    "validator_3"
]
```

### Alert Thresholds

Thresholds for different alert conditions:

```json
"alert_thresholds": {
    "missed_attestations": 2,        // Alert if 2 or more attestations are missed
    "missed_proposals": 1,           // Alert if 1 or more proposals are missed
    "inclusion_distance": 3,         // Alert if inclusion distance exceeds 3
    "decreasing_balance_percentage": 1,  // Alert if balance decreases by more than 1%
    "sync_committee_participation": 90   // Alert if sync committee participation falls below 90%
}
```

### Notification Methods

Configure how alerts should be sent:

```json
"notification_methods": {
    "email": true,                            // Enable email notifications
    "email_to": "validator-admin@example.com", // Email recipient
    "email_from": "validator-alerts@example.com", // Sender email
    "sms": false,                             // Enable SMS notifications
    "sms_to": "+15551234567",                 // SMS recipient
    "webhook": false,                         // Enable webhook notifications
    "webhook_url": "https://example.com/webhook/validator-alerts" // Webhook URL
}
```

### Other Settings

Additional configuration options:

```json
"data_directory": "/var/lib/validator/data",    // Directory to store persistent data
"metrics_directory": "/var/lib/validator/metrics", // Directory containing validator metrics
"polling_interval": 300,                       // Check interval in seconds
"retention_days": 30,                         // How long to keep alert history
"log_level": "INFO"                           // Logging level (DEBUG, INFO, WARN, ERROR)
```

## Getting Started

1. Copy the sample configuration file to create your own:
   ```bash
   cp alerts_config.sample.json alerts_config.json
   ```

2. Edit the configuration file to match your environment:
   ```bash
   nano alerts_config.json
   ```

3. Run the validator alerts system with your configuration:
   ```bash
   ../validator_alerts_system.sh --config-file config/alerts_config.json
   ```

## Testing

To test the alerts system:

```bash
../validator_alerts_system.sh --config-file config/alerts_config.json --test-mode \
  --test-data '{"missed_attestations": 3}' --alert-type missed_attestation
```

To test notifications:

```bash
../validator_alerts_system.sh --config-file config/alerts_config.json --test-mode \
  --test-notification email --alert-data '{"type": "missed_attestation", "message": "Test alert"}'
``` 