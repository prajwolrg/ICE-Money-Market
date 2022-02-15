// SPDX-License-Identifier: MIT
pragma solidity >=0.4.21 <0.7.0;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../utils/WadRayMath.sol";
import "../tokens/HToken.sol";
import "../tokens/DToken.sol";
import "./LendingPoolCore.sol";
import "hardhat/console.sol";
import "../oracle/Oracle.sol";
import "../configuration/AddressProvider.sol";

/** 
* @title LendingPool Data Provider
* @author Newton Poudel
**/

contract LendingPoolDataProvider {
	using WadRayMath for uint256;
    
    AddressProvider public addressProvider;
    LendingPoolCore public core;

	constructor(address _addressesProvider) public {
        addressProvider = AddressProvider(_addressesProvider);
    }

    function initialize() external {
        core = LendingPoolCore(addressProvider.getLendingPoolCore());
	}

    function getReserveData(address _reserve) public view returns
    	(
            uint lastUpdateTimestamp,
			uint borrowRate,
			uint liquidityRate,
			uint totalLiquidity,
			uint availableLiquidity,
			uint totalBorrows,
			uint borrowCumulativeIndex,
			uint liquidityCumulativeIndex,
			address hTokenAddress,
			address dTokenAddress
        )
    {
    	lastUpdateTimestamp = core.getReserveLastUpdateTimestamp(_reserve);
		borrowRate = core.getReserveBorrowRate(_reserve);
		liquidityRate = core.getReserveLiquidityRate(_reserve);
		totalLiquidity = core.getReserveTotalLiquidity(_reserve);
		availableLiquidity = core.getReserveAvailableLiquidity(_reserve);
		totalBorrows = core.getReserveTotalBorrows(_reserve);
		borrowCumulativeIndex = core.getReserveBorrowCumulativeIndex(_reserve);
		liquidityCumulativeIndex = core.getReserveLiquidityCumulativeIndex(_reserve);
		hTokenAddress = core.getReserveHTokenAddress(_reserve);
		dTokenAddress = core.getReserveDTokenAddress(_reserve);

    }

    function getAllReserves() public view returns(address[] memory) {
    	return core.getAllReserveList();
    }

    function getUserReserveData(address _reserve, address _user) public view returns
    	(
    		uint256 totalLiquidity, 
    		uint256 totalBorrows,
            uint256 totalLiquidityUSD,
            uint256 totalBorrowsUSD,
            uint256 lastUpdateTimestamp
    	) 
    {
        Oracle oracle = Oracle(addressProvider.getPriceOracle());
        uint256 unitPrice = oracle.get_reference_data(_reserve);
    	totalLiquidity = HToken(core.getReserveHTokenAddress(_reserve)).balanceOf(_user);
		totalBorrows = DToken(core.getReserveDTokenAddress(_reserve)).balanceOf(_user);
        totalLiquidityUSD = totalLiquidity.wadMul(unitPrice);
        totalBorrowsUSD = totalBorrows.wadMul(unitPrice);
        lastUpdateTimestamp = core.getReserveLastUserUpdateTimestamp(_reserve, _user);
    }

     // local variable
    struct UserDataLocalVariable {
        // uint reserveDecimals;
        // string  reserveSymbol;
        address reserveAddress;
        // address reserveHTokenAddress;
        // address reserveDTokenAddress;
        uint reservePriceInUSD;
        // uint reserveLTV;
        uint reserveHTokenBalance;
        uint reserveDTokenBalance;
        uint hTokenBalanceUSD;
        uint dTokenBalanceUSD;
        // uint byReserveDecimals;
        // uint reserveLiquidityUSD;
        // uint reserveBorrowsUSD;
    }

    function getUserAccountData(address _user) public view returns 
    	(
    		uint totalLiquidity,
    		uint totalBorrows,
    		uint ltv,
    		uint liquidationThresold,
    		bool canBeLiquidated
    	)
    {
    	UserDataLocalVariable memory vars;
        Oracle oracle = Oracle(addressProvider.getPriceOracle());
    	address[] memory reserveList = getAllReserves();

    	for(uint8 i = 0; i < reserveList.length; i++ ) {
    		vars.reserveAddress = reserveList[i];
            vars.reservePriceInUSD = oracle.get_reference_data(vars.reserveAddress);
    		vars.reserveHTokenBalance = HToken(core.getReserveHTokenAddress(vars.reserveAddress)).balanceOf(_user);
			vars.reserveDTokenBalance = DToken(core.getReserveDTokenAddress(vars.reserveAddress)).balanceOf(_user);
            vars.hTokenBalanceUSD = vars.reserveHTokenBalance.wadMul(vars.reservePriceInUSD);
            vars.dTokenBalanceUSD = vars.reserveDTokenBalance.wadMul(vars.reservePriceInUSD);
			totalLiquidity += vars.hTokenBalanceUSD;
			totalBorrows += vars.dTokenBalanceUSD;
    	}

    	if (totalBorrows == 0) {
    		ltv = uint(-1);
    	} else {
    		ltv = (totalBorrows.wadDiv(totalLiquidity)).wadToRay();
    	}
    	liquidationThresold = 65 * 1e25;
    	canBeLiquidated = false;
    }

    function calculateCollateralNeeded(uint256 _amount, uint256 _totalBorrows, uint256 _ltv) 
    public view returns(uint256) {
    	uint256 newTotalBorrows = _amount + _totalBorrows;
    	return (newTotalBorrows.wadToRay().rayDiv(_ltv)).rayToWad();
        // return ((borrowBalanceUSD.add(requestedAmountUSD)).wadToRay().rayDiv(userLTV)).rayToWad();
    }
}