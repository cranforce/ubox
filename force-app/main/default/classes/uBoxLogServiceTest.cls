@IsTest
private class uBoxLogServiceTest {

    @IsTest
    static void testCreateLog() {
        Id currentUserId = UserInfo.getUserId();

        Test.startTest();
        Id logId = uBoxLogService.createLog(
            'Create User',
            currentUserId,
            currentUserId,
            'Success',
            'Test detail message'
        );
        Test.stopTest();

        System.assertNotEquals(null, logId, 'Should return log record Id');

        uBox_Log__c log = [
            SELECT Action__c, Target_User__c, Performed_By__c, Status__c, Detail__c
            FROM uBox_Log__c
            WHERE Id = :logId
        ];
        System.assertEquals('Create User', log.Action__c);
        System.assertEquals(currentUserId, log.Target_User__c);
        System.assertEquals(currentUserId, log.Performed_By__c);
        System.assertEquals('Success', log.Status__c);
        System.assertEquals('Test detail message', log.Detail__c);
    }

    @IsTest
    static void testCreateLogWithEditAction() {
        Id currentUserId = UserInfo.getUserId();

        Id logId = uBoxLogService.createLog(
            'Edit User',
            currentUserId,
            currentUserId,
            'Partial Success',
            'Some assignments failed'
        );

        uBox_Log__c log = [
            SELECT Action__c, Status__c
            FROM uBox_Log__c
            WHERE Id = :logId
        ];
        System.assertEquals('Edit User', log.Action__c);
        System.assertEquals('Partial Success', log.Status__c);
    }

    @IsTest
    static void testSendCompletionNotificationHandlesGracefully() {
        Id currentUserId = UserInfo.getUserId();

        // Create a log record to use as target
        Id logId = uBoxLogService.createLog(
            'Create User',
            currentUserId,
            currentUserId,
            'Success',
            'Test'
        );

        // This will likely fail in test context (no CustomNotificationType deployed)
        // but should not throw — the method catches exceptions
        Test.startTest();
        uBoxLogService.sendCompletionNotification(
            currentUserId,
            currentUserId,
            'Create User',
            'Success',
            'All assignments completed successfully',
            logId
        );
        Test.stopTest();

        // If we got here without exception, the graceful error handling works
        System.assert(true, 'Notification method should not throw');
    }
}
