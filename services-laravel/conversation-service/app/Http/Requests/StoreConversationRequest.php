<?php

namespace App\Http\Requests;

use App\Models\Conversation;
use App\Http\Requests\Concerns\AuthorizesServiceRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreConversationRequest extends FormRequest
{
    use AuthorizesServiceRequest;

    public function authorize(): bool
    {
        return $this->authorizeServiceRequest();
    }

    public function rules(): array
    {
        return [
            'chatbot_slug' => ['required', 'string', 'max:120'],
            'chatbot_name' => ['required', 'string', 'max:160'],
            'domain_slug' => ['nullable', 'string', 'max:120'],
            'user_reference' => ['required', 'string', 'max:160'],
            'user_role' => ['nullable', 'string', 'max:120'],
            'title' => ['required', 'string', 'max:180'],
            'status' => ['nullable', Rule::in([Conversation::STATUS_OPEN, Conversation::STATUS_CLOSED, Conversation::STATUS_ARCHIVED])],
            'sensitivity' => ['nullable', 'string', 'max:60'],
            'metadata' => ['nullable', 'array'],
            'initial_message' => ['nullable', 'string', 'max:4000'],
        ];
    }
}
