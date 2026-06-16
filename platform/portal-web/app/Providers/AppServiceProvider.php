<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        if (class_exists(\SecureRag\LaravelSecurity\Http\Middleware\PrometheusMetricsMiddleware::class)) {
            \SecureRag\LaravelSecurity\Http\Middleware\PrometheusMetricsMiddleware::bootQueueTracking();
        }
    }
}
