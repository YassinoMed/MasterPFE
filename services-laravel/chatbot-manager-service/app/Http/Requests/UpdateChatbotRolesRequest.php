<?php

namespace App\Http\Requests;

use App\Services\ChatbotGovernanceService;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateChatbotRolesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'roles' => ['required', 'array', 'min:1'],
            'roles.*.role_slug' => ['required', 'string', 'max:100', 'regex:/^[a-z0-9-]+$/', Rule::in(ChatbotGovernanceService::ALLOWED_ROLE_SLUGS)],
            'roles.*.is_allowed' => ['required', 'boolean'],
        ];
    }
}
