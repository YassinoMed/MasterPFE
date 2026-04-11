<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StorePromptConfigRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'version' => ['required', 'string', 'max:40'],
            'system_prompt' => ['required', 'string', 'min:20', 'max:8000'],
            'is_current' => ['nullable', 'boolean'],
            'change_note' => ['nullable', 'string', 'max:500'],
        ];
    }
}
