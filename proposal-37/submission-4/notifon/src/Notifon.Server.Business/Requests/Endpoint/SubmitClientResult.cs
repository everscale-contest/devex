namespace Notifon.Server.Business.Requests.Endpoint {
    public interface SubmitClientResult {
        SubmitClientResultType ResultType { get; }
        object ResultValue { get; }
    }
}