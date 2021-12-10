using System.Collections.Generic;
using System.Text.Json;
using FluentAssertions;
using Notifon.Server.Business.Models;
using Xunit;

namespace Notifon.Server.Business.Tests.Models {
    public class CommandTests {
        [Theory]
        [InlineData("", CommandType.ListEndpoints, "{}")]
        [InlineData("   ", CommandType.ListEndpoints, "{}")]
        [InlineData("test", CommandType.Test, "{}")]
        [InlineData("telegram -t:1234546778:AABCD-ASD234werf123sdafq23r2sdfasdf", CommandType.AddEndpoint,
            @"{""mainParam"":""telegram"", ""t"":""1234546778:AABCD-ASD234werf123sdafq23r2sdfasdf""}")]
        [InlineData("test -d", CommandType.Test, "{\"d\":null}")]
        [InlineData("secret", CommandType.Secret, "{}")]
        [InlineData("secret Super:SecretKey", CommandType.Secret, "{\"mainParam\":\"Super:SecretKey\"}")]
        [InlineData("http://endpoint -d -a:testa -b:testb:b", CommandType.AddEndpoint,
            "{\"mainParam\":\"http://endpoint\", \"d\":null, \"b\":\"testb:b\", \"a\":\"testa\"}")]
        [InlineData("http://endpoint -d -a:parameter with spaces -b:testb:b", CommandType.AddEndpoint,
            "{\"mainParam\":\"http://endpoint\", \"d\":null, \"b\":\"testb:b\", \"a\":\"parameter with spaces\"}")]
        [InlineData("help", CommandType.Help, "{}")]
        public void CreateCommandFromData(string data, CommandType expectedCommandType, string expectedParametersJson) {
            var expectedParameters = JsonSerializer.Deserialize<Dictionary<string, string>>(expectedParametersJson);

            var command = Command.FromData(data);

            command.CommandType.Should().Be(expectedCommandType);
            command.Parameters.Should().Equal(expectedParameters);
        }
    }
}