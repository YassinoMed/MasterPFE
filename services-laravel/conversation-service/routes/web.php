<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'service' => 'auth-users-service',
        'status' => 'ok',
        'api' => '/api/v1',
    ]);
});
