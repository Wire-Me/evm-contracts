

contract UserSmartWalletERC20Proxy {
    address public implementation;
    address public admin;
    address public authorizedUserExternalAccount;

    constructor(address _impl, address _admin, address _authorizedUserExternalWallet) {
        admin = _admin;
        authorizedUserExternalAccount = _authorizedUserExternalWallet;
        implementation = _impl;
    }

    function setImplementation(address _impl) external {
        // add access control if you want
        require(msg.sender == admin, "Only admin account can call this function");
        implementation = _impl;
    }

    function setAuthorizedUserExternalAccount(address payable _newExternalAccount) external {
        require(msg.sender == admin, "Only admin account can call this function");
        require(_newExternalAccount != address(0), "New external account cannot be zero address");
        authorizedUserExternalAccount = _newExternalAccount;
    }

    fallback() external payable {
        require(msg.sender == admin || msg.sender == authorizedUserExternalAccount, "Only admin or authorized user account can call this function");
        address impl = implementation;
        require(impl != address(0), "No implementation");

        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch success
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
}