<?php

use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/platform/summary', function () {
        return response()->json([
            'platform' => 'SecureRAG Hub',
            'status' => 'bootstrap-ready',
            'frontend' => 'Laravel 12',
            'modules' => [
                'user-portal',
                'admin-portal',
                'security-supervision',
                'devsecops-observability',
            ],
        ]);
    });
});

Route::prefix('internal')->group(function (): void {
    Route::get('/health', function () {
        return response()->json([
            'service' => 'portal-web',
            'status' => 'ok',
        ]);
    });
});
