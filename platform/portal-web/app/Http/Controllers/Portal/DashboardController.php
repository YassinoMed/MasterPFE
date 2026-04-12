<?php

namespace App\Http\Controllers\Portal;

use App\Http\Controllers\Controller;
use App\Services\PortalBackendClient;
use App\Support\DemoPortalData;
use Illuminate\Contracts\View\View;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    public function __construct(private readonly PortalBackendClient $backends)
    {
    }

    public function user(): View
    {
        return $this->page('user', 'Portail utilisateur', DemoPortalData::userDashboard());
    }

    public function admin(): View
    {
        return $this->page('admin', 'Console administration', DemoPortalData::adminDashboard());
    }

    public function users(): View
    {
        return $this->page('users', 'Gestion utilisateurs', [
            'users' => $this->backends->users(),
            'source' => $this->backends->source('auth_users'),
        ]);
    }

    public function roles(): View
    {
        return $this->page('roles', 'Roles et permissions', [
            'roles' => $this->backends->roles(),
            'source' => $this->backends->source('auth_users'),
        ]);
    }

    public function chatbots(): View
    {
        return $this->page('chatbots', 'Gestion chatbots', [
            'chatbots' => $this->backends->chatbots(),
            'source' => $this->backends->source('chatbot_manager'),
        ]);
    }

    public function chat(): View
    {
        return $this->page('chat', 'Conversation demo', $this->backends->conversation());
    }

    public function history(): View
    {
        return $this->page('history', 'Historique conversations', [
            'history' => $this->backends->conversationHistory(),
            'source' => $this->backends->source('conversation'),
        ]);
    }

    public function security(): View
    {
        return $this->page('security', 'Supervision securite', $this->backends->securityIncidents());
    }

    public function devsecops(): View
    {
        return $this->page('devsecops', 'Supervision DevSecOps', DemoPortalData::devsecopsPipeline());
    }

    public function apiUser(): JsonResponse
    {
        return response()->json(DemoPortalData::userDashboard());
    }

    public function apiAdmin(): JsonResponse
    {
        return response()->json(DemoPortalData::adminDashboard());
    }

    public function apiChatbots(): JsonResponse
    {
        return response()->json([
            'chatbots' => $this->backends->chatbots(),
            'source' => $this->backends->source('chatbot_manager'),
        ]);
    }

    public function apiUsers(): JsonResponse
    {
        return response()->json([
            'users' => $this->backends->users(),
            'source' => $this->backends->source('auth_users'),
        ]);
    }

    public function apiRoles(): JsonResponse
    {
        return response()->json([
            'roles' => $this->backends->roles(),
            'source' => $this->backends->source('auth_users'),
        ]);
    }

    public function apiConversation(): JsonResponse
    {
        return response()->json($this->backends->conversation());
    }

    public function apiHistory(): JsonResponse
    {
        return response()->json([
            'history' => $this->backends->conversationHistory(),
            'source' => $this->backends->source('conversation'),
        ]);
    }

    public function apiSecurity(): JsonResponse
    {
        return response()->json($this->backends->securityIncidents());
    }

    public function apiDevSecOps(): JsonResponse
    {
        return response()->json(DemoPortalData::devsecopsPipeline());
    }

    private function page(string $activePage, string $title, array $data): View
    {
        return view('portal.shell', [
            'activePage' => $activePage,
            'title' => $title,
            'data' => $data,
        ]);
    }
}
