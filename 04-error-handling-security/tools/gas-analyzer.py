#!/usr/bin/env python3

"""
Gas Usage Analyzer for Solidity Contracts
Analyzes gas consumption patterns and suggests optimizations
"""

import re
import json
import sys
from datetime import datetime
from typing import List, Dict, Tuple

class GasAnalyzer:
    def __init__(self):
        self.gas_patterns = {
            'storage_operations': {
                'sstore': {'base_cost': 20000, 'description': 'Storage write operation'},
                'sload': {'base_cost': 800, 'description': 'Storage read operation'},
            },
            'loop_operations': {
                'for_loop': {'base_cost': 3, 'description': 'For loop iteration'},
                'while_loop': {'base_cost': 3, 'description': 'While loop iteration'},
            },
            'function_calls': {
                'external_call': {'base_cost': 700, 'description': 'External function call'},
                'internal_call': {'base_cost': 24, 'description': 'Internal function call'},
            },
            'data_types': {
                'uint256': {'base_cost': 3, 'description': 'uint256 operation'},
                'uint128': {'base_cost': 3, 'description': 'uint128 operation'},
                'uint64': {'base_cost': 3, 'description': 'uint64 operation'},
                'bytes32': {'base_cost': 3, 'description': 'bytes32 operation'},
                'string': {'base_cost': 32, 'description': 'String operation'},
            }
        }
        
        self.optimizations = []
        self.gas_hotspots = []
        self.analysis_results = {}

    def analyze_contract(self, file_path: str) -> Dict:
        """Analyze gas usage patterns in Solidity contract"""
        print(f" Analyzing gas usage: {file_path}")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                contract_code = file.read()
        except FileNotFoundError:
            print(f" File not found: {file_path}")
            return {}
        
        # Perform various gas analyses
        self.analyze_storage_usage(contract_code)
        self.analyze_loop_patterns(contract_code)
        self.analyze_function_patterns(contract_code)
        self.analyze_data_types(contract_code)
        self.analyze_array_operations(contract_code)
        self.analyze_mapping_operations(contract_code)
        self.suggest_optimizations(contract_code)
        
        # Generate report
        return self.generate_gas_report(file_path)

    def analyze_storage_usage(self, code: str):
        """Analyze storage variable usage patterns"""
        print(" Analyzing storage usage...")
        
        # Find storage variable declarations
        storage_vars = re.findall(r'^\s*(uint\d*|int\d*|bool|address|bytes\d*|string)\s+(?:public\s+|private\s+|internal\s+)?(\w+)', code, re.MULTILINE)
        
        # Find storage assignments
        storage_writes = len(re.findall(r'\w+\s*=\s*[^=]', code))
        
        # Estimate storage costs
        estimated_storage_cost = len(storage_vars) * 20000 + storage_writes * 5000
        
        self.gas_hotspots.append({
            'type': 'STORAGE_USAGE',
            'severity': 'MEDIUM' if len(storage_vars) > 10 else 'LOW',
            'description': f'Found {len(storage_vars)} storage variables, {storage_writes} assignments',
            'estimated_cost': estimated_storage_cost,
            'optimization': 'Consider packing variables, using memory for temporary data'
        })

    def analyze_loop_patterns(self, code: str):
        """Analyze loop patterns for gas efficiency"""
        print(" Analyzing loop patterns...")
        
        # Find different types of loops
        for_loops = re.findall(r'for\s*\([^)]+\)\s*{([^}]+)}', code, re.DOTALL)
        while_loops = re.findall(r'while\s*\([^)]+\)\s*{([^}]+)}', code, re.DOTALL)
        
        # Analyze loop contents for expensive operations
        expensive_in_loops = 0
        for loop in for_loops + while_loops:
            # Check for storage operations in loops
            if re.search(r'\w+\s*\[\s*\w+\s*\]\s*=', loop):
                expensive_in_loops += 1
            # Check for external calls in loops
            if re.search(r'\w+\.\w+\s*\(', loop):
                expensive_in_loops += 1
        
        if for_loops or while_loops:
            total_loops = len(for_loops) + len(while_loops)
            estimated_cost = total_loops * 1000 + expensive_in_loops * 10000
            
            self.gas_hotspots.append({
                'type': 'LOOP_OPERATIONS',
                'severity': 'HIGH' if expensive_in_loops > 0 else 'MEDIUM',
                'description': f'Found {total_loops} loops, {expensive_in_loops} with expensive operations',
                'estimated_cost': estimated_cost,
                'optimization': 'Minimize storage operations and external calls in loops'
            })

    def analyze_function_patterns(self, code: str):
        """Analyze function call patterns"""
        print(" Analyzing function patterns...")
        
        # Find function definitions
        functions = re.findall(r'function\s+(\w+)\s*\([^)]*\)\s*(external|public|internal|private)?\s*(view|pure|payable)?\s*(?:returns\s*\([^)]*\))?\s*{', code)
        
        # Find external calls
        external_calls = len(re.findall(r'\w+\.\w+\s*\(', code))
        
        # Find delegate calls (expensive)
        delegate_calls = len(re.findall(r'delegatecall\s*\(', code))
        
        estimated_cost = len(functions) * 500 + external_calls * 700 + delegate_calls * 700
        
        self.gas_hotspots.append({
            'type': 'FUNCTION_CALLS',
            'severity': 'MEDIUM',
            'description': f'Found {len(functions)} functions, {external_calls} external calls, {delegate_calls} delegate calls',
            'estimated_cost': estimated_cost,
            'optimization': 'Use internal functions when possible, batch external calls'
        })

    def analyze_data_types(self, code: str):
        """Analyze data type usage for gas efficiency"""
        print(" Analyzing data types...")
        
        # Count different data types
        type_counts = {
            'uint256': len(re.findall(r'\buint256\b', code)),
            'uint128': len(re.findall(r'\buint128\b', code)),
            'uint64': len(re.findall(r'\buint64\b', code)),
            'uint32': len(re.findall(r'\buint32\b', code)),
            'uint': len(re.findall(r'\buint\b(?!\d)', code)),
            'string': len(re.findall(r'\bstring\b', code)),
            'bytes': len(re.findall(r'\bbytes\d*\b', code)),
        }
        
        # Suggest optimizations based on type usage
        if type_counts['string'] > type_counts['bytes']:
            self.optimizations.append({
                'type': 'DATA_TYPE_OPTIMIZATION',
                'description': f'Consider using bytes32 instead of string for fixed-length data ({type_counts["string"]} string usages found)',
                'gas_savings': type_counts['string'] * 20
            })
        
        if type_counts['uint256'] > type_counts['uint'] * 2:
            self.optimizations.append({
                'type': 'DATA_TYPE_OPTIMIZATION',
                'description': f'Consider using uint instead of uint256 where possible ({type_counts["uint256"]} uint256 usages found)',
                'gas_savings': type_counts['uint256'] * 5
            })

    def analyze_array_operations(self, code: str):
        """Analyze array operations for gas efficiency"""
        print(" Analyzing array operations...")
        
        # Find array declarations
        arrays = re.findall(r'(\w+(?:\[\])?\s+(?:public\s+|private\s+|internal\s+)?(\w+)(?:\[\])?)', code)
        
        # Find array operations
        array_push = len(re.findall(r'\.push\s*\(', code))
        array_pop = len(re.findall(r'\.pop\s*\(', code))
        array_access = len(re.findall(r'\w+\s*\[\s*\d+\s*\]', code))
        
        if array_push + array_pop + array_access > 0:
            estimated_cost = array_push * 20000 + array_pop * 5000 + array_access * 800
            
            self.gas_hotspots.append({
                'type': 'ARRAY_OPERATIONS',
                'severity': 'MEDIUM' if estimated_cost > 50000 else 'LOW',
                'description': f'Array operations: {array_push} push, {array_pop} pop, {array_access} access',
                'estimated_cost': estimated_cost,
                'optimization': 'Consider using mappings for large datasets, batch array operations'
            })

    def analyze_mapping_operations(self, code: str):
        """Analyze mapping operations"""
        print(" Analyzing mapping operations...")
        
        # Find mapping declarations
        mappings = re.findall(r'mapping\s*\([^)]+\)\s*(?:public\s+|private\s+|internal\s+)?(\w+)', code)
        
        # Find mapping access patterns
        mapping_reads = len(re.findall(r'\w+\s*\[\s*\w+\s*\](?!\s*=)', code))
        mapping_writes = len(re.findall(r'\w+\s*\[\s*\w+\s*\]\s*=', code))
        
        if mapping_reads + mapping_writes > 0:
            estimated_cost = mapping_reads * 800 + mapping_writes * 20000
            
            self.gas_hotspots.append({
                'type': 'MAPPING_OPERATIONS',
                'severity': 'LOW',
                'description': f'Mapping operations: {mapping_reads} reads, {mapping_writes} writes',
                'estimated_cost': estimated_cost,
                'optimization': 'Mappings are generally gas-efficient for key-value storage'
            })

    def suggest_optimizations(self, code: str):
        """Suggest specific gas optimizations"""
        print(" Generating optimization suggestions...")
        
        # Check for common gas inefficiencies
        self._check_constant_variables(code)
        self._check_function_visibility(code)
        self._check_require_statements(code)
        self._check_event_usage(code)
        self._check_struct_packing(code)

    def _check_constant_variables(self, code: str):
        """Check for variables that could be constant"""
        # Find variables that are only assigned once
        variable_assignments = re.findall(r'(\w+)\s*=\s*([^;]+);', code)
        for var, value in variable_assignments:
            if re.search(r'\b(0x[0-9a-fA-F]+|\d+|true|false|"[^"]*")\b', value):
                self.optimizations.append({
                    'type': 'CONSTANT_OPTIMIZATION',
                    'description': f'Variable "{var}" could be marked as constant if not modified',
                    'gas_savings': 2300
                })

    def _check_function_visibility(self, code: str):
        """Check function visibility optimizations"""
        public_functions = len(re.findall(r'function\s+\w+\s*\([^)]*\)\s*public', code))
        if public_functions > 0:
            self.optimizations.append({
                'type': 'VISIBILITY_OPTIMIZATION',
                'description': f'Consider making functions internal/private if not called externally ({public_functions} public functions found)',
                'gas_savings': public_functions * 50
            })

    def _check_require_statements(self, code: str):
        """Check require statement optimizations"""
        require_statements = len(re.findall(r'require\s*\(', code))
        if require_statements > 0 and not re.search(r'error\s+\w+', code):
            self.optimizations.append({
                'type': 'ERROR_OPTIMIZATION',
                'description': f'Consider using custom errors instead of require strings ({require_statements} require statements found)',
                'gas_savings': require_statements * 100
            })

    def _check_event_usage(self, code: str):
        """Check event usage for gas optimization"""
        events = len(re.findall(r'event\s+\w+', code))
        emits = len(re.findall(r'emit\s+\w+', code))
        
        if events > emits:
            self.optimizations.append({
                'type': 'EVENT_OPTIMIZATION',
                'description': f'Some events are declared but not emitted ({events} events, {emits} emits)',
                'gas_savings': (events - emits) * 375
            })

    def _check_struct_packing(self, code: str):
        """Check struct packing optimizations"""
        structs = re.findall(r'struct\s+\w+\s*{([^}]+)}', code, re.DOTALL)
        
        for struct in structs:
            # Simple check for potential packing issues
            uint256_count = len(re.findall(r'uint256', struct))
            smaller_uint_count = len(re.findall(r'uint(?:8|16|32|64|128)', struct))
            
            if uint256_count > 0 and smaller_uint_count > 0:
                self.optimizations.append({
                    'type': 'STRUCT_PACKING',
                    'description': f'Struct may benefit from variable packing (reorder smaller types together)',
                    'gas_savings': 2000
                })

    def generate_gas_report(self, file_path: str) -> Dict:
        """Generate comprehensive gas analysis report"""
        total_estimated_cost = sum(hotspot['estimated_cost'] for hotspot in self.gas_hotspots)
        total_potential_savings = sum(opt['gas_savings'] for opt in self.optimizations)
        
        report = {
            'file_path': file_path,
            'analysis_timestamp': datetime.now().isoformat(),
            'summary': {
                'total_estimated_cost': total_estimated_cost,
                'total_potential_savings': total_potential_savings,
                'efficiency_score': max(0, 100 - (total_estimated_cost // 1000)),
                'hotspot_count': len(self.gas_hotspots),
                'optimization_count': len(self.optimizations)
            },
            'gas_hotspots': self.gas_hotspots,
            'optimizations': self.optimizations
        }
        
        self.print_gas_report(report)
        self.save_gas_report(report)
        
        return report

    def print_gas_report(self, report: Dict):
        """Print formatted gas analysis report"""
        print('\n' + '='*60)
        print(' GAS USAGE ANALYSIS REPORT')
        print('='*60)
        print(f" File: {report['file_path']}")
        print(f" Analysis Date: {report['analysis_timestamp']}")
        print(f" Estimated Total Cost: {report['summary']['total_estimated_cost']:,} gas")
        print(f" Potential Savings: {report['summary']['total_potential_savings']:,} gas")
        print(f" Efficiency Score: {report['summary']['efficiency_score']}/100")
        
        # Efficiency rating
        score = report['summary']['efficiency_score']
        if score >= 90:
            print(' Gas Efficiency: EXCELLENT')
        elif score >= 75:
            print('  Gas Efficiency: GOOD')
        elif score >= 50:
            print(' Gas Efficiency: NEEDS IMPROVEMENT')
        else:
            print(' Gas Efficiency: CRITICAL OPTIMIZATION NEEDED')
        
        if self.gas_hotspots:
            print('\n GAS HOTSPOTS:')
            print('-'*40)
            for i, hotspot in enumerate(self.gas_hotspots, 1):
                print(f"{i}. [{hotspot['severity']}] {hotspot['type']}")
                print(f"   Description: {hotspot['description']}")
                print(f"   Estimated Cost: {hotspot['estimated_cost']:,} gas")
                print(f"   Optimization: {hotspot['optimization']}")
                print()
        
        if self.optimizations:
            print('\n OPTIMIZATION SUGGESTIONS:')
            print('-'*40)
            for i, opt in enumerate(self.optimizations, 1):
                print(f"{i}. {opt['type']}")
                print(f"   Description: {opt['description']}")
                print(f"   Potential Savings: {opt['gas_savings']:,} gas")
                print()
        
        print('\n GAS OPTIMIZATION BEST PRACTICES:')
        print('-'*40)
        print('1. Use appropriate data types (uint instead of uint256)')
        print('2. Pack structs efficiently (group smaller types)')
        print('3. Use constant and immutable for unchanging values')
        print('4. Prefer internal/private over public functions')
        print('5. Use custom errors instead of require strings')
        print('6. Minimize storage operations, especially in loops')
        print('7. Use events instead of storing non-critical data')
        print('8. Consider using mappings over arrays for large datasets')
        print('9. Batch operations when possible')
        print('10. Use view/pure functions when not modifying state')

    def save_gas_report(self, report: Dict):
        """Save gas analysis report to JSON file"""
        filename = f"gas-analysis-{datetime.now().strftime('%Y%m%d-%H%M%S')}.json"
        with open(filename, 'w') as f:
            json.dump(report, f, indent=2)
        print(f"\n Gas analysis report saved to: {filename}")

def main():
    """Main CLI function"""
    if len(sys.argv) != 2:
        print("Usage: python gas-analyzer.py <contract-file>")
        print("Example: python gas-analyzer.py ./contracts/MyContract.sol")
        sys.exit(1)
    
    contract_file = sys.argv[1]
    analyzer = GasAnalyzer()
    analyzer.analyze_contract(contract_file)

if __name__ == "__main__":
    main()