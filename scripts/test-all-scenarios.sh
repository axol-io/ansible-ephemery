#!/bin/bash
# Script to run Molecule tests for all scenarios with proper logging

# Create logs directory
LOGS_DIR="molecule_logs"
mkdir -p "${LOGS_DIR}"

# Get list of all scenarios
mapfile -t SCENARIOS < <(find molecule -mindepth 1 -maxdepth 1 -type d -not -path "molecule/shared" | sort | xargs -n1 basename)

# Parse command line arguments
COMMAND="test"
VERBOSE=0
CONTINUE_ON_ERROR=0

function show_help {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Run Molecule tests for all scenarios with proper logging."
    echo ""
    echo "Options:"
    echo "  -c, --command COMMAND    Molecule command to run (default: test)"
    echo "  -s, --scenario SCENARIO  Only test specific scenario(s)"
    echo "  -v, --verbose            Show output in real-time in addition to logging"
    echo "  -k, --keep-going         Continue testing scenarios even after failures"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       Run 'test' command on all scenarios"
    echo "  $0 -c verify             Run 'verify' command on all scenarios"
    echo "  $0 -s default -s validator  Test only these specific scenarios"
    echo "  $0 -v -k                 Show real-time output and continue on errors"
    exit 0
}

# Parse arguments
SELECTED_SCENARIOS=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -c|--command)
            COMMAND="$2"
            shift 2
            ;;
        -s|--scenario)
            SELECTED_SCENARIOS+=("$2")
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -k|--keep-going)
            CONTINUE_ON_ERROR=1
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# If specific scenarios were selected, use those instead
if [ ${#SELECTED_SCENARIOS[@]} -gt 0 ]; then
    SCENARIOS=("${SELECTED_SCENARIOS[@]}")
fi

# Print header
echo "================================================================"
echo "Running Molecule '${COMMAND}' on ${#SCENARIOS[@]} scenarios"
echo "Output will be logged to ${LOGS_DIR}/scenario-*.log"
if [ $VERBOSE -eq 1 ]; then
    echo "Verbose mode: Output will also be displayed in real-time"
fi
if [ $CONTINUE_ON_ERROR -eq 1 ]; then
    echo "Keep-going mode: Testing will continue even after failures"
fi
echo "================================================================"
echo ""

# Initialize counters
PASSED=0
FAILED=0
SKIPPED=0

# Track failed scenarios
FAILED_SCENARIOS=()

# Get start time
START_TIME=$(date +%s)

# Run test for each scenario
for scenario in "${SCENARIOS[@]}"; do
    echo -n "Testing scenario '${scenario}'... "

    LOG_FILE="${LOGS_DIR}/scenario-${scenario}.log"

    # Check if the scenario directory actually exists
    if [ ! -d "molecule/${scenario}" ]; then
        echo "SKIPPED (directory not found)"
        SKIPPED=$((SKIPPED+1))
        continue
    fi

    # Run the test with the helper script
    if [ $VERBOSE -eq 1 ]; then
        ./run-molecule.sh ${COMMAND} -s ${scenario} | tee "${LOG_FILE}"
        EXIT_CODE=${PIPESTATUS[0]}
    else
        ./run-molecule.sh ${COMMAND} -s ${scenario} > "${LOG_FILE}" 2>&1
        EXIT_CODE=$?
    fi

    if [ $EXIT_CODE -eq 0 ]; then
        echo "PASSED"
        PASSED=$((PASSED+1))
    else
        echo "FAILED (see ${LOG_FILE} for details)"
        FAILED=$((FAILED+1))
        FAILED_SCENARIOS+=("${scenario}")

        # Exit if we're not continuing on error
        if [ $CONTINUE_ON_ERROR -eq 0 ]; then
            echo ""
            echo "Stopping due to failure. Use -k to continue past errors."
            break
        fi
    fi
done

# Get end time and calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Print summary
echo ""
echo "================================================================"
echo "TEST SUMMARY"
echo "================================================================"
echo "Total scenarios: ${#SCENARIOS[@]}"
echo "Passed: ${PASSED}"
echo "Failed: ${FAILED}"
echo "Skipped: ${SKIPPED}"
echo "Duration: ${MINUTES}m ${SECONDS}s"
echo ""

if [ $FAILED -gt 0 ]; then
    echo "Failed scenarios:"
    for scenario in "${FAILED_SCENARIOS[@]}"; do
        echo "  - ${scenario} (log: ${LOGS_DIR}/scenario-${scenario}.log)"
    done
    exit 1
else
    echo "All tests passed successfully!"
    exit 0
fi
