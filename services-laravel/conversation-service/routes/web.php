<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'service' => 'conversation-service',
        'status' => 'ok',
        'api' => '/api/v1',
    ]);
});
