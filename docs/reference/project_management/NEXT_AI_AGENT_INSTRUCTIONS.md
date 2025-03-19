# Instructions for Next AI Agent

## Current Project Status

As of May 2023, the following key features have been implemented:

1. **Core Ephemery Testnet Support**
   - Automated genesis reset detection
   - Retention script with 5-minute polling
   - Cron job setup for automatic resets
   - Genesis validator operations support

2. **Validator Management Tools**
   - Key validation and extraction
   - Multi-format archive support
   - Automatic key backup
   - Key restore functionality

3. **Performance Monitoring**
   - Comprehensive sync dashboard
   - Detailed metrics collection
   - Historical sync progress tracking
   - Checkpoint sync visualization

4. **Deployment Systems**
   - Single-command deployment script
   - Guided configuration workflow
   - Deployment verification tests

5. **Codebase Quality Improvements**
   - Path standardization
   - Container naming standardization
   - Error handling standardization
   - Shell script libraries

6. **Lido CSM Integration**
   - CSM validator performance monitoring script
   - Unified CSM analytics suite
   - Flexible JSON-based configuration system
   - CSM-specific performance metrics
   - Anomaly detection and alerting
   - Historical performance tracking
   - Dashboard generation capabilities

## Recently Completed Work

We have just completed the implementation of the Lido CSM Integration with Advanced Validator Performance Analytics. This work included:

1. **CSM Validator Performance Monitoring Script** (`scripts/monitoring/csm_validator_performance.sh`)
   - Real-time monitoring of CSM validators
   - Performance metrics (attestation effectiveness, balance tracking, inclusion distance)
   - Anomaly detection for performance outliers
   - Historical performance tracking
   - Multiple output formats (JSON, CSV, terminal, HTML)
   - Network performance comparisons

2. **CSM Analytics Suite** (`scripts/monitoring/csm_analytics_suite.sh`)
   - Unified interface for all CSM analytics tools
   - Integration with validator predictive analytics and bond optimization
   - Dashboard generation capabilities
   - Automation tools for scheduled analytics
   - Consistent command-line interface
   - Help documentation for all commands

3. **Configuration System** (`scripts/monitoring/config/csm_validator_performance.json`)
   - JSON-based configuration with default values
   - Alert channel configuration
   - Performance threshold configuration
   - Historical data retention settings
   - Centralized configuration for all tools

## Next Priority Areas

Based on the updated roadmap and implementation plan, your focus should be on the following priority areas:

1. **Distributed Validator Technology (DVT) Support**
   - Research current DVT implementations (Obol, SSV)
   - Design architecture for DVT integration in Ephemery
   - Develop infrastructure components for distributed validation
   - Create integration points with Obol and SSV networks
   - Implement monitoring specific to DVT operations
   - Document DVT setup and operation procedures

2. **Client Diversity Support Improvements**
   - Expand client combination testing
   - Enhance documentation for diverse client configurations
   - Optimize performance for all supported clients
   - Develop client-specific monitoring extensions
   - Create client transition guides for operators

3. **User Experience Enhancements**
   - Redesign user interfaces for improved usability
   - Enhance command-line interfaces for consistent operation
   - Expand documentation with detailed guides
   - Create comprehensive troubleshooting flows
   - Develop user onboarding improvements

## Implementation Considerations

When implementing these features, please adhere to the following principles and patterns established in the project:

1. **Code Organization**
   - Follow the established directory structure
   - Use standardized path management from `scripts/core/path_config.sh`
   - Implement consistent error handling using `scripts/core/error_handling.sh`
   - Leverage common utilities from `scripts/core/common.sh`

2. **Script Development**
   - Maintain consistent script header format with description and usage
   - Implement standardized command-line argument parsing
   - Use color-coded output for better readability
   - Add comprehensive help documentation
   - Follow established logging patterns

3. **Configuration Management**
   - Use JSON for configuration files with schema validation
   - Implement default values with configuration override capability
   - Follow the pattern established in existing configuration files
   - Add validation for configuration parameters

4. **Documentation**
   - Update PRD documents for new features
   - Follow the established documentation structure
   - Include comprehensive usage examples
   - Document configuration options with descriptions
   - Create troubleshooting guides for common issues

5. **Testing**
   - Implement comprehensive testing for new features
   - Test across different client combinations
   - Validate functionality in reset scenarios
   - Include performance testing where applicable

## Key Files to Reference

When implementing the next priority items, refer to these key files for patterns and integration points:

1. **For DVT Integration**
   - `scripts/monitoring/csm_validator_performance.sh` - For monitoring patterns
   - `scripts/monitoring/csm_analytics_suite.sh` - For integration patterns
   - `docs/PRD/FEATURES/VALIDATOR_PERFORMANCE_MONITORING.md` - For monitoring requirements

2. **For Client Diversity**
   - `scripts/deployment/setup_ephemery.sh` - For client configuration patterns
   - `ansible/playbooks/deploy_ephemery.yaml` - For deployment patterns
   - `docs/PRD/FEATURES/CLIENT_DIVERSITY.md` - For client diversity requirements

3. **For User Experience**
   - `scripts/validator-dashboard.sh` - For dashboard implementation patterns
   - `scripts/monitoring/monitor_ephemery.sh` - For monitoring UI patterns
   - `docs/PRD/FEATURES/USER_EXPERIENCE.md` - For UX requirements

## Contact Information

If you encounter issues or need clarification, please reach out to the project maintainers:

- Primary Contact: ephemery-support@example.com
- GitHub Issues: Submit issues in the main repository
- Documentation Queries: docs-support@example.com

## Progress Tracking

Please update the following documents as you make progress:

1. `docs/PRD/PROJECT_MANAGEMENT/IMPLEMENTATION_PROGRESS.md`
2. `docs/PRD/PROJECT_MANAGEMENT/ROADMAP.md`

Additionally, create detailed PRD documents for new features in the appropriate location within the `docs/PRD/FEATURES/` directory.

Good luck with the implementation!
