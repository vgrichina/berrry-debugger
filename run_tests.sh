#!/bin/bash

# BerrryDebugger UI Test Runner
# Runs smoke tests or custom tests with screenshot generation

set -e

DEVICE="iPhone 16 Pro"
SCHEME="BerrryDebugger"
TEST_RESULTS_DIR="test_results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [smoke|custom|all] [test_name]"
    echo ""
    echo "Options:"
    echo "  smoke     Run smoke tests only"
    echo "  custom    Run custom tests only" 
    echo "  all       Run all tests (default)"
    echo "  test_name Specific test to run (e.g., AppLaunchTests/testAppLaunches)"
    echo ""
    echo "Examples:"
    echo "  $0 smoke                           # Run all smoke tests"
    echo "  $0 custom                          # Run all custom tests"
    echo "  $0 AppLaunchTests/testAppLaunches  # Run specific test"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}🧪 BerrryDebugger UI Test Runner${NC}"
    echo -e "${BLUE}========================================${NC}"
}

build_project() {
    echo -e "${YELLOW}🔨 Generating Xcode project...${NC}"
    xcodegen generate
    
    echo -e "${YELLOW}🔨 Building project...${NC}"
    xcodebuild -scheme "$SCHEME" -destination "platform=iOS Simulator,name=$DEVICE" build
}

run_tests() {
    local test_filter="$1"
    
    echo -e "${YELLOW}🚀 Running tests on $DEVICE...${NC}"
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Clean up old screenshots (keep latest 20)
    if [ -d "$TEST_RESULTS_DIR" ]; then
        find "$TEST_RESULTS_DIR" -name "*.png" -type f | head -n -20 | xargs rm -f 2>/dev/null || true
    fi
    
    # Build and run tests
    if [ -n "$test_filter" ]; then
        echo -e "${BLUE}Running filtered tests: $test_filter${NC}"
        xcodebuild test \
            -scheme "$SCHEME" \
            -destination "platform=iOS Simulator,name=$DEVICE" \
            -only-testing:"BerrryDebuggerUITests/$test_filter" \
            | tee test_output.log
    else
        echo -e "${BLUE}Running all UI tests...${NC}"
        xcodebuild test \
            -scheme "$SCHEME" \
            -destination "platform=iOS Simulator,name=$DEVICE" \
            -testPlan BerrryDebuggerUITests \
            | tee test_output.log
    fi
}

show_results() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}📊 Test Results${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # Show test summary from log
    if grep -q "Test Suite.*failed" test_output.log; then
        echo -e "${RED}❌ Some tests failed${NC}"
        grep "Test Suite.*failed" test_output.log
    elif grep -q "Test Suite.*passed" test_output.log; then
        echo -e "${GREEN}✅ All tests passed${NC}"
        grep "Test Suite.*passed" test_output.log
    fi
    
    # Show screenshots generated
    echo -e "${BLUE}📸 Screenshots generated:${NC}"
    if [ -d "$TEST_RESULTS_DIR" ]; then
        ls -la "$TEST_RESULTS_DIR"/*.png 2>/dev/null | wc -l | xargs echo "Total screenshots:"
        echo ""
        echo -e "${YELLOW}Latest screenshots:${NC}"
        ls -lt "$TEST_RESULTS_DIR"/*.png 2>/dev/null | head -10
    else
        echo "No screenshots found"
    fi
    
    echo ""
    echo -e "${BLUE}🔍 To analyze screenshots with Claude:${NC}"
    echo "claude 'analyze the test screenshots in test_results/ and tell me if you see any issues'"
}

# Main execution
print_header

case "${1:-all}" in
    "smoke")
        echo -e "${BLUE}Running smoke tests only...${NC}"
        build_project
        # Run each smoke test class individually
        run_tests "AppLaunchTests"
        run_tests "URLSchemeTests" 
        run_tests "DevToolsTests"
        ;;
    "custom") 
        echo -e "${BLUE}Running custom tests only...${NC}"
        build_project
        run_tests "ExampleCustomTest"
        ;;
    "all")
        echo -e "${BLUE}Running all tests...${NC}"
        build_project
        run_tests ""
        ;;
    "help"|"-h"|"--help")
        usage
        exit 0
        ;;
    *)
        if [[ "$1" == *"/"* ]]; then
            echo -e "${BLUE}Running specific test: $1${NC}"
            build_project
            run_tests "$1"
        else
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
        fi
        ;;
esac

show_results

echo -e "${GREEN}✅ Test run complete!${NC}"