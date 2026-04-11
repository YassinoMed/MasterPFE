<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateChatbotStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in(['draft', 'active', 'disabled', 'archived'])],
            'is_active' => ['nullable', 'boolean'],
            'reason' => ['nullable', 'string', 'max:240'],
        ];
    }
}
