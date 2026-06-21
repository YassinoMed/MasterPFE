<?php

namespace Database\Seeders;

use App\Services\ConversationService;
use Illuminate\Database\Seeder;

class ConversationSeeder extends Seeder
{
    public function run(): void
    {
        app(ConversationService::class)->create([
            'chatbot_slug' => 'chatbot-rh',
            'chatbot_name' => 'Assistant RH',
            'domain_slug' => 'rh',
            'user_reference' => 'demo.rh@example.test',
            'user_role' => 'user-rh',
            'title' => 'Question demo sur les conges',
            'sensitivity' => 'medium',
            'metadata' => ['scenario' => 'demo'],
            'initial_message' => 'Comment consulter le solde des conges ?',
        ]);
    }
}
