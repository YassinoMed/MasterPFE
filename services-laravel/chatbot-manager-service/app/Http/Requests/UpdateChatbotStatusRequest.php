<?php

namespace App\Http\Requests;

use App\Http\Requests\Concerns\AuthorizesServiceRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateChatbotStatusRequest extends FormRequest
{
    use AuthorizesServiceRequest;

    public function authorize(): bool
    {
        return $this->authorizeServiceRequest();
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
