<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('conversations', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('chatbot_slug');
            $table->string('chatbot_name');
            $table->string('domain_slug')->nullable();
            $table->string('user_reference');
            $table->string('user_role')->nullable();
            $table->string('title');
            $table->string('status')->default('open');
            $table->string('sensitivity')->default('medium');
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->index(['user_reference', 'status']);
            $table->index(['chatbot_slug', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('conversations');
    }
};
