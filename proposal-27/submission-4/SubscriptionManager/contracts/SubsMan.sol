pragma ton-solidity ^ 0.47.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "https://raw.githubusercontent.com/tonlabs/debots/main/Debot.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/SigningBoxInput/SigningBoxInput.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Menu/Menu.sol";
import "https://raw.githubusercontent.com/tonlabs/DeBot-IS-consortium/main/Terminal/Terminal.sol";
import "https://raw.githubusercontent.com/tonlabs/debots/main/Sdk.sol";
import "ISubsManCallbacks.sol";
import "IMultisig.sol";
import "Subscription.sol";
import "Wallet.sol";
import "SubscriptionService.sol";

contract SubsMan is Debot {
    uint128 constant DEPLOY_FEE = 1 ton;

    bytes m_icon;

    TvmCell m_subscriptionBaseImage;

    // invoke arguments
    address s_invoker;
    uint256 s_ownerKey;
    address s_to;
    uint32 s_period;
    uint128 s_value;
    TvmCell s_args;
    uint32 s_sbHandle;
    address s_wallet;

    address m_invoker;
    uint256 m_ownerKey;
    uint256 m_serviceKey;
    uint32 debug;
    address m_wallet;
    TvmCell m_args;
    uint32 m_sbHandle;
    address m_subscription;
    string m_nonce;
    // helper vars
    uint32 m_gotoId;
    uint32 m_continue;

    uint8 m_deployFlags;

    Invoke m_invokeType;
    Invoke s_invokeType;

    TvmCell s_subscriptionServiceImage;
    TvmCell m_subscriptionWalletImage;
    TvmCell m_subscriptionIndexImage;

    uint256 subscriberKey;

    TvmCell svcParams;

    enum Invoke {
        NewSubscription,
        NewSubscriptionService,
        QuerySubscriptions
    }

    modifier onlyOwner() {
        tvm.accept();
        _;
    }

    /// @notice Returns Metadata about DeBot.
    function getDebotInfo() public functionID(0xDEB) override view returns(
        string name, string version, string publisher, string caption, string author,
        address support, string hello, string language, string dabi, bytes icon
    ) {
        name = "Subscription Manager";
        version = "0.2.0";
        publisher = "INTONATION";
        caption = "Managing user subscriptions";
        author = "INTONATION";
        support = address.makeAddrStd(0, 0x841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94);
        hello = "Hello, I am an Subscription Manager DeBot.";
        language = "en";
        dabi = m_debotAbi.get();
        icon = m_icon;
    }

    function setSubscriptionBase(TvmCell image) public onlyOwner {
        m_subscriptionBaseImage = image;
    }
 
    function setSubscriptionWalletCode(TvmCell image) public onlyOwner {
        m_subscriptionWalletImage = image;
    }

    function setSubscriptionIndexCode(TvmCell image) public onlyOwner {
        m_subscriptionIndexImage = image;
    }

    function setSubscriptionService(TvmCell image) public onlyOwner {
        s_subscriptionServiceImage = image;
    }

    /// @notice Entry point function for DeBot.
    function start() public override {
        
    }

    function getRequiredInterfaces() public view override returns (uint256[] interfaces) {
        return [ Menu.ID, SigningBoxInput.ID ];
    }

    function buildAccount(uint256 ownerKey, uint256 serviceKey, TvmCell params) private view returns (TvmCell image) {
        TvmCell code = buildAccountHelper(serviceKey);
        TvmCell newImage = tvm.buildStateInit({
            code: code,
            pubkey: ownerKey,
            varInit: { 
                serviceKey: serviceKey,
                user_wallet: address(tvm.hash(buildWallet(ownerKey))),
                svcParams: params
            },
            contr: Subscription
        });
        image = newImage;
    }

    function buildAccountHelper(uint256 serviceKey) private view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(serviceKey);
        TvmCell code = tvm.setCodeSalt(
            m_subscriptionBaseImage.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        return code;
    }

    function buildWallet(uint256 ownerKey) private view returns (TvmCell image) {
        TvmCell code = m_subscriptionWalletImage.toSlice().loadRef();
        TvmCell newImage = tvm.buildStateInit({
            code: code,
            pubkey: ownerKey
        });
        image = newImage;
    }

    function checkWallet() public {
        address walletAddr = address(tvm.hash(buildWallet(m_ownerKey)));
        Sdk.getAccountType(tvm.functionId(checkWalletState), walletAddr);
    }

    function checkWalletState(int8 acc_type) public {
        if (acc_type != 1) {
            if (acc_type == 2) {
                // frozen account
                returnOnError(Status.WalletFrozen);
                return;
            }
            Terminal.print(0, "User Wallet is inactive. Deploying...");
            m_gotoId = tvm.functionId(printWalletStatus);
            signSubscriptionWalletCode(m_sbHandle, m_wallet, m_ownerKey);
        } else {
            QueryServices();
        }
    }

    function buildSubscriptionIndex(uint256 ownerKey) public view returns (TvmCell) {
        TvmBuilder saltBuilder;
        saltBuilder.store(ownerKey);
        TvmCell code = tvm.setCodeSalt(
            m_subscriptionIndexImage.toSlice().loadRef(),
            saltBuilder.toCell()
        );
        return code;             
    }

    function deployAccountHelper(uint256 ownerKey, uint256 serviceKey, TvmCell params, bytes signature) public view {
        require(msg.value >= 1 ton, 102);
        TvmCell state = buildAccount(ownerKey,serviceKey,params);
        address subsAddr = address(tvm.hash(state));
        new Subscription{value: 1 ton, flag: 1, bounce: true, stateInit: state}(buildSubscriptionIndex(ownerKey), signature, subsAddr);
    }

    function deployAccount(bytes signature) public view {
        TvmCell body = tvm.encodeBody(SubsMan.deployAccountHelper, m_ownerKey, m_serviceKey, svcParams, signature);
        this.callMultisig(m_wallet, m_ownerKey, m_sbHandle, address(this), body, DEPLOY_FEE, tvm.functionId(checkAccount));
    }
 
     function deployWalletHelper(uint256 ownerKey, bytes signature) public view {
        TvmCell state = tvm.insertPubkey(tvm.buildStateInit({pubkey: ownerKey, code: m_subscriptionWalletImage.toSlice().loadRef()}), ownerKey);
        new Wallet {value: 1 ton, flag: 1, stateInit: state}(m_subscriptionBaseImage, signature);
    }

    function deployWallet(bytes signature) view public {
        TvmCell body = tvm.encodeBody(SubsMan.deployWalletHelper, m_ownerKey, signature);
        this.callMultisig(m_wallet, m_ownerKey, m_sbHandle, address(this), body, DEPLOY_FEE, m_gotoId);
    }

    // API function
    function signSubscriptionWalletCode(uint32 sbHandle, address wallet, uint256 ownerKey) public {
        m_sbHandle = sbHandle;
        m_ownerKey = ownerKey;
        m_wallet = wallet;
        if (m_gotoId != tvm.functionId(printWalletStatus) ) {
            m_invoker = msg.sender;
            m_gotoId = tvm.functionId(onSignSubscriptionWalletCode);
        }
        Sdk.signHash(tvm.functionId(deployWallet), m_sbHandle, tvm.hash(m_subscriptionWalletImage.toSlice().loadRef()));
    }

    function onSignSubscriptionWalletCode() public view {
       IonSignSubscriptionWalletCode(m_invoker).walletDetails();
    }

    function printWalletStatus() public {
        m_continue = tvm.functionId(QueryServices);
        Terminal.print(m_continue, "Wallet has been deployed.\nDeploying subscription contract...");
    }

    function checkAccount() public {
        address account = address(tvm.hash(buildAccount(m_ownerKey, m_serviceKey, svcParams)));
        Sdk.getAccountCodeHash(tvm.functionId(checkHash), account);
    }

    function menuCheckAccount(uint32 index) public {
        index;
        checkAccount();
    }

    function checkHash(uint256 code_hash) public {
        if (code_hash == tvm.hash(buildAccount(m_ownerKey, m_serviceKey, svcParams)) || code_hash == 0) {
            Menu.select("Waiting for the subcription deployment...", "", [ MenuItem("Check again", "", tvm.functionId(menuCheckAccount)) ]);
            return;
        }
        returnOnDeployStatus(Status.Success);
    }

    function callMultisig(address src, uint256 pubkey, uint32 sbhandle, address dest, TvmCell payload, uint128 value, uint32 gotoId) public {
        m_gotoId = gotoId;
        IMultisig(src).sendTransaction{
            abiVer: 2,
            extMsg: true,
            sign: true,
            pubkey: pubkey,
            time: 0,
            expire: 0,
            signBoxHandle: sbhandle,
            callbackId: tvm.functionId(onSuccess),
            onErrorId: tvm.functionId(onError)
        }(dest, value, true, 3, payload);
    }

    function onSuccess() public view {
        if (m_gotoId == tvm.functionId(checkAccount)) {
            this.checkAccount();
        }
        if (m_gotoId == tvm.functionId(printWalletStatus)) {
            this.printWalletStatus();
        }
        if (m_gotoId == tvm.functionId(printServiceStatus)) {
            this.printServiceStatus();
        }
        if (m_gotoId == tvm.functionId(onSignSubscriptionWalletCode)) {
            this.onSignSubscriptionWalletCode();
        }
    }

    function onError(uint32 sdkError, uint32 exitCode) public {
        // TODO: handle errors
        Terminal.print(0, format("Error: sdk code = {}, exit code = {}", sdkError, exitCode));
        returnOnError(Status.MultisigFailed);
    }

    /// @notice API function.
    function invokeDeploySubscription(
        uint256 ownerKey,
        uint256 serviceKey,
        address wallet,
        uint32 sbHandle,
        TvmCell args
    ) public {
        m_deployFlags = 0;
        m_invokeType = Invoke.NewSubscription;
        m_invoker = msg.sender;
        if (ownerKey == 0) {
            returnOnError(Status.ZeroKey);
            return;
        }
        if (sbHandle == 0) {
            returnOnError(Status.InvalidSigningBoxHandle);
            return;
        }
        m_ownerKey = ownerKey;
        m_serviceKey = serviceKey;
        m_wallet = wallet;
        m_args = args;
        m_sbHandle = sbHandle;
        checkWallet();
    }

    /// @notice API function.
    function invokeDeploySubscriptionService(
        uint256 ownerKey,
        address to,
        address wallet,
        uint32 sbHandle,
        uint32 period,
        uint128 value,
        string name,
        string description,
        TvmCell args
    ) public {
        s_invoker = msg.sender;
        s_invokeType = Invoke.NewSubscriptionService;
        if (ownerKey == 0) {
            returnOnError(Status.ZeroKey);
            return;
        }
        if (sbHandle == 0) {
            returnOnError(Status.InvalidSigningBoxHandle);
            return;
        }
        s_ownerKey = ownerKey;
        TvmBuilder params;
        params.store(to, value, period, name, description);
        svcParams = params.toCell();
        s_args = args;
        s_sbHandle = sbHandle;
        s_wallet = wallet;
        signServiceCode();
    }

    function signServiceCode() public {
        Sdk.signHash(tvm.functionId(deployService), s_sbHandle, tvm.hash(buildServiceHelper()));
    }

    function signSubscriptionIndexCode(uint256 ownerKey) public {
        Sdk.signHash(tvm.functionId(deployAccount), m_sbHandle, tvm.hash(buildSubscriptionIndex(ownerKey)));
    }

    function QueryServices() public {
        TvmCell code = buildServiceHelper();
        uint256 svc_addr = tvm.hash(buildService(m_serviceKey))-1;
        address addr = address.makeAddrStd(0, svc_addr);
        Sdk.getAccountsDataByHash(
            tvm.functionId(getServiceParams),
            tvm.hash(code),
            addr
        );
    }

    function _decodeServiceParams(TvmCell data) internal pure returns (TvmCell) {
        (, , , TvmCell params) = data.toSlice().decode(uint256, uint64, bool, TvmCell);
        return params;
    }

    function _decodeServiceKey(TvmCell data) internal pure returns (uint256) {
        (uint256 svcKey, ,) = data.toSlice().decode(uint256, uint64, bool);
        return svcKey;
    }

    function getServiceParams(AccData[] accounts) public {
        svcParams = _decodeServiceParams(accounts[0].data);
        signSubscriptionIndexCode(m_ownerKey);
    }

    //On-chain function
    function buildServiceHelper() private view returns (TvmCell) {
        TvmCell code = s_subscriptionServiceImage.toSlice().loadRef();
        return code;      
    }

    //On-chain function
    function buildService(uint256 serviceKey) private view returns (TvmCell image) {
        TvmCell code = buildServiceHelper();
        TvmCell state = tvm.buildStateInit({
            code: code,
            pubkey: serviceKey,
            varInit: {
                serviceKey: serviceKey
            },
            contr: SubscriptionService
        });
        image = tvm.insertPubkey(state, serviceKey);
    }

    //On-chain function
    function deployServiceHelper(uint256 serviceKey, TvmCell params, bytes signature) public view {
        require(msg.value >= 1 ton, 102);
        TvmCell state = buildService(serviceKey);
        new SubscriptionService{value: 1 ton, flag: 1, bounce: true, stateInit: state}(signature, params);
    }

    function deployService(bytes signature) view public {
        TvmCell body = tvm.encodeBody(SubsMan.deployServiceHelper, s_ownerKey, svcParams, signature);
        this.callMultisig(s_wallet, s_ownerKey, s_sbHandle, address(this), body, DEPLOY_FEE, tvm.functionId(printServiceStatus));
    }

    function printServiceStatus() public view {
        // need to add check for code_hash by address
        address addr = address(tvm.hash(buildService(s_ownerKey)));
        ISubsManCallbacksService(s_invoker).onSubscriptionServiceDeploy(Status.Success, addr);
    }

    /// @notice API function.
    function invokeQuerySubscriptions(uint256 ownerKey) public {
        m_invokeType = Invoke.QuerySubscriptions;
        m_invoker = msg.sender;
        Sdk.getAccountsDataByHash(
            tvm.functionId(setSubscriptions),
            tvm.hash(buildSubscriptionIndex(ownerKey)),
            address.makeAddrStd(-1, 0)
        );
    }
    
    function _getAccountCode() private view returns (TvmCell) {
        TvmCell code = m_subscriptionBaseImage.toSlice().loadRef();
        return code;
    }

    /// @notice API function.
    function invokeQuerySubscribers(uint256 serviceKey) public {
        s_invoker = msg.sender;
        Sdk.getAccountsDataByHash(
            tvm.functionId(setSubscriptionsSubscriber),
            tvm.hash(_getAccountCodeSubscriber(serviceKey)),
            address.makeAddrStd(-1, 0)
        );
    }
    
    function _getAccountCodeSubscriber(uint256 serviceKey) private view returns (TvmCell) {
        TvmCell code = buildAccountHelper(serviceKey);
        return code;
    }

    function _decodeAccountAddress(TvmCell data) internal pure returns (uint256) {
        // pubkey, timestamp, ctor flag, address
        (, , , uint256 serviceKey) = data.toSlice().decode(uint256, uint64, bool, uint256);
        return serviceKey;
    }

    function setSubscriptions(AccData[] accounts) public view {
       IonQuerySubscriptions(m_invoker).onQuerySubscriptions(accounts);
    }

    function _decodeAccountAddressSubscriber(TvmCell data) internal returns (uint256) {
        // pubkey, timestamp, ctor flag, address
        (subscriberKey) = data.toSlice().decode(uint256);
        return subscriberKey;
    }

    function setSubscriptionsSubscriber(AccData[] accounts) public {
        uint256[] pubkeys;
        for (uint i = 0; i < accounts.length; i++) {
            pubkeys.push(_decodeAccountAddressSubscriber(accounts[i].data));
        }
       IonQuerySubscribers(s_invoker).onQuerySubscribers(pubkeys);
    }

    function returnOnError(Status status) internal view {
        if (m_invokeType == Invoke.NewSubscription) {
            returnOnDeployStatus(status);
        }
        if (s_invokeType == Invoke.NewSubscriptionService) {
            returnOnDeploySubscriptionService(status, address(0));
        }
    }

    function returnOnDeployStatus(Status status) internal view {
        ISubsManCallbacks(m_invoker).onSubscriptionDeploy(status);
    }

    function returnOnDeploySubscriptionService(Status status, address addr) internal view {
        ISubsManCallbacksService(s_invoker).onSubscriptionServiceDeploy(status, addr);
    }
    
}
