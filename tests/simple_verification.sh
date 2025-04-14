#!/bin/bash
#
# Simple Verification Script
# Validates the basic structure and functionality of the project
#

# Set script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_RESET="\033[0m"

echo "Running simple verification tests..."

# Check if main files exist
echo -e "\nChecking critical files:"
critical_files=(
  "bin/pve-template-wizard.sh"
  "lib/core/ui.sh"
  "lib/core/logging.sh"
  "lib/core/config.sh"
  "lib/core/validation.sh"
  "lib/distributions/distro_info.sh"
  "lib/storage/storage.sh"
  "lib/network/network.sh"
  "lib/vm/vm.sh"
)

all_files_present=true
for file in "${critical_files[@]}"; do
  if [ -f "$REPO_DIR/$file" ]; then
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $file exists"
  else
    echo -e "  ${COLOR_RED}✗${COLOR_RESET} $file missing"
    all_files_present=false
  fi
done

# Check if files are executable
echo -e "\nChecking executable permissions:"
executables=(
  "bin/pve-template-wizard.sh"
  "tests/run_tests.sh"
)

all_executables_ok=true
for file in "${executables[@]}"; do
  if [ -x "$REPO_DIR/$file" ]; then
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $file is executable"
  else
    echo -e "  ${COLOR_RED}✗${COLOR_RESET} $file lacks executable permissions"
    all_executables_ok=false
  fi
done

# Check for required functions in core modules
echo -e "\nChecking core functionality:"
function check_for_function() {
  local file=$1
  local function_name=$2

  # Check for both function declaration styles:
  # 1. With "function" keyword: function show_menu() { ... }
  # 2. Without "function" keyword: show_menu() { ... }
  if grep -q -E "(function $function_name|$function_name\(\))" "$REPO_DIR/$file"; then
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $function_name present in $file"
    return 0
  else
    echo -e "  ${COLOR_RED}✗${COLOR_RESET} $function_name missing from $file"
    return 1
  fi
}

all_functions_present=true
# Check key functions
check_for_function "lib/core/ui.sh" "show_menu" || all_functions_present=false
check_for_function "lib/core/logging.sh" "init_logging" || all_functions_present=false
check_for_function "lib/core/validation.sh" "validate_ipv4" || all_functions_present=false
check_for_function "lib/vm/vm.sh" "create_vm" || all_functions_present=false

# Check test framework
echo -e "\nVerifying test framework:"
test_framework_ok=true

if [ -d "$REPO_DIR/tests/unit" ] && [ -d "$REPO_DIR/tests/integration" ]; then
  echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} Test directories exist"
else
  echo -e "  ${COLOR_RED}✗${COLOR_RESET} Test directories missing"
  test_framework_ok=false
fi

# Check documentation
echo -e "\nVerifying documentation:"
docs_ok=true

if [ -f "$REPO_DIR/README.md" ] && [ -f "$REPO_DIR/CONTRIBUTING.md" ]; then
  echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} Documentation files present"
else
  echo -e "  ${COLOR_RED}✗${COLOR_RESET} Documentation files missing"
  docs_ok=false
fi

# Final summary
echo -e "\n-------------------------------------"
echo -e "          Verification Summary       "
echo -e "-------------------------------------"

all_tests_passed=true
if $all_files_present; then
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} All critical files present"
else
  echo -e "${COLOR_RED}✗${COLOR_RESET} Some critical files missing"
  all_tests_passed=false
fi

if $all_executables_ok; then
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} All executables have correct permissions"
else
  echo -e "${COLOR_RED}✗${COLOR_RESET} Some executables lack proper permissions"
  all_tests_passed=false
fi

if $all_functions_present; then
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} All core functions detected"
else
  echo -e "${COLOR_RED}✗${COLOR_RESET} Some core functions missing"
  all_tests_passed=false
fi

if $test_framework_ok; then
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} Test framework intact"
else
  echo -e "${COLOR_RED}✗${COLOR_RESET} Test framework has issues"
  all_tests_passed=false
fi

if $docs_ok; then
  echo -e "${COLOR_GREEN}✓${COLOR_RESET} Documentation complete"
else
  echo -e "${COLOR_RED}✗${COLOR_RESET} Documentation incomplete"
  all_tests_passed=false
fi

echo -e "\n"
if $all_tests_passed; then
  echo -e "${COLOR_GREEN}All verification tests passed!${COLOR_RESET}"
  exit 0
else
  echo -e "${COLOR_RED}Some verification tests failed.${COLOR_RESET}"
  exit 1
fi
