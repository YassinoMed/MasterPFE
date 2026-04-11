<?php

use App\Http\Controllers\Api\V1\BusinessDomainController;
use App\Http\Controllers\Api\V1\ChatbotController;
use App\Http\Controllers\Api\V1\ChatbotPromptConfigController;
use App\Http\Controllers\Api\V1\HealthController;
use App\Http\Controllers\Api\V1\SensitivityLevelController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/health', HealthController::class);

    Route::apiResource('business-domains', BusinessDomainController::class)
        ->parameters(['business-domains' => 'domain'])
        ->except(['destroy']);

    Route::apiResource('sensitivity-levels', SensitivityLevelController::class)
        ->parameters(['sensitivity-levels' => 'level'])
        ->except(['destroy']);

    Route::apiResource('chatbots', ChatbotController::class)->except(['destroy']);
    Route::patch('/chatbots/{chatbot}/status', [ChatbotController::class, 'status']);
    Route::get('/chatbots/{chatbot}/roles', [ChatbotController::class, 'roles']);
    Route::put('/chatbots/{chatbot}/roles', [ChatbotController::class, 'updateRoles']);
    Route::get('/chatbots/{chatbot}/prompt-configs', [ChatbotPromptConfigController::class, 'index']);
    Route::post('/chatbots/{chatbot}/prompt-configs', [ChatbotPromptConfigController::class, 'store']);
});
