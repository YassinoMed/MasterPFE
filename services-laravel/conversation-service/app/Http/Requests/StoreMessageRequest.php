<?php

namespace App\Http\Requests;

use App\Models\Message;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'sender' => ['nullable', Rule::in([Message::SENDER_USER, Message::SENDER_ASSISTANT, Message::SENDER_SYSTEM])],
            'body' => ['required', 'string', 'max:8000'],
            'citations' => ['nullable', 'array'],
            'safety_flags' => ['nullable', 'array'],
            'generate_mock_answer' => ['nullable', 'boolean'],
        ];
    }
}
