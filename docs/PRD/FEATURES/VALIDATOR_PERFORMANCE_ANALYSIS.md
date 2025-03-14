# Validator Performance Analysis

This document describes the historical validator performance analysis feature for Ephemery nodes, which complements the real-time validator performance monitoring functionality by providing in-depth analysis of validator performance over time.

## Overview

The validator performance analysis system processes historical validator metrics to generate comprehensive reports, visualizations, and trend analysis that help operators understand long-term validator performance, identify patterns, and optimize their validator operations.

## Features

The validator performance analysis system offers:

- **Historical Trend Analysis**
  - Balance trend analysis across customizable time periods
  - Attestation effectiveness over time
  - Performance pattern detection
  - Validator earnings calculation

- **Comparative Performance**
  - Cross-validator performance comparison
  - Performance against network averages
  - Effectiveness ratings

- **Visualization**
  - Interactive HTML reports
  - Performance trend charts
  - Balance history graphs
  - PDF report generation for sharing/archiving

- **Customizable Analysis**
  - Adjustable time periods (1d, 7d, 30d, 90d, all)
  - Validator filtering for targeted analysis
  - Multiple detail levels (standard, detailed, minimal)

## Components

The validator performance analysis system consists of the following components:

1. **Analysis Script** (`validator_performance_analysis.sh`)
   - Processes historical metrics collected by the monitoring system
   - Generates trend analysis, reports and visualizations
   - Produces HTML and optional PDF reports

2. **Dashboard Integration**
   - Integration with the validator dashboard for easy access
   - Command-line options for launching analysis from dashboard script

3. **Visualization Engine**
   - Chart generation for balance trends
   - Attestation performance visualization
   - Interactive HTML reports

## Installation

The validator performance analysis system is included with the Ephemery deployment. Optional dependencies:

- `gnuplot` - for generating performance charts
- `wkhtmltopdf` - for generating PDF reports

## Usage

### Basic Analysis

To generate a standard performance report for the default 7-day period:

```bash
./scripts/monitoring/validator_performance_analysis.sh
```

### Advanced Analysis

For more comprehensive analysis with charts:

```bash
./scripts/monitoring/validator_performance_analysis.sh \
  --period 30d \
  --charts \
  --type detailed
```

### Dashboard Integration

The analysis can also be launched through the validator dashboard script:

```bash
# Generate performance report with default settings
./scripts/validator-dashboard.sh --analyze

# Generate detailed report with charts for a 90-day period
./scripts/validator-dashboard.sh --analyze --period 90d --charts
```

### PDF Report Generation

To generate a PDF report for sharing or archiving:

```bash
./scripts/monitoring/validator_performance_analysis.sh --period 30d --pdf
```

## Configuration Options

The validator performance analysis system supports the following configuration options:

| Option | Description | Default |
|--------|-------------|---------|
| `--output DIR` | Output directory for metrics and reports | `./validator_metrics` |
| `--period PERIOD` | Analysis period (1d, 7d, 30d, 90d, all) | `7d` |
| `--validators LIST` | Comma-separated list of validator indices to analyze | `all` |
| `--type TYPE` | Analysis type (standard, detailed, minimal) | `standard` |
| `--charts` | Generate performance charts using gnuplot | `false` |
| `--pdf` | Generate PDF report (requires wkhtmltopdf) | `false` |
| `--verbose` | Enable verbose output | `false` |

## Analysis Methodology

The analysis system uses the following methodologies to evaluate validator performance:

### Balance Trend Analysis

- Calculates balance changes over the selected time period
- Determines percent change to evaluate relative performance
- Identifies increasing, decreasing, or stable trends
- Compares current balance against historical averages

### Attestation Performance Analysis

- Calculates attestation effectiveness percentage
- Tracks missed attestations
- Evaluates overall attestation reliability
- Assigns performance ratings:
  - Excellent: >99% effectiveness
  - Good: 95-99% effectiveness
  - Fair: 90-95% effectiveness
  - Poor: <90% effectiveness

## Report Components

The generated reports include:

1. **Summary Section**
   - Overview of the analysis period
   - Key performance indicators
   - Number of validators analyzed

2. **Balance Trends Table**
   - Validator index
   - Current balance
   - Total balance change
   - Percent change
   - Trend indicator

3. **Attestation Performance Table**
   - Validator index
   - Attestation effectiveness percentage
   - Missed attestations count
   - Total attestations count
   - Performance rating

4. **Visualizations** (when charts enabled)
   - Balance trend charts
   - Attestation effectiveness charts

## Dependencies

The validator performance analysis system has the following dependencies:

- `jq`: For JSON data processing
- `curl`: For API requests (when needed)
- `gnuplot`: For chart generation (optional)
- `wkhtmltopdf`: For PDF report generation (optional)

## Design Principles

The validator performance analysis system was designed with the following principles:

1. **Historical Context**: Provide long-term historical context beyond real-time monitoring
2. **Actionable Insights**: Generate insights that help operators improve performance
3. **Flexible Analysis**: Support different time periods and analysis depths
4. **Visual Representation**: Offer clear visual representations of complex performance data
5. **Integration**: Seamlessly integrate with the existing monitoring ecosystem

## Extending the System

The validator performance analysis system can be extended by:

1. **Additional Analysis Types**
   - Implementation of specialized analysis algorithms
   - Custom performance metrics

2. **Enhanced Visualizations**
   - Additional chart types
   - Interactive dashboards

3. **Integration with External Tools**
   - Export data to external analytics platforms
   - Integration with notification systems

## Troubleshooting

### Common Issues

1. **Missing Historical Data**
   - Ensure the monitoring system has been running long enough
   - Check that history files are being properly generated
   - Verify permissions on metrics directories

2. **Chart Generation Failures**
   - Install gnuplot for chart functionality
   - Check for gnuplot dependencies

3. **PDF Generation Issues**
   - Install wkhtmltopdf for PDF functionality
   - Ensure proper permissions for file generation

## References

- [Validator Performance Monitoring](./VALIDATOR_PERFORMANCE_MONITORING.md)
- [Validator Key Management](./VALIDATOR_KEY_MANAGEMENT.md)
- [Dashboard Implementation](./DASHBOARD_IMPLEMENTATION.md)
- [Ephemery Setup](./EPHEMERY_SETUP.md) 