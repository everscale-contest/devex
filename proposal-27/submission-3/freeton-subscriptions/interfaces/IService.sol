pragma ton-solidity >= 0.47.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
struct SubscriptionPlan
{
    uint256 planID;      // Subscription Plan ID;
    uint32  period;      // Subscription period in seconds;
    uint128 periodPrice; // Subscription price;
}

//================================================================================
//
interface IService
{
    //========================================
    //
    function getSubscriptionPlans() external view returns (SubscriptionPlan[] plans);
    function addSubscriptionPlan   (uint256 planID, uint32 period, uint128 periodPrice) external;
    function removeSubscriptionPlan(uint256 planID) external;
    
    //========================================
    //
    function confirmSubscription       (address walletAddress, uint256 planID, uint32 period, uint128 periodPrice) external responsible returns (bool confirmed);
    function payForSubscription        (address walletAddress, uint256 planID, uint32 period, uint128 periodPrice) external;
    function subscriptionPaymentRequest(address walletAddress) external;
    
    //========================================
    //
    function cancelSubscription (address walletAddress, uint256 planID, uint32 period, uint128 periodPrice, uint32 lastPaid) external;
}

//================================================================================
//
