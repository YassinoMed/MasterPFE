<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('audit_logs', function (Blueprint $table): void {
            $table->string('previous_hash', 64)->nullable()->index();
            $table->string('integrity_hash', 64)->nullable()->unique();
        });
    }

    public function down(): void
    {
        Schema::table('audit_logs', function (Blueprint $table): void {
            $table->dropUnique(['integrity_hash']);
            $table->dropIndex(['previous_hash']);
            $table->dropColumn(['previous_hash', 'integrity_hash']);
        });
    }
};
