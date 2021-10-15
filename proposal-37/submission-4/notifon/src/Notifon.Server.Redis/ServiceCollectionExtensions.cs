﻿using System;
using HealthChecks.Redis;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Caching.StackExchangeRedis;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;

namespace Notifon.Server.Redis {
    public static class ServiceCollectionExtensions {
        public static IServiceCollection AddDistributedLockAndCache(this IServiceCollection services, bool useRedis) {
            if (useRedis)
                services
                    .AddSingleton<IDistributedCache, RedisCache>()
                    .AddHealthChecks()
                    .Add(new HealthCheckRegistration("redis", (Func<IServiceProvider, IHealthCheck>)(sp => {
                        var redisConfiguration =
                            sp.GetRequiredService<IOptions<RedisCacheOptions>>().Value.Configuration;
                        return new RedisHealthCheck(redisConfiguration);
                    }), null, null, null));
            else
                services
                    .AddSingleton<IDistributedCache, MemoryDistributedCache>();

            return services;
        }
    }
}