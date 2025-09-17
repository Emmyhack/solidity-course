// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Advanced Array Operations
 * @dev Comprehensive guide to array manipulation, optimization, and patterns
 *
 * This contract demonstrates:
 * - Dynamic array operations and gas optimization
 * - Multidimensional arrays and complex structures
 * - Memory vs storage considerations
 * - Sorting and searching algorithms
 * - Pagination and efficient data access
 * - Array state management patterns
 */

contract AdvancedArrays {
    // ======================
    // STATE VARIABLES
    // ======================

    // Dynamic arrays for different use cases
    uint256[] public numbers;
    address[] public users;
    string[] public messages;

    // Fixed-size arrays for optimization
    uint256[10] public fixedNumbers;
    address[5] public admins;

    // Multidimensional arrays
    uint256[][] public matrix;
    mapping(address => uint256[]) public userNumbers;

    // Array metadata for efficient operations
    mapping(address => uint256) public userArrayLengths;
    mapping(uint256 => bool) public numberExists;

    // Pagination support
    uint256 public constant PAGE_SIZE = 10;

    // Events for array operations
    event ArrayUpdated(string arrayName, uint256 newLength);
    event ElementAdded(string arrayName, uint256 index, string element);
    event ElementRemoved(string arrayName, uint256 index);
    event ArraySorted(string arrayName, uint256 length);

    // ======================
    // BASIC ARRAY OPERATIONS
    // ======================

    /**
     * @dev Add elements to dynamic arrays with gas optimization
     */
    function addNumbers(uint256[] memory _numbers) public {
        for (uint256 i = 0; i < _numbers.length; i++) {
            numbers.push(_numbers[i]);
            numberExists[_numbers[i]] = true;
        }
        emit ArrayUpdated("numbers", numbers.length);
    }

    /**
     * @dev Remove element by value (expensive operation)
     */
    function removeNumberByValue(uint256 _value) public {
        require(numberExists[_value], "Number does not exist");

        for (uint256 i = 0; i < numbers.length; i++) {
            if (numbers[i] == _value) {
                removeNumberByIndex(i);
                break;
            }
        }
        numberExists[_value] = false;
    }

    /**
     * @dev Remove element by index (more efficient)
     */
    function removeNumberByIndex(uint256 _index) public {
        require(_index < numbers.length, "Index out of bounds");

        // Move last element to deleted position (unordered removal)
        numbers[_index] = numbers[numbers.length - 1];
        numbers.pop();

        emit ElementRemoved("numbers", _index);
        emit ArrayUpdated("numbers", numbers.length);
    }

    /**
     * @dev Remove element maintaining order (expensive)
     */
    function removeNumberByIndexOrdered(uint256 _index) public {
        require(_index < numbers.length, "Index out of bounds");

        // Shift all elements after index to the left
        for (uint256 i = _index; i < numbers.length - 1; i++) {
            numbers[i] = numbers[i + 1];
        }
        numbers.pop();

        emit ElementRemoved("numbers", _index);
        emit ArrayUpdated("numbers", numbers.length);
    }

    // ======================
    // MULTIDIMENSIONAL ARRAYS
    // ======================

    /**
     * @dev Initialize a 2D matrix
     */
    function initializeMatrix(uint256 _rows, uint256 _cols) public {
        // Clear existing matrix
        delete matrix;

        // Initialize with specified dimensions
        for (uint256 i = 0; i < _rows; i++) {
            matrix.push();
            for (uint256 j = 0; j < _cols; j++) {
                matrix[i].push(0);
            }
        }

        emit ArrayUpdated("matrix", _rows);
    }

    /**
     * @dev Set value in 2D matrix
     */
    function setMatrixValue(uint256 _row, uint256 _col, uint256 _value) public {
        require(_row < matrix.length, "Row index out of bounds");
        require(_col < matrix[_row].length, "Column index out of bounds");

        matrix[_row][_col] = _value;
    }

    /**
     * @dev Get matrix dimensions
     */
    function getMatrixDimensions()
        public
        view
        returns (uint256 rows, uint256 cols)
    {
        rows = matrix.length;
        cols = matrix.length > 0 ? matrix[0].length : 0;
    }

    /**
     * @dev Add row to matrix
     */
    function addMatrixRow(uint256[] memory _rowData) public {
        if (matrix.length > 0) {
            require(_rowData.length == matrix[0].length, "Row size mismatch");
        }
        matrix.push(_rowData);
        emit ArrayUpdated("matrix", matrix.length);
    }

    // ======================
    // USER-SPECIFIC ARRAYS
    // ======================

    /**
     * @dev Add numbers for a specific user
     */
    function addUserNumbers(address _user, uint256[] memory _numbers) public {
        for (uint256 i = 0; i < _numbers.length; i++) {
            userNumbers[_user].push(_numbers[i]);
        }
        userArrayLengths[_user] = userNumbers[_user].length;
        emit ArrayUpdated("userNumbers", userNumbers[_user].length);
    }

    /**
     * @dev Get user numbers with pagination
     */
    function getUserNumbers(
        address _user,
        uint256 _page
    ) public view returns (uint256[] memory pageNumbers, bool hasMore) {
        uint256[] storage userNums = userNumbers[_user];
        uint256 startIndex = _page * PAGE_SIZE;

        if (startIndex >= userNums.length) {
            return (new uint256[](0), false);
        }

        uint256 endIndex = startIndex + PAGE_SIZE;
        if (endIndex > userNums.length) {
            endIndex = userNums.length;
        }

        uint256 pageLength = endIndex - startIndex;
        pageNumbers = new uint256[](pageLength);

        for (uint256 i = 0; i < pageLength; i++) {
            pageNumbers[i] = userNums[startIndex + i];
        }

        hasMore = endIndex < userNums.length;
    }

    // ======================
    // SORTING ALGORITHMS
    // ======================

    /**
     * @dev Bubble sort (for small arrays only - high gas cost)
     */
    function bubbleSortNumbers() public {
        uint256 length = numbers.length;

        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (numbers[j] > numbers[j + 1]) {
                    // Swap elements
                    uint256 temp = numbers[j];
                    numbers[j] = numbers[j + 1];
                    numbers[j + 1] = temp;
                }
            }
        }

        emit ArraySorted("numbers", length);
    }

    /**
     * @dev Quick sort implementation (more efficient for larger arrays)
     */
    function quickSortNumbers() public {
        if (numbers.length > 1) {
            _quickSort(0, numbers.length - 1);
            emit ArraySorted("numbers", numbers.length);
        }
    }

    /**
     * @dev Internal quick sort recursive function
     */
    function _quickSort(uint256 _low, uint256 _high) internal {
        if (_low < _high) {
            uint256 pivot = _partition(_low, _high);

            if (pivot > 0) {
                _quickSort(_low, pivot - 1);
            }
            _quickSort(pivot + 1, _high);
        }
    }

    /**
     * @dev Partition function for quick sort
     */
    function _partition(
        uint256 _low,
        uint256 _high
    ) internal returns (uint256) {
        uint256 pivot = numbers[_high];
        uint256 i = _low;

        for (uint256 j = _low; j < _high; j++) {
            if (numbers[j] <= pivot) {
                // Swap elements
                uint256 temp = numbers[i];
                numbers[i] = numbers[j];
                numbers[j] = temp;
                i++;
            }
        }

        // Place pivot in correct position
        uint256 temp = numbers[i];
        numbers[i] = numbers[_high];
        numbers[_high] = temp;

        return i;
    }

    // ======================
    // SEARCHING ALGORITHMS
    // ======================

    /**
     * @dev Linear search (O(n) complexity)
     */
    function linearSearch(
        uint256 _value
    ) public view returns (bool found, uint256 index) {
        for (uint256 i = 0; i < numbers.length; i++) {
            if (numbers[i] == _value) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    /**
     * @dev Binary search (requires sorted array - O(log n) complexity)
     */
    function binarySearch(
        uint256 _value
    ) public view returns (bool found, uint256 index) {
        if (numbers.length == 0) {
            return (false, 0);
        }

        uint256 left = 0;
        uint256 right = numbers.length - 1;

        while (left <= right) {
            uint256 mid = left + (right - left) / 2;

            if (numbers[mid] == _value) {
                return (true, mid);
            } else if (numbers[mid] < _value) {
                left = mid + 1;
            } else {
                if (mid == 0) break; // Prevent underflow
                right = mid - 1;
            }
        }

        return (false, 0);
    }

    // ======================
    // MEMORY VS STORAGE OPERATIONS
    // ======================

    /**
     * @dev Demonstrate memory array operations
     */
    function processMemoryArray(
        uint256[] memory _inputArray
    ) public pure returns (uint256[] memory processedArray) {
        // Create memory array
        processedArray = new uint256[](_inputArray.length);

        // Process in memory (cheaper than storage operations)
        for (uint256 i = 0; i < _inputArray.length; i++) {
            processedArray[i] = _inputArray[i] * 2;
        }

        return processedArray;
    }

    /**
     * @dev Batch operations for gas efficiency
     */
    function batchAddNumbers(uint256[] calldata _numbers) external {
        // Calldata is cheaper than memory for external functions
        for (uint256 i = 0; i < _numbers.length; i++) {
            numbers.push(_numbers[i]);
        }
        emit ArrayUpdated("numbers", numbers.length);
    }

    // ======================
    // ADVANCED PATTERNS
    // ======================

    /**
     * @dev Implement a circular buffer with fixed size
     */
    uint256[100] public circularBuffer;
    uint256 public bufferHead;
    uint256 public bufferSize;

    function addToCircularBuffer(uint256 _value) public {
        circularBuffer[bufferHead] = _value;
        bufferHead = (bufferHead + 1) % circularBuffer.length;

        if (bufferSize < circularBuffer.length) {
            bufferSize++;
        }
    }

    function getCircularBufferValues()
        public
        view
        returns (uint256[] memory values)
    {
        values = new uint256[](bufferSize);

        for (uint256 i = 0; i < bufferSize; i++) {
            uint256 index = (bufferHead +
                circularBuffer.length -
                bufferSize +
                i) % circularBuffer.length;
            values[i] = circularBuffer[index];
        }
    }

    /**
     * @dev Stack implementation using array
     */
    uint256[] private stack;

    function push(uint256 _value) public {
        stack.push(_value);
    }

    function pop() public returns (uint256) {
        require(stack.length > 0, "Stack is empty");
        uint256 value = stack[stack.length - 1];
        stack.pop();
        return value;
    }

    function peek() public view returns (uint256) {
        require(stack.length > 0, "Stack is empty");
        return stack[stack.length - 1];
    }

    function stackSize() public view returns (uint256) {
        return stack.length;
    }

    // ======================
    // UTILITY FUNCTIONS
    // ======================

    function getArrayLengths()
        public
        view
        returns (
            uint256 numbersLength,
            uint256 usersLength,
            uint256 messagesLength,
            uint256 matrixRows
        )
    {
        return (numbers.length, users.length, messages.length, matrix.length);
    }

    function getNumbers() public view returns (uint256[] memory) {
        return numbers;
    }

    function getNumbersPaginated(
        uint256 _page
    ) public view returns (uint256[] memory pageNumbers, bool hasMore) {
        uint256 startIndex = _page * PAGE_SIZE;

        if (startIndex >= numbers.length) {
            return (new uint256[](0), false);
        }

        uint256 endIndex = startIndex + PAGE_SIZE;
        if (endIndex > numbers.length) {
            endIndex = numbers.length;
        }

        uint256 pageLength = endIndex - startIndex;
        pageNumbers = new uint256[](pageLength);

        for (uint256 i = 0; i < pageLength; i++) {
            pageNumbers[i] = numbers[startIndex + i];
        }

        hasMore = endIndex < numbers.length;
    }

    /**
     * @dev Clear all arrays (be careful with gas costs)
     */
    function clearAllArrays() public {
        delete numbers;
        delete users;
        delete messages;
        delete matrix;

        // Reset metadata
        bufferHead = 0;
        bufferSize = 0;

        emit ArrayUpdated("all", 0);
    }
}

/**
 * 🧠 LEARNING POINTS:
 *
 * 1. ARRAY TYPES:
 *    - Dynamic arrays: flexible size, higher gas costs
 *    - Fixed arrays: gas efficient, limited flexibility
 *    - Multidimensional: arrays of arrays, complex indexing
 *
 * 2. OPERATIONS COMPLEXITY:
 *    - push(): O(1) - cheap operation
 *    - pop(): O(1) - cheap operation
 *    - Remove by index (unordered): O(1) - swap with last
 *    - Remove by index (ordered): O(n) - shift elements
 *    - Search by value: O(n) - linear search
 *
 * 3. MEMORY MANAGEMENT:
 *    - Storage: persistent, expensive writes
 *    - Memory: temporary, cheaper for processing
 *    - Calldata: cheapest for external function parameters
 *
 * 4. GAS OPTIMIZATION:
 *    - Batch operations when possible
 *    - Use fixed-size arrays for known limits
 *    - Avoid nested loops with large arrays
 *    - Consider pagination for large datasets
 *
 * 5. ADVANCED PATTERNS:
 *    - Circular buffers for fixed-size history
 *    - Stack/Queue implementations
 *    - Sorting only when necessary
 *    - Index mappings for O(1) lookups
 *
 * ⚠️ WARNINGS:
 * - Large arrays can cause out-of-gas errors
 * - Sorting is expensive - do off-chain when possible
 * - Multidimensional arrays increase complexity
 * - Always validate array bounds
 *
 * 🚀 TRY THIS:
 * 1. Test different array operations and measure gas
 * 2. Implement your own data structures
 * 3. Compare storage vs memory costs
 * 4. Build pagination for large datasets
 */
