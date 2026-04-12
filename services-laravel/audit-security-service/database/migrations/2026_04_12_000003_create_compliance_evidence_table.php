<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('compliance_evidence', function (Blueprint $table): void {
            $table->id();
            $table->uuid('uuid')->unique();
            $table->string('control_id');
            $table->string('title');
            $table->string('status')->default('warn');
            $table->string('evidence_uri')->nullable();
            $table->text('summary')->nullable();
            $table->timestamp('collected_at')->nullable();
            $table->json('metadata')->nullable();
            $table->timestamps();

            $table->index(['control_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('compliance_evidence');
    }
};
