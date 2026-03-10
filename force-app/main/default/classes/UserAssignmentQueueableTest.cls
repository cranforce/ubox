@IsTest
private class UserAssignmentQueueableTest {

    @IsTest
    static void testExecuteWithPermissionSets() {
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

        List<PermissionSet> availablePS = [
            SELECT Id FROM PermissionSet
            WHERE IsOwnedByProfile = false
            AND IsCustom = true
            LIMIT 1
        ];

        List<Id> psIds = new List<Id>();
        for (PermissionSet ps : availablePS) {
            psIds.add(ps.Id);
        }

        Test.startTest();
        System.enqueueJob(new UserAssignmentQueueable(
            testUser.Id,
            psIds,
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>()
        ));
        Test.stopTest();

        if (!psIds.isEmpty()) {
            List<PermissionSetAssignment> psas = [
                SELECT Id FROM PermissionSetAssignment
                WHERE AssigneeId = :testUser.Id
                AND PermissionSet.IsOwnedByProfile = false
                AND PermissionSet.IsCustom = true
            ];
            System.assert(!psas.isEmpty(), 'Permission set should be assigned');
        }
    }

    @IsTest
    static void testExecuteWithGroups() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User testUser = new User(
            FirstName = 'Test',
            LastName = 'QueueableGroup',
            Email = 'testuboxgrp@example.com',
            Username = 'testuboxgrp' + Datetime.now().getTime() + '@example.com',
            Alias = 'tgrp',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert testUser;

        Group testGroup = new Group(Name = 'uBox Test Group', Type = 'Regular');
        insert testGroup;

        Test.startTest();
        System.enqueueJob(new UserAssignmentQueueable(
            testUser.Id,
            new List<Id>(),
            new List<Id>{ testGroup.Id },
            new List<Id>(),
            new List<Id>(),
            new List<Id>()
        ));
        Test.stopTest();

        List<GroupMember> members = [
            SELECT Id FROM GroupMember
            WHERE UserOrGroupId = :testUser.Id
            AND GroupId = :testGroup.Id
        ];
        System.assertEquals(1, members.size(), 'User should be added to the group');
    }

    @IsTest
    static void testExecuteWithEmptyLists() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User testUser = new User(
            FirstName = 'Test',
            LastName = 'QueueableEmpty',
            Email = 'testuboxempty@example.com',
            Username = 'testuboxempty' + Datetime.now().getTime() + '@example.com',
            Alias = 'tempty',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert testUser;

        Test.startTest();
        System.enqueueJob(new UserAssignmentQueueable(
            testUser.Id,
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>()
        ));
        Test.stopTest();

        // Should complete without errors
        System.assertNotEquals(null, testUser.Id);
    }
}
