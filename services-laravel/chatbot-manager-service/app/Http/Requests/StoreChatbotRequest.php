<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreChatbotRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:140'],
            'slug' => ['required', 'string', 'max:120', 'regex:/^[a-z0-9-]+$/', 'unique:chatbots,slug'],
            'description' => ['nullable', 'string', 'max:800'],
            'business_domain_slug' => ['required', 'string', 'exists:business_domains,slug'],
            'sensitivity_level_slug' => ['required', 'string', 'exists:sensitivity_levels,slug'],
            'status' => ['nullable', Rule::in(['draft', 'active', 'disabled', 'archived'])],
            'visibility' => ['nullable', Rule::in(['restricted', 'internal', 'public'])],
            'system_prompt_version' => ['nullable', 'string', 'max:40'],
            'security_profile' => ['nullable', 'string', 'max:80'],
            'is_active' => ['nullable', 'boolean'],
            'settings' => ['nullable', 'array'],
        ];
    }
}
