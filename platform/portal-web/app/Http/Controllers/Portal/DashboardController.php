<?php

namespace App\Http\Controllers\Portal;

use App\Http\Controllers\Controller;
use App\Support\DemoPortalData;
use Illuminate\Contracts\View\View;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
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
        return $this->page('users', 'Gestion utilisateurs', ['users' => DemoPortalData::users()]);
    }

    public function roles(): View
    {
        return $this->page('roles', 'Roles et permissions', ['roles' => DemoPortalData::roles()]);
    }

    public function chatbots(): View
    {
        return $this->page('chatbots', 'Gestion chatbots', ['chatbots' => DemoPortalData::chatbots()]);
    }

    public function chat(): View
    {
        return $this->page('chat', 'Conversation demo', DemoPortalData::conversation());
    }

    public function history(): View
    {
        return $this->page('history', 'Historique conversations', ['history' => DemoPortalData::conversationHistory()]);
    }

    public function security(): View
    {
        return $this->page('security', 'Supervision securite', DemoPortalData::securityIncidents());
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
        return response()->json(['chatbots' => DemoPortalData::chatbots()]);
    }

    public function apiUsers(): JsonResponse
    {
        return response()->json(['users' => DemoPortalData::users()]);
    }

    public function apiRoles(): JsonResponse
    {
        return response()->json(['roles' => DemoPortalData::roles()]);
    }

    public function apiConversation(): JsonResponse
    {
        return response()->json(DemoPortalData::conversation());
    }

    public function apiHistory(): JsonResponse
    {
        return response()->json(['history' => DemoPortalData::conversationHistory()]);
    }

    public function apiSecurity(): JsonResponse
    {
        return response()->json(DemoPortalData::securityIncidents());
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
