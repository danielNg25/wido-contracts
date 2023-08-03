// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "forge-std/StdUtils.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../../shared/PolygonForkTest.sol";
import "../../../contracts/core/zapper/WidoZapperGammaRetro.sol";

contract WidoZapperGamma_Retro_WETH_WMATIC_Test is PolygonForkTest {
    using SafeMath for uint256;

    WidoZapperGammaRetro zapper;

    address constant UNI_ROUTER = address(0xf5b509bB0909a69B1c207E495f687a596C168E12);
    address constant WETH_WMATIC_LP = address(0xe7806B5ba13d4B2Ab3EaB3061cB31d4a4F3390Aa);

    function setUp() public {
        setUpBase();

        zapper = new WidoZapperGammaRetro();
        vm.label(address(zapper), "Zapper");

        vm.label(UNI_ROUTER, "UNI_ROUTER");
        vm.label(WETH_WMATIC_LP, "WETH_WMATIC_LP");
    }

    function test_zapWETHForLP() public {
        /** Arrange */

        uint256 amount = 1e18;
        address fromAsset = WETH;
        address toAsset = WETH_WMATIC_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertLt(finalFromBalance, amount, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(WMATIC).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");
    }

    function test_zapWMATICForLP() public {
        /** Arrange */

        uint256 amount = 50e18;
        address fromAsset = WMATIC;
        address toAsset = WETH_WMATIC_LP;

        /** Act */

        uint256 minToToken = _zapIn(zapper, fromAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertLt(finalFromBalance, amount, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(WMATIC).balanceOf(address(zapper)), 2, "Dust");
        assertLe(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");
    }

    function test_zapLPForWETH() public {
        /** Arrange */

        _zapIn(zapper, WETH, 1e18);

        address fromAsset = WETH_WMATIC_LP;
        address toAsset = WETH;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertLt(finalFromBalance, amount, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(WMATIC).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");
    }

    function test_zapLPForWMATIC() public {
        /** Arrange */

        _zapIn(zapper, WMATIC, 150e18);

        address fromAsset = WETH_WMATIC_LP;
        address toAsset = WMATIC;
        uint256 amount = IERC20(fromAsset).balanceOf(user1);

        assertGt(IERC20(fromAsset).balanceOf(user1), 0, "From balance incorrect");

        /** Act */

        uint256 minToToken = _zapOut(zapper, fromAsset, toAsset, amount);

        /** Assert */

        uint256 finalFromBalance = IERC20(fromAsset).balanceOf(user1);
        uint256 finalToBalance = IERC20(toAsset).balanceOf(user1);

        assertEq(finalFromBalance, 0, "From balance incorrect");
        assertGe(finalToBalance, minToToken, "To balance incorrect");

        assertLe(IERC20(WMATIC).balanceOf(address(zapper)), 0, "Dust");
        assertLe(IERC20(WETH).balanceOf(address(zapper)), 0, "Dust");
    }

    function _zapIn(
        WidoZapperGammaRetro _zapper,
        address _fromAsset,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){
        deal(_fromAsset, user1, _amountIn);
        vm.startPrank(user1);

        uint256[] memory inMin = new uint256[](4);
        inMin[0] = 0;
        inMin[1] = 0;
        inMin[2] = 0;
        inMin[3] = 0;

        bytes memory data = abi.encode(inMin);

        minToToken = _zapper.calcMinToAmountForZapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WETH_WMATIC_LP),
            _fromAsset,
            _amountIn,
            data
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapIn(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WETH_WMATIC_LP),
            _fromAsset,
            user1,
            _amountIn,
            minToToken,
            data
        );
    }

    function _zapOut(
        WidoZapperGammaRetro _zapper,
        address _fromAsset,
        address _toAsset,
        uint256 _amountIn
    ) internal returns (uint256 minToToken){

        uint256[] memory inMin = new uint256[](4);
        inMin[0] = 0;
        inMin[1] = 0;
        inMin[2] = 0;
        inMin[3] = 0;

        bytes memory data = abi.encode(inMin);

        minToToken = _zapper.calcMinToAmountForZapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WETH_WMATIC_LP),
            _toAsset,
            _amountIn,
            data
        )
        .mul(998)
        .div(1000);

        IERC20(_fromAsset).approve(address(_zapper), _amountIn);
        _zapper.zapOut(
            IUniswapV2Router02(UNI_ROUTER),
            IUniswapV2Pair(WETH_WMATIC_LP),
            _amountIn,
            _toAsset,
            minToToken,
            data
        );
    }
}
