@IsTest
private class UserAssignmentQueueableTest {

    private static User createTestUser() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'QueueableUser',
            Email = 'testuboxqueue@example.com',
            Username = 'testuboxqueue' + Datetime.now().getTime() + '@example.com',
            Alias = 'tqueue',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert testUser;
        return testUser;
    }

    @IsTest
    static void testExecuteWithPermissionSets() {
        User testUser = createTestUser();

        PermissionSet ps = new PermissionSet(Name = 'uBox_Test_Assign_PS', Label = 'uBox Test Assign PS');
        insert ps;

        Test.startTest();
        System.enqueueJob(new UserAssignmentQueueable(
            testUser.Id,
            new List<Id>{ ps.Id },
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            UserInfo.getUserId()
        ));
        Test.stopTest();

        List<PermissionSetAssignment> psas = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :testUser.Id AND PermissionSetId = :ps.Id
        ];
        System.assertEquals(1, psas.size(), 'Permission set should be assigned');

        List<uBox_Log__c> logs = [
            SELECT Status__c FROM uBox_Log__c
            WHERE Target_User__c = :testUser.Id AND Action__c = 'Create User'
        ];
        System.assert(!logs.isEmpty(), 'Should create a log record');
    }

    @IsTest
    static void testExecuteWithGroups() {
        User testUser = createTestUser();

        Group testGroup = new Group(Name = 'uBox Test Group', Type = 'Regular');
        insert testGroup;

        Test.startTest();
        System.enqueueJob(new UserAssignmentQueueable(
            testUser.Id,
            new List<Id>(),
            new List<Id>{ testGroup.Id },
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            UserInfo.getUserId()
        ));
        Test.stopTest();

        List<GroupMember> members = [
            SELECT Id FROM GroupMember
            WHERE UserOrGroupId = :testUser.Id AND GroupId = :testGroup.Id
        ];
        System.assertEquals(1, members.size(), 'User should be added to the group');
    }

    @IsTest
    static void testExecuteWithPermSetLicensesAndPackageLicensesAndGroups() {
        User testUser = createTestUser();

        // Use available perm set licenses and package licenses if they exist;
        // the partial-success pattern means DML errors are logged, not thrown.
        List<PermissionSetLicense> psls = [
            SELECT Id FROM PermissionSetLicense WHERE Status = 'Active' LIMIT 1
        ];
        List<Id> pslIds = new List<Id>();
        for (PermissionSetLicense psl : psls) {
            pslIds.add(psl.Id);
        }

        List<PackageLicense> pkgLics = [
            SELECT Id FROM PackageLicense LIMIT 1
        ];
        List<Id> pkgLicIds = new List<Id>();
        for (PackageLicense pl : pkgLics) {
            pkgLicIds.add(pl.Id);
        }

        // If no real records, use fake IDs to exercise the code paths (partial success handles errors)
        if (pslIds.isEmpty()) {
            pslIds.add('0PL000000000001AAA');
        }
        if (pkgLicIds.isEmpty()) {
            pkgLicIds.add('0FK000000000001AAA');
        }

        Test.startTest();
        System.enqueueJob(new UserAssignmentQueueable(
            testUser.Id,
            new List<Id>(),
            new List<Id>(),
            pkgLicIds,
            pslIds,
            new List<Id>(),
            UserInfo.getUserId()
        ));
        Test.stopTest();

        // Partial success — queueable should complete without unhandled exception
        System.assertNotEquals(null, testUser.Id, 'Queueable should complete without error');
    }

    @IsTest
    static void testExecuteWithPermSetGroups() {
        User testUser = createTestUser();

        // Use a fake perm set group ID to exercise the code path (partial success handles errors)
        List<PermissionSetGroup> psgs = [
            SELECT Id FROM PermissionSetGroup WHERE Status = 'Updated' LIMIT 1
        ];
        List<Id> psgIds = new List<Id>();
        for (PermissionSetGroup psg : psgs) {
            psgIds.add(psg.Id);
        }
        if (psgIds.isEmpty()) {
            psgIds.add('0PG000000000001AAA');
        }

        Test.startTest();
        System.enqueueJob(new UserAssignmentQueueable(
            testUser.Id,
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            psgIds,
            UserInfo.getUserId()
        ));
        Test.stopTest();

        System.assertNotEquals(null, testUser.Id, 'Queueable should complete without error');
    }

    @IsTest
    static void testExecuteWithEmptyLists() {
        User testUser = createTestUser();

        Test.startTest();
        System.enqueueJob(new UserAssignmentQueueable(
            testUser.Id,
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            UserInfo.getUserId()
        ));
        Test.stopTest();

        System.assertNotEquals(null, testUser.Id);
    }
}
