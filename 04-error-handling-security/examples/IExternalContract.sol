// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Interface for External Contract Calls
 * @dev Used for demonstrating try-catch error handling
 */
interface IExternalContract {
    function riskyFunction(uint256 value) external returns (bool);

    function getValue() external view returns (uint256);

    function processData(bytes memory data) external returns (bytes memory);
}

/**
 * @title Mock External Contract
 * @dev Test contract for demonstrating external call failures
 */
contract MockExternalContract is IExternalContract {
    uint256 public value;
    bool public shouldFail = false;

    function riskyFunction(uint256 _value) external override returns (bool) {
        if (shouldFail) {
            revert("Mock contract failure");
        }

        if (_value == 0) {
            assert(false); // Cause a panic
        }

        value = _value;
        return true;
    }

    function getValue() external view override returns (uint256) {
        return value;
    }

    function processData(
        bytes memory data
    ) external pure override returns (bytes memory) {
        return data;
    }

    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }
}
