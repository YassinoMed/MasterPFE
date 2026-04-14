<?php

namespace App\Http\Requests;

use App\Models\Conversation;
use App\Http\Requests\Concerns\AuthorizesServiceRequest;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateConversationStatusRequest extends FormRequest
{
    use AuthorizesServiceRequest;

    public function authorize(): bool
    {
        return $this->authorizeServiceRequest();
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in([Conversation::STATUS_OPEN, Conversation::STATUS_CLOSED, Conversation::STATUS_ARCHIVED])],
        ];
    }
}
