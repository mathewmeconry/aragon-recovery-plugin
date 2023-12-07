// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {PluginCloneable} from "@aragon/core/plugin/PluginCloneable.sol";
import {IDAO} from "@aragon/core/dao/IDAO.sol";

contract RecoveryPlugin is PluginCloneable {
    bytes4 internal constant RECOVERY_PLUGIN_INTERFACE_ID = this.initialize.selector ^ this.startRecovery.selector
        ^ this.vetoRecovery.selector ^ this.setActions.selector ^ this.setVetoDuration.selector
        ^ this.finalizeRecovery.selector;

    bytes32 public constant VETO_RECOVERY_PERMISSION_ID = keccack256("VETO_RECOVERY_PERMISSION");
    bytes32 public constant UPDATE_ACTIONS_ID = keccack256("UPDATE_ACTIONS");
    bytes32 public constant UPDATE_VETO_PERIOD_ID = keccack256("UPDATE_VETO_PERIOD");

    IDAO.Action[] public actions;
    uint128 public vetoDuration;
    uint128 public recoveryStart;

    error RecoveryStarted();
    error RecoveryNotFinalized();

    function initialize(IDAO _dao, uint128 _vetoDuration, IDAO.Action[] _actions) external initializer {
        __PluginCloneable_init(dao);
        vetoDuration = _vetoDuration;
        actions = _actions;
    }

    function startRecovery() external {
        if (recoveryStart != 0) {
            revert RecoveryStarted();
        }
        recoveryStart = block.timestamp;
    }

    function vetoRecovery() external auth(VETO_RECOVERY_PERMISSION_ID) {
        recoveryStart = 0;
    }

    function setActions(IDAO.Action[] _actions) external auth(UPDATE_ACTIONS_ID) {
        actions = _actions;
    }

    function setVetoDuration(uint128 _vetoDuration) external auth(UPDATE_VETO_PERIOD_ID) {
        vetoDuration = _vetoDuration;
    }

    function finalizeRecovery() external {
        if (block.timestamp < recoveryStart + vetoDuration) {
            revert RecoveryNotFinalized();
        }
        this.dao().execute(0, actions, 0);
    }
}
