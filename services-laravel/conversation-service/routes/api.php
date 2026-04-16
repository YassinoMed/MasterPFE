<?php

use App\Http\Controllers\Api\V1\ConversationController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\MessageController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/health', HealthController::class);

    Route::middleware('throttle:120,1')->group(function (): void {
        Route::apiResource('conversations', ConversationController::class)->only(['index', 'store', 'show']);
        Route::patch('/conversations/{conversation}/status', [ConversationController::class, 'status']);
        Route::get('/conversations/{conversation}/messages', [MessageController::class, 'index']);
        Route::post('/conversations/{conversation}/messages', [MessageController::class, 'store']);
    });
});
