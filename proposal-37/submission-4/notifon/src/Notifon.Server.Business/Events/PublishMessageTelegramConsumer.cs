﻿using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using MassTransit;
using Microsoft.Extensions.Options;
using Notifon.Server.Business.Models;
using Notifon.Server.Configuration.Options;
using Notifon.Server.Models;

namespace Notifon.Server.Business.Events {
    public class PublishMessageTelegramConsumer : IConsumer<PublishMessage> {
        private const string SendMessageUrlFormat = "https://api.telegram.org/bot{0}/sendMessage";

        private readonly HttpClient _httpClient;
        private readonly IOptions<TelegramOptions> _telegramOptionsAccessor;

        public PublishMessageTelegramConsumer(HttpClient httpClient, IOptions<TelegramOptions> telegramOptionsAccessor) {
            _httpClient = httpClient;
            _telegramOptionsAccessor = telegramOptionsAccessor;
        }

        public async Task Consume(ConsumeContext<PublishMessage> context) {
            if (context.Message.EndpointType != EndpointType.Telegram) return;

            var cancellationToken = context.CancellationToken;
            var parameters = TelegramParameters.Create(context.Message, () => _telegramOptionsAccessor.Value);

            var url = string.Format(SendMessageUrlFormat, parameters.BotToken);
            var request = new { chat_id = $"{parameters.ChatId}", text = parameters.Text };
            var response = await _httpClient.PostAsJsonAsync(url, request, cancellationToken);
            response.EnsureSuccessStatusCode();
        }
    }

    public class PublishMessageTelegramConsumerDefinition : PublishMessageConsumerDefinitionBase<
        PublishMessageTelegramConsumer> {
        public PublishMessageTelegramConsumerDefinition(IOptions<RetryPolicyOptions> retryPolicyOptionsAccessor) :
            base(retryPolicyOptionsAccessor) { }
    }
}