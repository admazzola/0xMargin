 

pragma solidity ^0.8.0;


/*

 0xLeverage - Margin Loans System 

  

*/
                                                                                 
  
 


interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}



 
 
 
   

interface MintableERC20  {
     function mint(address account, uint256 amount) external ;
     function burn(address account, uint256 amount) external ;
}

interface PriceOracleQuoter {
    function assetToEth(
        address _tokenIn,
        uint256 _amountIn,
        uint32 _twapPeriod
    ) external view returns (uint256 ethAmountOut) ;

     function ethToAsset(
        uint256 _ethAmountIn,
        address _tokenOut,
        uint32 _twapPeriod
    ) external view returns (uint256 amountOut);
}
 
abstract contract ApproveAndCallFallBack {
       function receiveApproval(address from, uint256 tokens, address token, bytes memory data) public virtual;
  }
  
  
  
  
/**
 * 
 * 
 *  Staking contract that supports community-extractable donations 
 *
 */
contract _0xLeverage is 
  ApproveAndCallFallBack
{
 
  
  address public _stakeableCurrency; 
  address public _reservePoolToken; 

  //mainnet 
  address public priceQuoter = 0x0F1f5A87f99f0918e6C81F16E59F3518698221Ff;


  uint256 public totalAmountStaked; 
  uint256 public totalAmountSuspended;

  uint256 public totalAmountBorrowed;  
  mapping(address => uint256) amountBorrowed;
  //amount available left to borrow = (totalAmountStaked - totalAmountSuspended - totalAmountBorrowed)



  uint256 public totalDepositedCollateral; 
  mapping(address => uint256) depositedCollateral;

  mapping(address => uint256) amountBorrowedValueEth; //amount of StakeableToken borrowed, denominated in ETH 

    
   
  constructor(  address stakeableCurrency, address reservePoolToken  ) 
  { 
    
   _stakeableCurrency = stakeableCurrency;
   _reservePoolToken = reservePoolToken;
  }
   


  
  function stakeCurrency( address from,  uint256 currencyAmount ) public returns (bool){
       
      uint256 reserveTokensMinted = _reserveTokensMinted(  currencyAmount) ;
     
      require( IERC20(_stakeableCurrency).transferFrom(from, address(this), currencyAmount ), 'transfer failed'  );
          
      MintableERC20(_reservePoolToken).mint(from,  reserveTokensMinted) ;
      
     return true; 
  }
  
   
  function unstakeCurrency( uint256 reserveTokenAmount, address currencyToClaim) public returns (bool){
        
     
      uint256 vaultOutputAmount =  _vaultOutputAmount( reserveTokenAmount, currencyToClaim );
        
        
      MintableERC20(_reservePoolToken).burn(msg.sender,  reserveTokenAmount ); 
      
       
      IERC20(currencyToClaim).transfer( msg.sender, vaultOutputAmount );
       
      
      
     return true; 
  }
  

    //amount of reserve_tokens to give to staker 
  function _reserveTokensMinted(  uint256 currencyAmount ) public view returns (uint){

      uint256 totalReserveTokens = IERC20(_reservePoolToken).totalSupply();


      uint256 internalVaultBalance =  IERC20(_stakeableCurrency).balanceOf(address(this)); 
      
     
      if(totalReserveTokens == 0 || internalVaultBalance == 0 ){
        return currencyAmount;
      }
      
      
      uint256 incomingTokenRatio = (currencyAmount*100000000) / internalVaultBalance;
       
       
      return ( ( totalReserveTokens)  * incomingTokenRatio) / 100000000;
  }
  
  
    //amount of output tokens to give to redeemer
  function _vaultOutputAmount(   uint256 reserveTokenAmount, address currencyToClaim ) public view returns (uint){

      uint256 internalVaultBalance = IERC20(currencyToClaim ).balanceOf(address(this));
      

      uint256 totalReserveTokens = IERC20(_reservePoolToken).totalSupply();
 
       
      uint256 burnedTokenRatio = (reserveTokenAmount*100000000) / totalReserveTokens  ;
      
       
      return (internalVaultBalance * burnedTokenRatio) / 100000000;
  }

 
  
  
    function receiveApproval(address from, uint256 tokens, address token, bytes memory data) public override{
      require(token == _stakeableCurrency);
      
       stakeCurrency(from, tokens); 
        
    }


    function borrowableCapitalAmount() public view returns (uint256){
      return (totalAmountStaked - totalAmountSuspended - totalAmountBorrowed);

    }



    function borrowCapital(  uint256 amount ) public returns (bool){
      address from = msg.sender;

      require(amount <= borrowableCapitalAmount());

      require(  depositedCollateral[from] >  recommendedCollateralForAmount(amount) );

      totalAmountBorrowed+=amount;
      amountBorrowed[from]+=amount;
      IERC20(_stakeableCurrency).transfer(from, amount);
    }




      //can add more collateral to pervent loan being liquidateable 
    function _depositCollateral(address from, uint256 amount) internal returns (bool){
      IERC20(_stakeableCurrency).transferFrom(from, address(this),amount);

      depositedCollateral[from] += amount;
      totalDepositedCollateral += amount; 
    }




    function repayLoan(address from, uint256 amount) public returns (bool){
      IERC20(_stakeableCurrency).transferFrom(from, address(this),amount);
      
      uint256 effectiveAmountRepaidEth = quoteAssetToEth( amount );

      amountBorrowedValueEth[from] -= effectiveAmountRepaidEth; 


    }

     

    //TODO 
    function closeLoan(address from, uint256 amount) public returns (bool){
      require(loanIsRepaid(from));
      require(depositedCollateral[from] > 0);

      //withdraw collateral 
      IERC20(_stakeableCurrency).transfer(from,   depositedCollateral[from]);

      depositedCollateral[from] -= depositedCollateral[from];
      totalDepositedCollateral -= depositedCollateral[from]; 

      return true;
    }

    //TODO 
    function _liquidateLoan(address borrower) internal returns (bool){
     // IERC20(_stakeableCurrency).transferFrom(from, address(this),amount);

     require(borrowerCanBeLiquidated(borrower));



       
    }



    function loanIsRepaid( address borrower ) public view returns (bool) {

      //need to figure out the best way to handle this... there may be rounding errors 
      return(  amountBorrowedValueEth[borrower] < 1000 );

    }


      //Any loan needs to have collateral worth in excess of 1.25x of the borrowed amount .  
    function borrowerCanBeLiquidated( address borrower ) public view returns (bool) {

      return(  depositedCollateral[borrower] < minimumCollateralForBorrower(borrower)  );

    }

    function minimumCollateralForBorrower( address borrower ) public view returns (uint256) {

      return minimumCollateralForAmount( amountBorrowedValueEth[borrower] ); 

    }

     function minimumCollateralForAmount( uint256 amount ) public view returns (uint256) {

      uint256 multiplier_pct = 125; 

      uint256 effectiveAmountBorrowedStakeableToken = quoteEthToAsset( amount);

      return effectiveAmountBorrowedStakeableToken * multiplier_pct / 100;

    }

    function recommendedCollateralForAmount( address borrower ) public view returns (uint256) {

      uint256 multiplier_pct = 150; 

      uint256 effectiveAmountBorrowedStakeableToken = quoteEthToAsset( amount);

      return effectiveAmountBorrowedStakeableToken * multiplier_pct / 100;

    }



    function quoteAssetToEth( uint256 amount ) public view returns (uint){

       return PriceOracleQuoter(priceQuoter).assetToEth(_stakeableCurrency, amount, 3600);
    }

    function quoteEthToAsset( uint256 amount ) public view returns (uint){

        return PriceOracleQuoter(priceQuoter).ethToAsset( amount, _stakeableCurrency, 3600);
    }
    
   
     // ------------------------------------------------------------------------

    // Don't accept ETH

    // ------------------------------------------------------------------------
 
    fallback() external payable { revert(); }
    receive() external payable { revert(); }
   

}