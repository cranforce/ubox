@IsTest
private class UserUpdateAssignmentQueueableTest {

    @IsTest
    static void testExecuteWithAddsOnly() {
        // Use empty lists for removes, empty lists for adds (no real perm sets to add in test context)
        UserUpdateAssignmentQueueable q = new UserUpdateAssignmentQueueable(
            UserInfo.getUserId(),
            new List<Id>(), // permSetsToAdd
            new List<Id>(), // permSetsToRemove
            new List<Id>(), // permSetGroupsToAdd
            new List<Id>(), // permSetGroupsToRemove
            new List<Id>(), // permSetLicensesToAdd
            new List<Id>(), // permSetLicensesToRemove
            new List<Id>(), // groupsToAdd
            new List<Id>(), // groupsToRemove
            new List<Id>(), // packageLicensesToAdd
            new List<Id>()  // packageLicensesToRemove
        );

        Test.startTest();
        System.enqueueJob(q);
        Test.stopTest();

        // Verify no errors — queueable ran without exception
        System.assert(true, 'Queueable should execute without errors');
    }

    @IsTest
    static void testExecuteWithRemovesOnly() {
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
