// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {RecoveryPlugin} from "../src/RecoveryPlugin.sol";
import {DAO} from "@aragon/core/dao/DAO.sol";
import {IDAO} from "@aragon/core/dao/IDAO.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract RecoveryPluginTest is Test {
    using Clones for address;

    RecoveryPlugin public pluginImplementation;
    RecoveryPlugin public plugin;
    DAO public daoImplementation;
    DAO public dao;

    uint256 public randomNumber = 0;

    function setUp() public {
        daoImplementation = new DAO();
        pluginImplementation = new RecoveryPlugin();
        plugin = RecoveryPlugin(address(pluginImplementation).clone());
        dao = DAO(payable(address(daoImplementation).clone()));
        dao.initialize("", address(this), address(this), "");
        plugin.initialize(dao, 2 days, new IDAO.Action[](0));

        dao.grant(address(plugin), address(this), plugin.VETO_RECOVERY_PERMISSION_ID());
        dao.grant(address(plugin), address(this), plugin.UPDATE_VETO_PERIOD_ID());
        dao.grant(address(plugin), address(this), plugin.UPDATE_ACTIONS_ID());
        dao.grant(address(dao), address(plugin), dao.EXECUTE_PERMISSION_ID());
    }

    function test_startRecovery_set_recoveryStart() public {
        plugin.startRecovery();
        assertEq(plugin.recoveryStart(), block.timestamp);
    }

    function test_startRecovery_revertsAlreadyStarted() public {
        plugin.startRecovery();
        vm.expectRevert(RecoveryPlugin.RecoveryStarted.selector);
        plugin.startRecovery();
    }

    function test_vetoRecovery_canVeto() public {
        plugin.startRecovery();
        assertEq(plugin.recoveryStart(), block.timestamp);
        plugin.vetoRecovery();
        assertEq(plugin.recoveryStart(), 0);
    }

    function test_vetoRecovery_revertsUnauthorized() public {
        address random = makeAddr("random");
        vm.startPrank(random);
        plugin.startRecovery();
        vm.expectRevert();
        plugin.vetoRecovery();
        vm.stopPrank();
    }

    function test_setVetoDuration_setNewDurationo() public {
        assertEq(plugin.vetoDuration(), 2 days);
        plugin.setVetoDuration(3 days);
        assertEq(plugin.vetoDuration(), 3 days);
    }

    function test_setVetoDuration_revertsUnauthorized() public {
        vm.prank(makeAddr("random"));
        vm.expectRevert();
        plugin.setVetoDuration(3 days);
    }

    function test_finalizeRecovery_executAction() public {
        deal(address(dao), 2 ether);
        IDAO.Action[] memory actions = new IDAO.Action[](1);
        actions[0] = IDAO.Action({
            to: address(this),
            value: 1 ether,
            data: abi.encodeCall(this.callFromDAO, (123))
        });
        plugin.setActions(actions);
        plugin.startRecovery();
        vm.warp(block.timestamp + 2 days);
        plugin.finalizeRecovery();
        assertEq(randomNumber, 123);
    }

    function callFromDAO(uint256 _randomNumber) public payable {
        randomNumber = _randomNumber;
    }
}