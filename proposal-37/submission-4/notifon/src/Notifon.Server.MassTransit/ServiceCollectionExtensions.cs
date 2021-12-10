﻿using MassTransit;
using MassTransit.PrometheusIntegration;
using MassTransit.RabbitMqTransport;
using MassTransit.Registration;
using MassTransit.SignalR;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Notifon.Server.Business.Events;
using Notifon.Server.Business.Requests.Api;
using Notifon.Server.Business.Requests.Endpoint;
using Notifon.Server.Business.Requests.TonClient;
using Notifon.Server.Configuration.Options;
using Notifon.Server.Kafka;
using Notifon.Server.SignalR;

namespace Notifon.Server.MassTransit {
    public static class ServiceCollectionExtensions {
        public static IServiceCollection AddMassTransit(this IServiceCollection services, bool useRabbitMq) {
            services
                .AddMediator(x => {
                    x.AddConsumer<GetServerStatusConsumer>();
                    x.AddRequestClient<GetServerStatus>();
                    x.AddConsumer<SubmitClientConsumer>();
                    x.AddRequestClient<SubmitClient>();
                    x.AddConsumer<DecryptEncryptedMessageConsumer>();
                    x.AddRequestClient<DecryptEncryptedMessage>();
                    x.AddConsumer<FormatDecryptedMessageConsumer>();
                    x.AddRequestClient<FormatDecryptedMessage>();
                    x.AddConsumer<FreeTonSendMessageConsumer>();
                    x.AddRequestClient<FreeTonSendMessage>();
                    x.AddConsumer<FreeTonDeployConsumer>();
                    x.AddRequestClient<FreeTonDeploy>();
                })
                .AddMassTransit(x => {
                    x.AddDelayedMessageScheduler();
                    x.AddConsumer<PublishMessageHttpConsumer, PublishMessageHttpConsumerDefinition>();
                    x.AddConsumer<PublishMessageTelegramConsumer, PublishMessageTelegramConsumerDefinition>();
                    x.AddConsumer<PublishMessageMailgunConsumer, PublishMessageMailgunConsumerDefinition>();
                    x.AddConsumer<PublishMessageByUserIdConsumer, PublishMessageByUserIdConsumerDefinition>();
                    x.AddConsumer<PublishMessageFcmConsumer, PublishMessageFcmConsumerDefinition>();
                    x.AddRider(RiderRegistrationConfiguratorExtensions.KafkaRegistrationConfigurator);
                    x.AddSignalRHub<SignalRHub>();
                    x.SetKebabCaseEndpointNameFormatter();

                    if (useRabbitMq)
                        x.UsingRabbitMq((context, cfg) => {
                            SetupRabbitMqHost(cfg, context);
                            ConfigureContext(cfg, context);
                            cfg.ConfigureEndpoints(context);
                        });
                    else
                        x.UsingInMemory((context, cfg) => {
                            ConfigureContext(cfg, context);
                            cfg.UseMessageScope(context);
                            cfg.ConfigureEndpoints(context);
                        });
                })
                .AddMassTransitHostedService();

            return services;
        }

        private static void ConfigureContext(IBusFactoryConfigurator cfg, IConfigurationServiceProvider context) {
            cfg.UseDelayedMessageScheduler();
            cfg.UsePublishFilter(typeof(PublishMessageDecryptMessageFilter<>), context);
            cfg.UsePublishFilter(typeof(PublishMessageLoggingFilter<>), context);
            cfg.UsePrometheusMetrics();
        }

        private static void SetupRabbitMqHost(IRabbitMqBusFactoryConfigurator cfg,
            IConfigurationServiceProvider context) {
            var options = context.GetRequiredService<IOptions<RabbitMqOptions>>().Value;
            cfg.Host(options.Host, r => {
                r.Username(options.Username);
                r.Password(options.Password);
            });
        }
    }
}