<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateChatbotRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $chatbotId = $this->route('chatbot')?->id;

        return [
            'name' => ['sometimes', 'required', 'string', 'max:140'],
            'slug' => ['sometimes', 'required', 'string', 'max:120', 'regex:/^[a-z0-9-]+$/', Rule::unique('chatbots', 'slug')->ignore($chatbotId)],
            'description' => ['sometimes', 'nullable', 'string', 'max:800'],
            'business_domain_slug' => ['sometimes', 'required', 'string', 'exists:business_domains,slug'],
            'sensitivity_level_slug' => ['sometimes', 'required', 'string', 'exists:sensitivity_levels,slug'],
            'status' => ['sometimes', Rule::in(['draft', 'active', 'disabled', 'archived'])],
            'visibility' => ['sometimes', Rule::in(['restricted', 'internal', 'public'])],
            'system_prompt_version' => ['sometimes', 'nullable', 'string', 'max:40'],
            'security_profile' => ['sometimes', 'nullable', 'string', 'max:80'],
            'is_active' => ['sometimes', 'boolean'],
            'settings' => ['sometimes', 'nullable', 'array'],
        ];
    }
}
