﻿using Notifon.Server.Models;

namespace Notifon.Server.Business.Models {
    public class EncryptedMessage : SubscriptionMessage {
        public EncryptedMessage(string nonce, string message) {
            Nonce = nonce;
            Message = message;
        }

        public string Nonce { get; }
        public string Message { get; }
        public string Text => $"{Nonce} {Message}";

        public SubscriptionMessageType MessageType { get; } = SubscriptionMessageType.Encrypted;

        public static EncryptedMessage CreateFromBase(SubscriptionMessage subscriptionMessage) {
            var split = subscriptionMessage.Text.Split(' ', 2);
            return new EncryptedMessage(split[0], split[1]);
        }
    }
}