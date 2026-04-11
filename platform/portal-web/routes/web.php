<?php

use App\Http\Controllers\Portal\DashboardController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('securerag-home');
});

Route::get('/app', [DashboardController::class, 'user'])->name('portal.user');
Route::get('/admin', [DashboardController::class, 'admin'])->name('portal.admin');
Route::get('/admin/users', [DashboardController::class, 'users'])->name('portal.users');
Route::get('/admin/roles', [DashboardController::class, 'roles'])->name('portal.roles');
Route::get('/chatbots', [DashboardController::class, 'chatbots'])->name('portal.chatbots');
Route::get('/chat', [DashboardController::class, 'chat'])->name('portal.chat');
Route::get('/history', [DashboardController::class, 'history'])->name('portal.history');
Route::get('/security', [DashboardController::class, 'security'])->name('portal.security');
Route::get('/devsecops', [DashboardController::class, 'devsecops'])->name('portal.devsecops');
