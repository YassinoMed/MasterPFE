<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'service' => 'chatbot-manager-service',
        'status' => 'ok',
        'api' => '/api/v1',
    ]);
});
