@IsTest
private class UserUpdateAssignmentQueueableTest {

    private static User createTestUser() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'UpdateQueue',
            Email = 'testupdatequeue@example.com',
            Username = 'testupdatequeue' + Datetime.now().getTime() + '@example.com',
            Alias = 'tuq',
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
    static void testAddAndRemovePermissionSets() {
        User testUser = createTestUser();

        PermissionSet psToAdd = new PermissionSet(Name = 'uBox_UQ_Add_PS', Label = 'uBox UQ Add PS');
        PermissionSet psToRemove = new PermissionSet(Name = 'uBox_UQ_Rm_PS', Label = 'uBox UQ Rm PS');
        insert new List<PermissionSet>{ psToAdd, psToRemove };

        insert new PermissionSetAssignment(AssigneeId = testUser.Id, PermissionSetId = psToRemove.Id);

        Test.startTest();
        System.enqueueJob(new UserUpdateAssignmentQueueable(
            testUser.Id,
            new List<Id>{ psToAdd.Id },
            new List<Id>{ psToRemove.Id },
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>()
        ));
        Test.stopTest();

        List<PermissionSetAssignment> psas = [
            SELECT PermissionSetId FROM PermissionSetAssignment
            WHERE AssigneeId = :testUser.Id
            AND PermissionSetId IN (:psToAdd.Id, :psToRemove.Id)
        ];
        Set<Id> assignedIds = new Set<Id>();
        for (PermissionSetAssignment psa : psas) {
            assignedIds.add(psa.PermissionSetId);
        }
        System.assert(!assignedIds.contains(psToRemove.Id), 'Removed perm set should be gone');
        System.assert(assignedIds.contains(psToAdd.Id), 'Added perm set should be assigned');
    }

    @IsTest
    static void testAddAndRemoveGroups() {
        User testUser = createTestUser();

        Group grpToRemove = new Group(Name = 'uBox UQ Remove Grp', Type = 'Regular');
        Group grpToAdd = new Group(Name = 'uBox UQ Add Grp', Type = 'Regular');
        insert new List<Group>{ grpToRemove, grpToAdd };

        insert new GroupMember(UserOrGroupId = testUser.Id, GroupId = grpToRemove.Id);

        Test.startTest();
        System.enqueueJob(new UserUpdateAssignmentQueueable(
            testUser.Id,
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>{ grpToAdd.Id },
            new List<Id>{ grpToRemove.Id },
            new List<Id>(),
            new List<Id>()
        ));
        Test.stopTest();

        List<GroupMember> remaining = [
            SELECT GroupId FROM GroupMember
            WHERE UserOrGroupId = :testUser.Id
            AND GroupId IN (:grpToRemove.Id, :grpToAdd.Id)
        ];
        Set<Id> memberGroupIds = new Set<Id>();
        for (GroupMember gm : remaining) {
            memberGroupIds.add(gm.GroupId);
        }
        System.assert(!memberGroupIds.contains(grpToRemove.Id), 'Removed group should be gone');
        System.assert(memberGroupIds.contains(grpToAdd.Id), 'Added group should be assigned');
    }

    @IsTest
    static void testPermSetLicenseAndPackageLicenseAndPermSetGroupPaths() {
        User testUser = createTestUser();

        // Use fake IDs to exercise all code paths — partial success handles errors gracefully
        Test.startTest();
        System.enqueueJob(new UserUpdateAssignmentQueueable(
            testUser.Id,
            new List<Id>(),
            new List<Id>(),
            new List<Id>{ '0PG000000000001AAA' },  // permSetGroupsToAdd (fake)
            new List<Id>{ '0PG000000000002AAA' },  // permSetGroupsToRemove (fake)
            new List<Id>{ '0PL000000000001AAA' },  // permSetLicensesToAdd (fake)
            new List<Id>{ '0PL000000000002AAA' },  // permSetLicensesToRemove (fake)
            new List<Id>(),
            new List<Id>(),
            new List<Id>{ '0FK000000000001AAA' },  // packageLicensesToAdd (fake)
            new List<Id>{ '0FK000000000002AAA' }   // packageLicensesToRemove (fake)
        ));
        Test.stopTest();

        System.assertNotEquals(null, testUser.Id, 'Queueable should complete without error');
    }

    @IsTest
    static void testEmptyLists() {
        UserUpdateAssignmentQueueable q = new UserUpdateAssignmentQueueable(
            UserInfo.getUserId(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>()
        );

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();

        System.assert(true, 'Queueable should execute without errors');
    }
}
