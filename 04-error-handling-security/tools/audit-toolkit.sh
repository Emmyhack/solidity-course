#!/bin/bash

# Smart Contract Testing and Auditing Toolkit
# Comprehensive script for security testing of Solidity contracts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR"
REPORTS_DIR="$SCRIPT_DIR/reports"

# Create reports directory if it doesn't exist
mkdir -p "$REPORTS_DIR"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a tool is installed
check_tool() {
    if command -v "$1" &> /dev/null; then
        print_success "$1 is installed"
        return 0
    else
        print_warning "$1 is not installed"
        return 1
    fi
}

# Function to install Node.js dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    # Check for Node.js
    if ! check_tool "node"; then
        print_error "Node.js is required. Please install Node.js first."
        exit 1
    fi
    
    # Check for Python
    if ! check_tool "python3"; then
        print_error "Python 3 is required. Please install Python 3 first."
        exit 1
    fi
    
    # Install npm packages if package.json exists
    if [ -f "package.json" ]; then
        npm install
    fi
    
    print_success "Dependencies checked"
}

# Function to run security analysis
run_security_analysis() {
    local contract_file="$1"
    
    if [ ! -f "$contract_file" ]; then
        print_error "Contract file not found: $contract_file"
        return 1
    fi
    
    print_status "Running security analysis on $contract_file"
    
    # Run our custom security analyzer
    if [ -f "$TOOLS_DIR/security-analyzer.js" ]; then
        print_status "Running custom security analyzer..."
        node "$TOOLS_DIR/security-analyzer.js" "$contract_file"
    fi
    
    # Run Slither if available
    if check_tool "slither"; then
        print_status "Running Slither analysis..."
        slither "$contract_file" --json "$REPORTS_DIR/slither-report.json" || true
    fi
    
    # Run MythX if available
    if check_tool "mythx"; then
        print_status "Running MythX analysis..."
        mythx analyze "$contract_file" --output "$REPORTS_DIR/mythx-report.json" || true
    fi
    
    print_success "Security analysis completed"
}

# Function to run gas analysis
run_gas_analysis() {
    local contract_file="$1"
    
    if [ ! -f "$contract_file" ]; then
        print_error "Contract file not found: $contract_file"
        return 1
    fi
    
    print_status "Running gas analysis on $contract_file"
    
    # Run our custom gas analyzer
    if [ -f "$TOOLS_DIR/gas-analyzer.py" ]; then
        print_status "Running custom gas analyzer..."
        python3 "$TOOLS_DIR/gas-analyzer.py" "$contract_file"
    fi
    
    print_success "Gas analysis completed"
}

# Function to run static analysis with Solhint
run_solhint_analysis() {
    local contract_file="$1"
    
    if check_tool "solhint"; then
        print_status "Running Solhint analysis..."
        solhint "$contract_file" -f json > "$REPORTS_DIR/solhint-report.json" || true
        solhint "$contract_file"
    else
        print_warning "Solhint not installed. Skipping Solhint analysis."
    fi
}

# Function to run tests with Hardhat
run_hardhat_tests() {
    if [ -f "hardhat.config.js" ] && check_tool "npx"; then
        print_status "Running Hardhat tests..."
        npx hardhat test --reporter json > "$REPORTS_DIR/test-results.json" || true
        npx hardhat test
    else
        print_warning "Hardhat not configured. Skipping Hardhat tests."
    fi
}

# Function to check code coverage
run_coverage_analysis() {
    if [ -f "hardhat.config.js" ] && check_tool "npx"; then
        print_status "Running coverage analysis..."
        npx hardhat coverage --reporter json > "$REPORTS_DIR/coverage-report.json" || true
    else
        print_warning "Coverage analysis not available."
    fi
}

# Function to run all analyses
run_full_audit() {
    local contract_file="$1"
    
    print_status "Starting comprehensive security audit..."
    
    # Create timestamp for this audit
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local audit_dir="$REPORTS_DIR/audit_$timestamp"
    mkdir -p "$audit_dir"
    
    # Change to audit directory
    cd "$audit_dir"
    
    print_status "Running security analysis..."
    run_security_analysis "$contract_file"
    
    print_status "Running gas analysis..."
    run_gas_analysis "$contract_file"
    
    print_status "Running static analysis..."
    run_solhint_analysis "$contract_file"
    
    print_status "Running tests..."
    run_hardhat_tests
    
    print_status "Running coverage analysis..."
    run_coverage_analysis
    
    # Generate summary report
    generate_audit_summary "$audit_dir" "$contract_file"
    
    print_success "Full audit completed. Results saved in: $audit_dir"
}

# Function to generate audit summary
generate_audit_summary() {
    local audit_dir="$1"
    local contract_file="$2"
    local summary_file="$audit_dir/audit-summary.md"
    
    print_status "Generating audit summary..."
    
    cat > "$summary_file" << EOF
# Smart Contract Security Audit Summary

**Contract:** $(basename "$contract_file")  
**Audit Date:** $(date)  
**Auditor:** Automated Security Toolkit  

## 📋 Audit Scope

This automated audit covers:
- Security vulnerability analysis
- Gas optimization review
- Code quality assessment
- Best practices compliance
- Test coverage analysis

## 🔍 Analysis Results

### Security Analysis
- Custom security analyzer results
- Static analysis with Solhint
- External tool results (if available)

### Gas Analysis
- Gas usage patterns
- Optimization opportunities
- Cost estimates

### Code Quality
- Solidity best practices
- Documentation completeness
- Error handling patterns

## 📊 Summary

Check individual report files for detailed results:
- \`security-analysis-report.json\` - Security vulnerabilities
- \`gas-analysis-*.json\` - Gas optimization opportunities
- \`solhint-report.json\` - Code quality issues
- \`test-results.json\` - Test execution results
- \`coverage-report.json\` - Code coverage metrics

## 🎯 Recommendations

1. **High Priority**: Address any HIGH severity security issues
2. **Medium Priority**: Implement suggested gas optimizations
3. **Low Priority**: Follow best practice recommendations
4. **Testing**: Ensure comprehensive test coverage (>90%)
5. **Documentation**: Add missing function/contract documentation

## ⚠️ Disclaimer

This is an automated analysis. Manual review by security experts
is recommended for production contracts handling significant value.

---
*Generated by Smart Contract Security Toolkit*
EOF

    print_success "Audit summary generated: $summary_file"
}

# Function to setup the toolkit
setup_toolkit() {
    print_status "Setting up Smart Contract Security Toolkit..."
    
    # Make scripts executable
    chmod +x "$TOOLS_DIR/audit-toolkit.sh"
    chmod +x "$TOOLS_DIR/security-analyzer.js"
    chmod +x "$TOOLS_DIR/gas-analyzer.py"
    
    # Check for external tools
    print_status "Checking for external security tools..."
    
    echo "Available tools:"
    check_tool "node" && echo "  ✓ Node.js (required)"
    check_tool "python3" && echo "  ✓ Python 3 (required)"
    check_tool "solhint" && echo "  ✓ Solhint (recommended)"
    check_tool "slither" && echo "  ✓ Slither (recommended)"
    check_tool "mythx" && echo "  ✓ MythX (optional)"
    check_tool "npx" && echo "  ✓ NPX (for Hardhat)"
    
    print_success "Toolkit setup completed"
}

# Function to show help
show_help() {
    cat << EOF
Smart Contract Security Toolkit

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    setup                   Setup the toolkit and check dependencies
    security <file>         Run security analysis on a contract
    gas <file>             Run gas analysis on a contract
    solhint <file>         Run Solhint static analysis
    test                   Run Hardhat tests
    coverage               Run coverage analysis
    audit <file>           Run comprehensive audit (all analyses)
    help                   Show this help message

Examples:
    $0 setup
    $0 security ./contracts/MyContract.sol
    $0 gas ./contracts/MyContract.sol
    $0 audit ./contracts/MyContract.sol

Options:
    -h, --help             Show help message
    -v, --verbose          Verbose output

External Tools (install separately for enhanced functionality):
    - Solhint: npm install -g solhint
    - Slither: pip install slither-analyzer
    - MythX: pip install mythx-cli

EOF
}

# Main script logic
main() {
    case "${1:-help}" in
        "setup")
            setup_toolkit
            install_dependencies
            ;;
        "security")
            if [ -z "$2" ]; then
                print_error "Please provide a contract file"
                show_help
                exit 1
            fi
            run_security_analysis "$2"
            ;;
        "gas")
            if [ -z "$2" ]; then
                print_error "Please provide a contract file"
                show_help
                exit 1
            fi
            run_gas_analysis "$2"
            ;;
        "solhint")
            if [ -z "$2" ]; then
                print_error "Please provide a contract file"
                show_help
                exit 1
            fi
            run_solhint_analysis "$2"
            ;;
        "test")
            run_hardhat_tests
            ;;
        "coverage")
            run_coverage_analysis
            ;;
        "audit")
            if [ -z "$2" ]; then
                print_error "Please provide a contract file"
                show_help
                exit 1
            fi
            run_full_audit "$2"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"