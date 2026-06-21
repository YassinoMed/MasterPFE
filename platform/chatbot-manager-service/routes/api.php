<?php

use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    Route::get('/health', function () {
        return response()->json([
            'service' => 'chatbot-manager-service',
            'status' => 'ok',
        ]);
    });

    // GET /chatbots
    // POST /chatbots
    // GET /chatbots/{chatbot}
    // PATCH /chatbots/{chatbot}
    // GET /domains
    // GET /sensitivity-levels
    // GET /chatbots/{chatbot}/access-rules
    // PATCH /chatbots/{chatbot}/prompt-config
});
