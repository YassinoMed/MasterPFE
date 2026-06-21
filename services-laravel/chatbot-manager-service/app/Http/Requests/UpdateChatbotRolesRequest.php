<?php

namespace App\Http\Requests;

use App\Services\ChatbotGovernanceService;
use App\Http\Requests\Concerns\AuthorizesServiceRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateChatbotRolesRequest extends FormRequest
{
    use AuthorizesServiceRequest;

    public function authorize(): bool
    {
        return $this->authorizeServiceRequest();
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
