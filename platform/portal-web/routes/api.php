<?php

use App\Http\Controllers\Portal\DashboardController;
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

    Route::prefix('portal')->group(function (): void {
        Route::get('/user-dashboard', [DashboardController::class, 'apiUser']);
        Route::get('/admin-dashboard', [DashboardController::class, 'apiAdmin']);
        Route::get('/users', [DashboardController::class, 'apiUsers']);
        Route::get('/roles', [DashboardController::class, 'apiRoles']);
        Route::get('/chatbots', [DashboardController::class, 'apiChatbots']);
        Route::get('/conversation-demo', [DashboardController::class, 'apiConversation']);
        Route::get('/conversation-history', [DashboardController::class, 'apiHistory']);
        Route::get('/security-incidents', [DashboardController::class, 'apiSecurity']);
        Route::get('/devsecops-pipeline', [DashboardController::class, 'apiDevSecOps']);
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
