<?php

namespace Tests;

use PHPUnit\Framework\TestCase;
use App\Services\ModerationService;

class ModerationServiceTest extends TestCase
{
    private ModerationService $moderationService;

    protected function setUp(): void
    {
        $this->moderationService = new ModerationService();
    }

    public function testBasicModerationRejectsEmail()
    {
        $content = "Contact me at test@example.com for more info";
        $result = $this->moderationService->moderateContent($content);
        
        $this->assertEquals('rejected', $result['status']);
        $this->assertStringContainsString('email', strtolower($result['reason']));
    }

    public function testBasicModerationRejectsPhoneNumber()
    {
        $content = "Call me at 555-123-4567 anytime";
        $result = $this->moderationService->moderateContent($content);
        
        $this->assertEquals('rejected', $result['status']);
        $this->assertStringContainsString('phone', strtolower($result['reason']));
    }

    public function testBasicModerationRejectsTooShortContent()
    {
        $content = "Hi";
        $result = $this->moderationService->moderateContent($content);
        
        $this->assertEquals('rejected', $result['status']);
        $this->assertStringContainsString('short', strtolower($result['reason']));
    }

    public function testBasicModerationApprovesValidContent()
    {
        $content = "This is a valid confession with enough content to pass moderation checks.";
        $result = $this->moderationService->moderateContent($content);
        
        $this->assertEquals('approved', $result['status']);
    }
}
