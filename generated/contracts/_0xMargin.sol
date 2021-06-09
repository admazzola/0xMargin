 

pragma solidity ^0.8.0;


/*

 0xMargin - Single-asset Lending System 

  

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

 
abstract contract ApproveAndCallFallBack {
       function receiveApproval(address from, uint256 tokens, address token, bytes memory data) public virtual;
  }
  
  
  
  
/**
 * 
 * 
 *   
 *
 */
contract _0xMargin is 
  ApproveAndCallFallBack
{
 
  
  address public _stakeableCurrency; 
  address public _reservePoolToken; 

  

  uint256 public totalAmountStaked; 
  uint256 public totalInterestEarned;
 

  uint256 public totalAmountBorrowed;  
  //mapping(address => uint256) amountBorrowed; //amount of StakeableToken borrowed 
 


  uint256 public totalDepositedCollateral; 
  //mapping(address => uint256) depositedCollateral;


  mapping(uint256 => Loan) loans;
  uint256 loanCount;


/*

Need to calculate interest due ! 

*/
  struct Loan {

    address borrower;
    uint256 depositedCollateral;
    uint256 amountBorrowed;
    uint256 amountRepaid;
 

  }
 
   
  constructor(  address stakeableCurrency, address reservePoolToken  ) 
  { 
    
   _stakeableCurrency = stakeableCurrency;
   _reservePoolToken = reservePoolToken;
  }
   


  
  function stakeCurrency( address from,  uint256 currencyAmount ) public returns (bool){
       
      uint256 reserveTokensMinted = _reserveTokensMinted(  currencyAmount) ;
     
      require( IERC20(_stakeableCurrency).transferFrom(from, address(this), currencyAmount ), 'transfer failed'  );
      totalAmountStaked += currencyAmount;    


      MintableERC20(_reservePoolToken).mint(from,  reserveTokensMinted) ;
      
     return true; 
  }
  
   
  function unstakeCurrency( uint256 reserveTokenAmount, address currencyToClaim) public returns (bool){
        
     
      uint256 vaultOutputAmount =  _vaultOutputAmount( reserveTokenAmount  );
        
        
      MintableERC20(_reservePoolToken).burn(msg.sender,  reserveTokenAmount ); 
      
       
      IERC20(currencyToClaim).transfer( msg.sender, vaultOutputAmount );
      totalAmountStaked -= vaultOutputAmount;   

      require( borrowableCapitalAmount() >= 0);
      
      
     return true; 
  }
  

    //amount of reserve_tokens to give to staker 
  function _reserveTokensMinted(  uint256 currencyAmount ) public view returns (uint){

      uint256 totalReserveTokens = IERC20(_reservePoolToken).totalSupply();


      uint256 internalVaultBalance = getTotalVaultBalance(); 
      
     
      if(totalReserveTokens == 0 || internalVaultBalance == 0 ){
        return currencyAmount;
      }
      
      
      uint256 incomingTokenRatio = (currencyAmount*100000000) / internalVaultBalance;
       
       
      return ( ( totalReserveTokens)  * incomingTokenRatio) / 100000000;
  }
  
  
    //amount of output tokens to give to redeemer
  function _vaultOutputAmount(   uint256 reserveTokenAmount  ) public view returns (uint){

      uint256 internalVaultBalance = getTotalVaultBalance();  
      

      uint256 totalReserveTokens = IERC20(_reservePoolToken).totalSupply();
 
       
      uint256 burnedTokenRatio = (reserveTokenAmount*100000000) / totalReserveTokens  ;
      
       
      return (internalVaultBalance * burnedTokenRatio) / 100000000;
  }





  function getTotalVaultBalance() public view returns (uint256) { 

    return totalAmountStaked + totalInterestEarned; 
  }

 
  
  
    function receiveApproval(address from, uint256 tokens, address token, bytes memory data) public override{
      require(token == _stakeableCurrency);
      
       stakeCurrency(from, tokens); 
        
    }


    function borrowableCapitalAmount() public view returns (uint256){
      return (totalAmountStaked -  totalAmountBorrowed);

    }




    function initializeLoan(uint256 depositAmount, uint256 borrowAmount ) public returns (bool){
      uint256 loanId = loanCount++;
      loans[loanId] = Loan( msg.sender,0,0,0 );

      if(depositAmount > 0){
        depositCollateral(loanId,depositAmount);
      }

      if(borrowAmount > 0){
        borrowCapital(loanId,borrowAmount);
      }

    }

  //can add more collateral to prevent loan being liquidateable 
    function depositCollateral(uint256 loanId, uint256 amount) public returns (bool){
      address from = msg.sender;
      require(loans[loanId].borrower == from);

      IERC20(_stakeableCurrency).transferFrom(from, address(this),amount);

      totalDepositedCollateral += amount; 
      loans[loanId].depositedCollateral += amount;
      

      return true;
    }


 
    function borrowCapital( uint256 loanId, uint256 amount ) public returns (bool){
      address from = msg.sender;
      require(loans[loanId].borrower == from);
      
      require( loans[loanId].depositedCollateral > recommendedCollateralForAmount(amount) );      
      
      IERC20(_stakeableCurrency).transfer(from, amount);

      totalAmountBorrowed += amount;
      loans[loanId].amountBorrowed += amount;
      

      require( borrowableCapitalAmount() >= 0);

      return true;
    }




      


  
    function repayLoan(uint256 loanId, uint256 amount) public returns (bool){
      address from = msg.sender;
      require(loans[loanId].borrower == from);      

      IERC20(_stakeableCurrency).transferFrom(from, address(this),amount);

      loans[loanId].amountRepaid += amount; 

      return true;
      //need to be able to pay back interest

    }


    function repayLoanWithCollateral(uint256 loanId, uint256 amount) public returns (bool){
      address from = msg.sender;
      require(loans[loanId].borrower == from);      

       
      loans[loanId].depositedCollateral -= amount; 
      loans[loanId].amountRepaid += amount;   

      require(loans[loanId].depositedCollateral >= 0);

      return true;
    }


 

    //reclaim the collateral 
    function closeLoan(uint256 loanId ) public returns (bool){
      address from = msg.sender;
      require(loans[loanId].borrower == from);   
      require(loanIsRepaid(loanId));
      

      require(loans[loanId].depositedCollateral > 0);

      //withdraw collateral 
      IERC20(_stakeableCurrency).transfer(from, loans[loanId].depositedCollateral);

      totalDepositedCollateral -= loans[loanId].depositedCollateral; 
      loans[loanId].depositedCollateral -= loans[loanId].depositedCollateral;
      

      return true;
    }

    //TODO 
    //this can be called if the borrowed+interest gets dangerously close to the collateral 
    function _liquidateLoan(uint256 loanId ) internal returns (bool){
     // IERC20(_stakeableCurrency).transferFrom(from, address(this),amount);

     require(loanCanBeLiquidated(loanId));



      //seize the collateral and close out the loan in a different way,   borrower keeps the borrowed assets
 
    }



    function loanIsRepaid( uint256 loanId ) public view returns (bool) {

      //need to figure out the best way to handle this... there may be rounding errors 
      return( loans[loanId].amountRepaid > loans[loanId].amountBorrowed + calculateLoanInterest( loanId )  );

    }



    function calculateLoanInterest(uint256 loanId) public view returns (uint256) {
      //IMPLEMENT
        return 0 ;
    }


      //Any loan needs to have collateral worth in excess of 1.25x of the borrowed amount .  
    function loanCanBeLiquidated( uint256 loanId ) public view returns (bool) {

      return(  loans[loanId].depositedCollateral < minimumCollateralForLoan(loanId)  );

    }

    function minimumCollateralForLoan( uint256 loanId ) public view returns (uint256) {

      return minimumCollateralForAmount( loans[loanId].amountBorrowed ); 

    }

     function minimumCollateralForAmount( uint256 amount ) public view returns (uint256) {
      uint256 multiplier_pct = 125;  

      return amount * multiplier_pct / 100;
    }

    function recommendedCollateralForAmount( uint256 amount  ) public view returns (uint256) {
      uint256 multiplier_pct = 150;  

      return amount * multiplier_pct / 100;
    }


 
   
     // ------------------------------------------------------------------------

    // Don't accept ETH

    // ------------------------------------------------------------------------
 
    fallback() external payable { revert(); }
    receive() external payable { revert(); }
   

}