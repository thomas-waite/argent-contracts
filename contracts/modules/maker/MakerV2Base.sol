pragma solidity ^0.5.4;

import "../common/BaseModule.sol";
import "../common/RelayerModule.sol";
import "../common/OnlyOwnerModule.sol";
import "../../../lib/utils/SafeMath.sol";
import "../../infrastructure/MakerRegistry.sol";

/**
 * @title MakerV2Base
 * @dev Module to convert SAI <-> DAI. Also serves as common base to MakerV2Invest and MakerV2Loan.
 * @author Olivier VDB - <olivier@argent.xyz>
 */
contract MakerV2Base is BaseModule, RelayerModule, OnlyOwnerModule {

    bytes32 constant private NAME = "MakerV2Manager";

    // The address of the SAI token
    GemLike internal saiToken;
    // The address of the (MCD) DAI token
    GemLike internal daiToken;
    // The address of the SAI <-> DAI migration contract
    address internal scdMcdMigration;
    // The address of the Dai Adapter
    JoinLike internal daiJoin;
    // The address of the Vat
    VatLike internal vat;

    // Method signatures to reduce gas cost at depoyment
    bytes4 constant internal ERC20_APPROVE = bytes4(keccak256("approve(address,uint256)"));
    bytes4 constant internal SWAP_SAI_DAI = bytes4(keccak256("swapSaiToDai(uint256)"));
    bytes4 constant internal SWAP_DAI_SAI = bytes4(keccak256("swapDaiToSai(uint256)"));

    uint256 constant internal RAY = 10 ** 27;

    using SafeMath for uint256;

    // ****************** Events *************************** //

    event TokenConverted(address indexed _wallet, address _srcToken, uint _srcAmount, address _destToken, uint _destAmount);

    // *************** Constructor ********************** //

    constructor(
        ModuleRegistry _registry,
        GuardianStorage _guardianStorage,
        ScdMcdMigration _scdMcdMigration
    )
        BaseModule(_registry, _guardianStorage, NAME)
        public
    {
        scdMcdMigration = address(_scdMcdMigration);
        daiJoin = _scdMcdMigration.daiJoin();
        saiToken = _scdMcdMigration.saiJoin().gem();
        daiToken = daiJoin.dai();
        vat = daiJoin.vat();
    }

    /* **************************************** SAI <> DAI Conversion **************************************** */

    /**
    * @dev lets the owner convert SCD SAI into MCD DAI.
    * @param _wallet The target wallet.
    * @param _amount The amount of SAI to convert
    */
    function swapSaiToDai(
        BaseWallet _wallet,
        uint256 _amount
    )
        public
        onlyWalletOwner(_wallet)
        onlyWhenUnlocked(_wallet)
    {
        require(saiToken.balanceOf(address(_wallet)) >= _amount, "MV2: insufficient SAI");
        invokeWallet(address(_wallet), address(saiToken), 0, abi.encodeWithSelector(ERC20_APPROVE, scdMcdMigration, _amount));
        invokeWallet(address(_wallet), scdMcdMigration, 0, abi.encodeWithSelector(SWAP_SAI_DAI, _amount));
        emit TokenConverted(address(_wallet), address(saiToken), _amount, address(daiToken), _amount);
    }

    /**
    * @dev lets the owner convert MCD DAI into SCD SAI.
    * @param _wallet The target wallet.
    * @param _amount The amount of DAI to convert
    */
    function swapDaiToSai(
        BaseWallet _wallet,
        uint256 _amount
    )
        external
        onlyWalletOwner(_wallet)
        onlyWhenUnlocked(_wallet)
    {
        require(daiToken.balanceOf(address(_wallet)) >= _amount, "MV2: insufficient DAI");
        invokeWallet(address(_wallet), address(daiToken), 0, abi.encodeWithSelector(ERC20_APPROVE, scdMcdMigration, _amount));
        invokeWallet(address(_wallet), scdMcdMigration, 0, abi.encodeWithSelector(SWAP_DAI_SAI, _amount));
        emit TokenConverted(address(_wallet), address(daiToken), _amount, address(saiToken), _amount);
    }

}