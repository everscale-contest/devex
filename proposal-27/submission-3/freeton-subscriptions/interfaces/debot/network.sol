pragma ton-solidity >= 0.42.0;
pragma AbiHeader time;
pragma AbiHeader pubkey;
pragma AbiHeader expire;

//================================================================================
//
interface INetwork 
{
    function  get(uint32 answerId, bytes url, string[] headers)             external returns (int32 statusCode, string[] retHeaders, string content);
    function post(uint32 answerId, bytes url, string[] headers, bytes body) external returns (int32 statusCode, string[] retHeaders, string content);
}

library Network 
{
    uint256 constant ID = 0xe38aed5884dc3e4426a87c083faaf4fa08109189fbc0c79281112f52e062d8ee;
    int8 constant DEBOT_WC = -31;
    address constant addr     = address.makeAddrStd(DEBOT_WC, ID);

    function  get(uint32 answerId, bytes url, string[] headers)             public pure {    INetwork(addr).get (answerId, url, headers);          }
    function post(uint32 answerId, bytes url, string[] headers, bytes body) public pure {    INetwork(addr).post(answerId, url, headers, body);    }
}

//================================================================================
//
