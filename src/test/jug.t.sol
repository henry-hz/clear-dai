pragma solidity 0.5.12;

import "ds-test/test.sol";

import {StabilityFees} from "../stabilityFees.sol";
import {CDPEngineInstance} from "../CDPEngine.sol";


contract Hevm {
    function warp(uint256) public;
}

contract CDPEngineContract {
    function collateralTypes(bytes32) public view returns (
        uint256 debtAmount,
        uint256 accumulatedRates ,
        uint256 spot,
        uint256 line,
        uint256 dust
    );
}

contract JugTest is DSTest {
    Hevm hevm;
    StabilityFees stabilityFees;
    CDPEngineInstance  CDPEngine;

    function rad(uint wad_) internal pure returns (uint) {
        return wad_ * 10 ** 27;
    }
    function amount(uint rad_) internal pure returns (uint) {
        return rad_ / 10 ** 27;
    }
    function timeOfLastCollectionRate(bytes32 collateralType) internal view returns (uint) {
        (uint duty, uint rho_) = stabilityFees.collateralTypes(collateralType); duty;
        return rho_;
    }
    function debtAmount(bytes32 collateralType) internal view returns (uint ArtV) {
        (ArtV,,,,) = CDPEngineContract(address(CDPEngine)).collateralTypes(collateralType);
    }
    function accumulatedRates (bytes32 collateralType) internal view returns (uint rateV) {
        (, rateV,,,) = CDPEngineContract(address(CDPEngine)).collateralTypes(collateralType);
    }
    function line(bytes32 collateralType) internal view returns (uint lineV) {
        (,,, lineV,) = CDPEngineContract(address(CDPEngine)).collateralTypes(collateralType);
    }

    address ali = address(bytes20("ali"));

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(604411200);

        CDPEngine  = new CDPEngineInstance();
        stabilityFees = new StabilityFees(address(CDPEngine));
        CDPEngine.addAuthorization(address(stabilityFees));
        CDPEngine.init("i");

        draw("i", 100 ether);
    }
    function draw(bytes32 collateralType, uint dai) internal {
        CDPEngine.file("Line", CDPEngine.Line() + rad(dai));
        CDPEngine.file(collateralType, "line", line(collateralType) + rad(dai));
        CDPEngine.file(collateralType, "spot", 10 ** 27 * 10000 ether);
        address self = address(this);
        CDPEngine.slip(collateralType, self,  10 ** 27 * 1 ether);
        CDPEngine.frob(collateralType, self, self, self, int(1 ether), int(dai));
    }

    function test_collectRate_setup() public {
        hevm.warp(0);
        assertEq(uint(now), 0);
        hevm.warp(1);
        assertEq(uint(now), 1);
        hevm.warp(2);
        assertEq(uint(now), 2);
        assertEq(debtAmount("i"), 100 ether);
    }
    function test_collectRate_updates_rho() public {
        stabilityFees.init("i");
        assertEq(timeOfLastCollectionRate("i"), now);

        stabilityFees.file("i", "duty", 10 ** 27);
        stabilityFees.collectRate("i");
        assertEq(timeOfLastCollectionRate("i"), now);
        hevm.warp(now + 1);
        assertEq(timeOfLastCollectionRate("i"), now - 1);
        stabilityFees.collectRate("i");
        assertEq(timeOfLastCollectionRate("i"), now);
        hevm.warp(now + 1 days);
        stabilityFees.collectRate("i");
        assertEq(timeOfLastCollectionRate("i"), now);
    }
    function test_collectRate_file() public {
        stabilityFees.init("i");
        stabilityFees.file("i", "duty", 10 ** 27);
        stabilityFees.collectRate("i");
        stabilityFees.file("i", "duty", 1000000564701133626865910626);  // 5% / day
    }
    function test_collectRate_0d() public {
        stabilityFees.init("i");
        stabilityFees.file("i", "duty", 1000000564701133626865910626);  // 5% / day
        assertEq(CDPEngine.dai(ali), rad(0 ether));
        stabilityFees.collectRate("i");
        assertEq(CDPEngine.dai(ali), rad(0 ether));
    }
    function test_collectRate_1d() public {
        stabilityFees.init("i");
        stabilityFees.file("debtEngine", ali);

        stabilityFees.file("i", "duty", 1000000564701133626865910626);  // 5% / day
        hevm.warp(now + 1 days);
        assertEq(amount(CDPEngine.dai(ali)), 0 ether);
        stabilityFees.collectRate("i");
        assertEq(amount(CDPEngine.dai(ali)), 5 ether);
    }
    function test_collectRate_2d() public {
        stabilityFees.init("i");
        stabilityFees.file("debtEngine", ali);
        stabilityFees.file("i", "duty", 1000000564701133626865910626);  // 5% / day

        hevm.warp(now + 2 days);
        assertEq(amount(CDPEngine.dai(ali)), 0 ether);
        stabilityFees.collectRate("i");
        assertEq(amount(CDPEngine.dai(ali)), 10.25 ether);
    }
    function test_collectRate_3d() public {
        stabilityFees.init("i");
        stabilityFees.file("debtEngine", ali);

        stabilityFees.file("i", "duty", 1000000564701133626865910626);  // 5% / day
        hevm.warp(now + 3 days);
        assertEq(amount(CDPEngine.dai(ali)), 0 ether);
        stabilityFees.collectRate("i");
        assertEq(amount(CDPEngine.dai(ali)), 15.7625 ether);
    }
    function test_collectRate_negative_3d() public {
        stabilityFees.init("i");
        stabilityFees.file("debtEngine", ali);

        stabilityFees.file("i", "duty", 999999706969857929985428567);  // -2.5% / day
        hevm.warp(now + 3 days);
        assertEq(amount(CDPEngine.dai(address(this))), 100 ether);
        CDPEngine.move(address(this), ali, rad(100 ether));
        assertEq(amount(CDPEngine.dai(ali)), 100 ether);
        stabilityFees.collectRate("i");
        assertEq(amount(CDPEngine.dai(ali)), 92.6859375 ether);
    }

    function test_collectRate_multi() public {
        stabilityFees.init("i");
        stabilityFees.file("debtEngine", ali);

        stabilityFees.file("i", "duty", 1000000564701133626865910626);  // 5% / day
        hevm.warp(now + 1 days);
        stabilityFees.collectRate("i");
        assertEq(amount(CDPEngine.dai(ali)), 5 ether);
        stabilityFees.file("i", "duty", 1000001103127689513476993127);  // 10% / day
        hevm.warp(now + 1 days);
        stabilityFees.collectRate("i");
        assertEq(amount(CDPEngine.dai(ali)),  15.5 ether);
        assertEq(amount(CDPEngine.debt()),     115.5 ether);
        assertEq(accumulatedRates ("i") / 10 ** 9, 1.155 ether);
    }
    function test_collectRate_base() public {
        CDPEngine.init("j");
        draw("j", 100 ether);

        stabilityFees.init("i");
        stabilityFees.init("j");
        stabilityFees.file("debtEngine", ali);

        stabilityFees.file("i", "duty", 1050000000000000000000000000);  // 5% / second
        stabilityFees.file("j", "duty", 1000000000000000000000000000);  // 0% / second
        stabilityFees.file("base",  uint(50000000000000000000000000)); // 5% / second
        hevm.warp(now + 1);
        stabilityFees.collectRate("i");
        assertEq(amount(CDPEngine.dai(ali)), 10 ether);
    }
    function test_file_duty() public {
        stabilityFees.init("i");
        hevm.warp(now + 1);
        stabilityFees.collectRate("i");
        stabilityFees.file("i", "duty", 1);
    }
    function testFail_file_duty() public {
        stabilityFees.init("i");
        hevm.warp(now + 1);
        stabilityFees.file("i", "duty", 1);
    }
}
