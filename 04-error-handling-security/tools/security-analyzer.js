#!/usr/bin/env node

/**
 * Smart Contract Security Analysis Tool
 * Automated security scanning and vulnerability detection
 */

const fs = require('fs');
const path = require('path');

class SecurityAnalyzer {
    constructor() {
        this.vulnerabilities = [];
        this.gasOptimizations = [];
        this.bestPractices = [];
        this.securityScore = 100;
    }

    /**
     * Analyze Solidity contract for security vulnerabilities
     */
    analyzeContract(contractPath) {
        console.log(` Analyzing: ${contractPath}`);
        
        if (!fs.existsSync(contractPath)) {
            console.error(` File not found: ${contractPath}`);
            return;
        }

        const contractCode = fs.readFileSync(contractPath, 'utf8');
        
        // Run all security checks
        this.checkReentrancy(contractCode);
        this.checkAccessControl(contractCode);
        this.checkIntegerOverflow(contractCode);
        this.checkUncheckedCalls(contractCode);
        this.checkTimestampDependence(contractCode);
        this.checkTxOriginUsage(contractCode);
        this.checkRandomnessVulnerabilities(contractCode);
        this.checkGasOptimization(contractCode);
        this.checkBestPractices(contractCode);
        
        this.generateReport();
    }

    /**
     * Check for reentrancy vulnerabilities
     */
    checkReentrancy(code) {
        const patterns = [
            {
                regex: /\.call\s*\(/g,
                severity: 'HIGH',
                description: 'Low-level call detected - potential reentrancy risk'
            },
            {
                regex: /\.send\s*\(/g,
                severity: 'MEDIUM',
                description: 'Use of .send() - consider .transfer() or .call()'
            },
            {
                regex: /external.*payable.*{[^}]*(?!nonReentrant)/gs,
                severity: 'HIGH',
                description: 'Payable external function without reentrancy protection'
            }
        ];

        this.checkPatterns(code, patterns, 'REENTRANCY');
        
        // Check for ReentrancyGuard usage
        if (!code.includes('ReentrancyGuard') && !code.includes('nonReentrant')) {
            this.vulnerabilities.push({
                type: 'REENTRANCY',
                severity: 'MEDIUM',
                line: 0,
                description: 'Contract lacks reentrancy protection mechanism'
            });
        }
    }

    /**
     * Check access control implementation
     */
    checkAccessControl(code) {
        const patterns = [
            {
                regex: /function\s+\w+\s*\([^)]*\)\s*external\s*{[^}]*(?!onlyOwner|onlyRole|require)/gs,
                severity: 'MEDIUM',
                description: 'External function without access control'
            },
            {
                regex: /selfdestruct\s*\(/g,
                severity: 'HIGH',
                description: 'Use of selfdestruct - ensure proper access control'
            },
            {
                regex: /delegatecall\s*\(/g,
                severity: 'HIGH',
                description: 'Use of delegatecall - potential security risk'
            }
        ];

        this.checkPatterns(code, patterns, 'ACCESS_CONTROL');

        // Check for proper access control imports
        if (!code.includes('Ownable') && !code.includes('AccessControl')) {
            this.vulnerabilities.push({
                type: 'ACCESS_CONTROL',
                severity: 'MEDIUM',
                line: 0,
                description: 'No standard access control mechanism detected'
            });
        }
    }

    /**
     * Check for integer overflow/underflow
     */
    checkIntegerOverflow(code) {
        const patterns = [
            {
                regex: /\+\+|\-\-/g,
                severity: 'LOW',
                description: 'Increment/decrement operations - check for overflow'
            },
            {
                regex: /\w+\s*\+=\s*\w+/g,
                severity: 'LOW',
                description: 'Addition assignment - potential overflow'
            },
            {
                regex: /\w+\s*\-=\s*\w+/g,
                severity: 'LOW',
                description: 'Subtraction assignment - potential underflow'
            }
        ];

        // Check Solidity version for built-in overflow protection
        const versionMatch = code.match(/pragma\s+solidity\s+[^;]+;/);
        if (versionMatch) {
            const version = versionMatch[0];
            if (!version.includes('0.8') && !code.includes('SafeMath')) {
                this.vulnerabilities.push({
                    type: 'INTEGER_OVERFLOW',
                    severity: 'HIGH',
                    line: 0,
                    description: 'Pre-0.8.0 Solidity without SafeMath - overflow risk'
                });
            }
        }

        this.checkPatterns(code, patterns, 'INTEGER_OVERFLOW');
    }

    /**
     * Check for unchecked external calls
     */
    checkUncheckedCalls(code) {
        const patterns = [
            {
                regex: /\.call\s*\([^)]*\)\s*;/g,
                severity: 'HIGH',
                description: 'Unchecked low-level call'
            },
            {
                regex: /\.send\s*\([^)]*\)\s*;/g,
                severity: 'MEDIUM',
                description: 'Unchecked send call'
            },
            {
                regex: /\.transfer\s*\([^)]*\)\s*;/g,
                severity: 'LOW',
                description: 'Transfer call - consider error handling'
            }
        ];

        this.checkPatterns(code, patterns, 'UNCHECKED_CALLS');
    }

    /**
     * Check for timestamp dependence
     */
    checkTimestampDependence(code) {
        const patterns = [
            {
                regex: /block\.timestamp/g,
                severity: 'MEDIUM',
                description: 'Use of block.timestamp - miner manipulation risk'
            },
            {
                regex: /now\b/g,
                severity: 'MEDIUM',
                description: 'Use of "now" keyword - deprecated, use block.timestamp'
            },
            {
                regex: /block\.number/g,
                severity: 'LOW',
                description: 'Use of block.number for timing - consider implications'
            }
        ];

        this.checkPatterns(code, patterns, 'TIMESTAMP_DEPENDENCE');
    }

    /**
     * Check for tx.origin usage
     */
    checkTxOriginUsage(code) {
        const patterns = [
            {
                regex: /tx\.origin/g,
                severity: 'HIGH',
                description: 'Use of tx.origin - phishing attack vulnerability'
            }
        ];

        this.checkPatterns(code, patterns, 'TX_ORIGIN');
    }

    /**
     * Check for weak randomness
     */
    checkRandomnessVulnerabilities(code) {
        const patterns = [
            {
                regex: /keccak256\s*\([^)]*block\.timestamp[^)]*\)/g,
                severity: 'HIGH',
                description: 'Weak randomness using block.timestamp'
            },
            {
                regex: /keccak256\s*\([^)]*block\.difficulty[^)]*\)/g,
                severity: 'HIGH',
                description: 'Weak randomness using block.difficulty'
            },
            {
                regex: /keccak256\s*\([^)]*blockhash[^)]*\)/g,
                severity: 'MEDIUM',
                description: 'Potentially weak randomness using blockhash'
            }
        ];

        this.checkPatterns(code, patterns, 'WEAK_RANDOMNESS');
    }

    /**
     * Check for gas optimization opportunities
     */
    checkGasOptimization(code) {
        const optimizations = [
            {
                regex: /uint256/g,
                severity: 'INFO',
                description: 'Consider using uint for gas optimization'
            },
            {
                regex: /string\s+memory/g,
                severity: 'INFO',
                description: 'String memory usage - consider bytes32 if possible'
            },
            {
                regex: /for\s*\([^)]*\)\s*{[^}]*\.push\(/gs,
                severity: 'INFO',
                description: 'Array push in loop - potential gas optimization'
            },
            {
                regex: /mapping\s*\([^)]*\)\s*public/g,
                severity: 'INFO',
                description: 'Public mapping - consider gas costs for getter'
            }
        ];

        optimizations.forEach(opt => {
            const matches = code.match(opt.regex);
            if (matches) {
                this.gasOptimizations.push({
                    type: 'GAS_OPTIMIZATION',
                    count: matches.length,
                    description: opt.description
                });
            }
        });
    }

    /**
     * Check for best practices
     */
    checkBestPractices(code) {
        const practices = [
            {
                check: !code.includes('SPDX-License-Identifier'),
                description: 'Missing SPDX license identifier'
            },
            {
                check: !code.includes('@dev') && !code.includes('@notice'),
                description: 'Missing comprehensive documentation'
            },
            {
                check: !code.includes('emit '),
                description: 'No events emitted - consider for transparency'
            },
            {
                check: !code.includes('error ') && code.includes('pragma solidity ^0.8'),
                description: 'Consider using custom errors for gas efficiency'
            },
            {
                check: code.includes('selfdestruct') && !code.includes('onlyOwner'),
                description: 'Selfdestruct without proper access control'
            }
        ];

        practices.forEach(practice => {
            if (practice.check) {
                this.bestPractices.push({
                    type: 'BEST_PRACTICE',
                    description: practice.description
                });
            }
        });
    }

    /**
     * Helper function to check patterns
     */
    checkPatterns(code, patterns, type) {
        patterns.forEach(pattern => {
            const matches = code.match(pattern.regex);
            if (matches) {
                const lines = this.getLineNumbers(code, pattern.regex);
                lines.forEach(line => {
                    this.vulnerabilities.push({
                        type: type,
                        severity: pattern.severity,
                        line: line,
                        description: pattern.description
                    });
                });
            }
        });
    }

    /**
     * Get line numbers for matches
     */
    getLineNumbers(code, regex) {
        const lines = code.split('\n');
        const lineNumbers = [];
        
        lines.forEach((line, index) => {
            if (regex.test(line)) {
                lineNumbers.push(index + 1);
            }
        });
        
        return lineNumbers;
    }

    /**
     * Calculate security score
     */
    calculateSecurityScore() {
        let score = 100;
        
        this.vulnerabilities.forEach(vuln => {
            switch (vuln.severity) {
                case 'HIGH':
                    score -= 20;
                    break;
                case 'MEDIUM':
                    score -= 10;
                    break;
                case 'LOW':
                    score -= 5;
                    break;
            }
        });

        this.bestPractices.forEach(() => {
            score -= 2;
        });

        return Math.max(0, score);
    }

    /**
     * Generate comprehensive security report
     */
    generateReport() {
        const score = this.calculateSecurityScore();
        const timestamp = new Date().toISOString();
        
        console.log('\n' + '='.repeat(60));
        console.log(' SMART CONTRACT SECURITY ANALYSIS REPORT');
        console.log('='.repeat(60));
        console.log(` Analysis Date: ${timestamp}`);
        console.log(` Security Score: ${score}/100`);
        
        if (score >= 90) {
            console.log(' Security Level: EXCELLENT');
        } else if (score >= 75) {
            console.log('  Security Level: GOOD');
        } else if (score >= 50) {
            console.log(' Security Level: NEEDS IMPROVEMENT');
        } else {
            console.log(' Security Level: CRITICAL ISSUES');
        }
        
        console.log('\n VULNERABILITY SUMMARY:');
        console.log('-'.repeat(40));
        
        const severityCounts = {
            HIGH: 0,
            MEDIUM: 0,
            LOW: 0
        };
        
        this.vulnerabilities.forEach(vuln => {
            severityCounts[vuln.severity]++;
        });
        
        console.log(` High Severity: ${severityCounts.HIGH}`);
        console.log(`🟡 Medium Severity: ${severityCounts.MEDIUM}`);
        console.log(`🟢 Low Severity: ${severityCounts.LOW}`);
        
        if (this.vulnerabilities.length > 0) {
            console.log('\n DETAILED VULNERABILITIES:');
            console.log('-'.repeat(40));
            
            this.vulnerabilities.forEach((vuln, index) => {
                console.log(`${index + 1}. [${vuln.severity}] ${vuln.type}`);
                console.log(`   Line: ${vuln.line || 'Multiple'}`);
                console.log(`   Description: ${vuln.description}`);
                console.log('');
            });
        }
        
        if (this.gasOptimizations.length > 0) {
            console.log('\n GAS OPTIMIZATION OPPORTUNITIES:');
            console.log('-'.repeat(40));
            
            this.gasOptimizations.forEach((opt, index) => {
                console.log(`${index + 1}. ${opt.description}`);
                console.log(`   Occurrences: ${opt.count}`);
                console.log('');
            });
        }
        
        if (this.bestPractices.length > 0) {
            console.log('\n BEST PRACTICE RECOMMENDATIONS:');
            console.log('-'.repeat(40));
            
            this.bestPractices.forEach((practice, index) => {
                console.log(`${index + 1}. ${practice.description}`);
            });
        }
        
        console.log('\n SECURITY RECOMMENDATIONS:');
        console.log('-'.repeat(40));
        console.log('1. Use OpenZeppelin contracts for standard functionality');
        console.log('2. Implement comprehensive access controls');
        console.log('3. Add reentrancy protection to state-changing functions');
        console.log('4. Use events for transparency and off-chain monitoring');
        console.log('5. Implement proper error handling and validation');
        console.log('6. Consider using multi-signature for critical operations');
        console.log('7. Conduct thorough testing and formal audits');
        console.log('8. Monitor contract interactions post-deployment');
        
        // Save report to file
        this.saveReportToFile(score, timestamp);
        
        console.log('\n Analysis Complete!');
        console.log(' Report saved to: security-analysis-report.json');
    }

    /**
     * Save report to JSON file
     */
    saveReportToFile(score, timestamp) {
        const report = {
            timestamp,
            securityScore: score,
            vulnerabilities: this.vulnerabilities,
            gasOptimizations: this.gasOptimizations,
            bestPractices: this.bestPractices,
            summary: {
                totalVulnerabilities: this.vulnerabilities.length,
                highSeverity: this.vulnerabilities.filter(v => v.severity === 'HIGH').length,
                mediumSeverity: this.vulnerabilities.filter(v => v.severity === 'MEDIUM').length,
                lowSeverity: this.vulnerabilities.filter(v => v.severity === 'LOW').length
            }
        };
        
        fs.writeFileSync(
            'security-analysis-report.json',
            JSON.stringify(report, null, 2)
        );
    }
}

// CLI Usage
if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log('Usage: node security-analyzer.js <contract-file>');
        console.log('Example: node security-analyzer.js ./contracts/MyContract.sol');
        process.exit(1);
    }
    
    const contractPath = args[0];
    const analyzer = new SecurityAnalyzer();
    analyzer.analyzeContract(contractPath);
}

module.exports = SecurityAnalyzer;