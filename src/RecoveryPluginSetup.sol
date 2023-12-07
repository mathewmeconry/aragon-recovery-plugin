// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {PluginSetup} from "@aragon/framework/plugin/setup/PluginSetup.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IDAO} from "@aragon/core/dao/IDAO.sol";
import {DAO} from "@aragon/core/dao/DAO.sol";
import {PermissionLib} from "@aragon/core/permission/PermissionLib.sol";

import {RecoveryPlugin} from "./RecoveryPlugin.sol";

contract RecoveryPluginSetup is PluginSetup {
    using Clones for address;

    address private immutable implementation_;

    constructor() {
        implementation_ = address(new RecoveryPlugin());
    }

    function prepareInstallation(address _dao, bytes calldata _data)
        external
        returns (address plugin, PreparedSetupData memory preparedSetupData)
    {
        (uint128 vetoDuration, IDAO.Action[] memory actions) = abi.decode(_data, (uint128, IDAO.Action[]));

        plugin = implementation_.clone();
        RecoveryPlugin(plugin).initialize(IDAO(_dao), vetoDuration, actions);

        // Prepare permissions
        PermissionLib.MultiTargetPermission[] memory permissions = new PermissionLib.MultiTargetPermission[](3);

        permissions[0] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Grant,
            plugin,
            _dao,
            PermissionLib.NO_CONDITION,
            RecoveryPlugin(plugin).UPDATE_ACTIONS_ID()
        );

        permissions[1] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Grant,
            plugin,
            _dao,
            PermissionLib.NO_CONDITION,
            RecoveryPlugin(plugin).UPDATE_VETO_PERIOD_ID()
        );

        permissions[2] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Grant,
            _dao,
            plugin,
            PermissionLib.NO_CONDITION,
            DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        );

        preparedSetupData.permissions = permissions;
    }

    function prepareUninstallation(address _dao, SetupPayload calldata _payload)
        external
        view
        returns (PermissionLib.MultiTargetPermission[] memory permissions)
    {
        permissions = new PermissionLib.MultiTargetPermission[](1);

        permissions[0] = PermissionLib.MultiTargetPermission(
            PermissionLib.Operation.Revoke,
            _dao,
            _payload.plugin,
            PermissionLib.NO_CONDITION,
            DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        );
    }

    function implementation() external view returns (address) {
        return implementation_;
    }
}
