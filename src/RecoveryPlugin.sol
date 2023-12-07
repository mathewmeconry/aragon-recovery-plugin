// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {PluginCloneable} from "@aragon/core/plugin/PluginCloneable.sol";
import {IDAO} from "@aragon/core/dao/IDAO.sol";

contract RecoveryPlugin is PluginCloneable {
    bytes4 internal constant RECOVERY_PLUGIN_INTERFACE_ID = this.initialize.selector ^ this.startRecovery.selector
        ^ this.vetoRecovery.selector ^ this.setActions.selector ^ this.setVetoDuration.selector
        ^ this.finalizeRecovery.selector;

    bytes32 public constant VETO_RECOVERY_PERMISSION_ID = keccak256("VETO_RECOVERY_PERMISSION");
    bytes32 public constant UPDATE_ACTIONS_ID = keccak256("UPDATE_ACTIONS");
    bytes32 public constant UPDATE_VETO_PERIOD_ID = keccak256("UPDATE_VETO_PERIOD");

    IDAO.Action[] public actions;
    uint128 public vetoDuration;
    uint128 public recoveryStart;
    IDAO public dao;

    error RecoveryStarted();
    error RecoveryNotFinalized();

    function initialize(IDAO _dao, uint128 _vetoDuration, IDAO.Action[] calldata _actions) external initializer {
        __PluginCloneable_init(_dao);
        dao = _dao;
        vetoDuration = _vetoDuration;
        _setActions(_actions);
    }

    function startRecovery() external {
        if (recoveryStart != 0) {
            revert RecoveryStarted();
        }
        recoveryStart = uint128(block.timestamp);
    }

    function vetoRecovery() external auth(VETO_RECOVERY_PERMISSION_ID) {
        recoveryStart = 0;
    }

    function _setActions(IDAO.Action[] calldata _actions) internal {
        delete actions;
        uint256 length = _actions.length;
        for (uint256 i = 0; i < length;) {
            IDAO.Action memory action =
                IDAO.Action({to: _actions[i].to, value: _actions[i].value, data: _actions[i].data});
            actions.push(action);
            unchecked {
                ++i;
            }
        }
    }

    function setVetoDuration(uint128 _vetoDuration) external auth(UPDATE_VETO_PERIOD_ID) {
        vetoDuration = _vetoDuration;
    }

    function finalizeRecovery() external {
        if (block.timestamp < recoveryStart + vetoDuration) {
            revert RecoveryNotFinalized();
        }
        dao.execute(0, actions, 0);
    }

    function supportsInterface(bytes4 _interfaceId) public view override(PluginCloneable) returns (bool) {
        return _interfaceId == RECOVERY_PLUGIN_INTERFACE_ID || super.supportsInterface(_interfaceId);
    }

    function setActions(IDAO.Action[] calldata _actions) external auth(UPDATE_ACTIONS_ID) {
        _setActions(_actions);
    }
}
