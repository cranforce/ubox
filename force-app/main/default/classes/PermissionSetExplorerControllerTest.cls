@IsTest
private class PermissionSetExplorerControllerTest {

    private static PermissionSet createTestPermissionSet() {
        PermissionSet ps = new PermissionSet(
            Name = 'uBox_Explorer_Test_' + String.valueOf(Datetime.now().getTime()),
            Label = 'uBox Explorer Test',
            PermissionsApiEnabled = true
        );
        insert ps;
        return ps;
    }

    private static PermissionSet createTestPermissionSetWithObjectPerm() {
        PermissionSet ps = createTestPermissionSet();
        ObjectPermissions op = new ObjectPermissions(
            ParentId = ps.Id,
            SobjectType = 'Account',
            PermissionsRead = true,
            PermissionsCreate = true,
            PermissionsEdit = true
        );
        insert op;
        return ps;
    }

    private static PermissionSetGroup createTestPermissionSetGroup(PermissionSet member) {
        PermissionSetGroup psg = new PermissionSetGroup(
            DeveloperName = 'uBox_PSG_Test_' + String.valueOf(Datetime.now().getTime()),
            MasterLabel = 'uBox PSG Test',
            Description = 'Test group'
        );
        insert psg;
        if (member != null) {
            insert new PermissionSetGroupComponent(
                PermissionSetGroupId = psg.Id,
                PermissionSetId = member.Id
            );
        }
        return psg;
    }

    private static User createTestUser() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'PSE',
            LastName = 'Tester',
            Email = 'psetester@example.com',
            Username = 'psetester' + Datetime.now().getTime() + '@example.com.ubox',
            Alias = 'psetst',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert u;
        return u;
    }

    @IsTest
    static void testGetPermissionSetsIncludesGroups() {
        PermissionSet ps = createTestPermissionSet();
        PermissionSetGroup psg = createTestPermissionSetGroup(ps);

        List<Map<String, Object>> results = PermissionSetExplorerController.getPermissionSets();
        System.assertNotEquals(null, results, 'Should return list');
        System.assert(!results.isEmpty(), 'Should include at least one entry');

        Boolean foundPs = false;
        Boolean foundPsg = false;
        for (Map<String, Object> row : results) {
            Id rowId = (Id) row.get('id');
            String rowType = (String) row.get('type');
            if (rowId == ps.Id) {
                foundPs = true;
                System.assertEquals('PermissionSet', rowType, 'PS row should be typed PermissionSet');
            }
            if (rowId == psg.Id) {
                foundPsg = true;
                System.assertEquals('PermissionSetGroup', rowType, 'PSG row should be typed PermissionSetGroup');
            }
        }
        System.assert(foundPs, 'Should include the newly created permission set');
        System.assert(foundPsg, 'Should include the newly created permission set group');
    }

    @IsTest
    static void testGetPermissionSetDetail() {
        PermissionSet ps = createTestPermissionSetWithObjectPerm();

        Map<String, Object> detail = PermissionSetExplorerController.getPermissionSetDetail(ps.Id);

        System.assertNotEquals(null, detail.get('header'), 'Should return header');
        System.assertNotEquals(null, detail.get('userPermissions'), 'Should return user permissions');
        System.assertNotEquals(null, detail.get('objectPermissions'), 'Should return object permissions');
        System.assertNotEquals(null, detail.get('tabSettings'), 'Should return tab settings');
        System.assertNotEquals(null, detail.get('appAccesses'), 'Should return app accesses');
        System.assertNotEquals(null, detail.get('customPermissions'), 'Should return custom permissions');

        Map<String, Object> header = (Map<String, Object>) detail.get('header');
        System.assertEquals(ps.Id, (Id) header.get('id'));
        System.assertEquals('PermissionSet', (String) header.get('type'));

        List<Map<String, String>> userPerms = (List<Map<String, String>>) detail.get('userPermissions');
        System.assert(!userPerms.isEmpty(), 'Should include the API Enabled permission');

        List<Map<String, Object>> objectPerms = (List<Map<String, Object>>) detail.get('objectPermissions');
        System.assertEquals(1, objectPerms.size(), 'Should include the Account object permission');
        System.assertEquals('Account', (String) objectPerms[0].get('apiName'));
    }

    @IsTest
    static void testGetPermissionSetGroupDetail() {
        PermissionSet ps = createTestPermissionSetWithObjectPerm();
        PermissionSetGroup psg = createTestPermissionSetGroup(ps);

        Map<String, Object> detail = PermissionSetExplorerController.getPermissionSetGroupDetail(psg.Id);
        System.assertNotEquals(null, detail.get('header'), 'Should return header');
        Map<String, Object> header = (Map<String, Object>) detail.get('header');
        System.assertEquals(psg.Id, (Id) header.get('id'));
        System.assertEquals('PermissionSetGroup', (String) header.get('type'));

        // Members should include the linked permission set
        List<Map<String, Object>> members = (List<Map<String, Object>>) detail.get('members');
        System.assertNotEquals(null, members, 'Should return members list');
        Boolean foundMember = false;
        for (Map<String, Object> m : members) {
            if (ps.Id == (Id) m.get('id')) { foundMember = true; break; }
        }
        System.assert(foundMember, 'Members should include the linked permission set');
    }

    @IsTest
    static void testGetPermissionSetDetailNotFound() {
        Id fakeId = '0PS000000000000AAA';
        try {
            PermissionSetExplorerController.getPermissionSetDetail(fakeId);
            System.assert(false, 'Should have thrown for missing permission set');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected exception thrown');
        }
    }

    @IsTest
    static void testGetPermissionSetGroupDetailNotFound() {
        Id fakeId = '0PG000000000000AAA';
        try {
            PermissionSetExplorerController.getPermissionSetGroupDetail(fakeId);
            System.assert(false, 'Should have thrown for missing permission set group');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected exception thrown');
        }
    }

    @IsTest
    static void testGetUsersByIds() {
        User u = createTestUser();

        List<Map<String, String>> results = PermissionSetExplorerController.getUsersByIds(new List<Id>{ u.Id });
        System.assertEquals(1, results.size());
        System.assertEquals(u.Id, (Id) results[0].get('id'));
    }

    @IsTest
    static void testGetUsersByIdsEmpty() {
        List<Map<String, String>> results = PermissionSetExplorerController.getUsersByIds(new List<Id>());
        System.assertEquals(0, results.size());

        List<Map<String, String>> nullResults = PermissionSetExplorerController.getUsersByIds(null);
        System.assertEquals(0, nullResults.size());
    }

    @IsTest
    static void testGetAssignedUsersEmpty() {
        PermissionSet ps = createTestPermissionSet();

        List<Map<String, String>> assigned = PermissionSetExplorerController.getAssignedUsers(ps.Id, 'PermissionSet');
        System.assertEquals(0, assigned.size(), 'Should return empty list for new permission set');
    }

    @IsTest
    static void testAssignAndUnassignPermissionSet() {
        PermissionSet ps = createTestPermissionSet();
        User u = createTestUser();

        Test.startTest();
        Map<String, Object> result = PermissionSetExplorerController.assignPermissionSet(
            ps.Id,
            'PermissionSet',
            new List<Id>{ u.Id }
        );
        Test.stopTest();

        System.assertEquals(1, (Integer) result.get('successCount'), 'Should have 1 successful assignment');

        List<Map<String, String>> assigned = PermissionSetExplorerController.getAssignedUsers(ps.Id, 'PermissionSet');
        System.assertEquals(1, assigned.size(), 'Should now have 1 assignee');
        System.assertEquals(u.Id, (Id) assigned[0].get('userId'));

        Id assignmentId = (Id) assigned[0].get('assignmentId');
        PermissionSetExplorerController.unassignPermissionSet(assignmentId);

        List<Map<String, String>> afterUnassign = PermissionSetExplorerController.getAssignedUsers(ps.Id, 'PermissionSet');
        System.assertEquals(0, afterUnassign.size(), 'Should be empty after unassign');
    }

    @IsTest
    static void testAssignAndUnassignPermissionSetGroup() {
        PermissionSet ps = createTestPermissionSet();
        PermissionSetGroup psg = createTestPermissionSetGroup(ps);
        User u = createTestUser();

        // PSG aggregation runs async; force it synchronously so the group's
        // Status becomes "Updated" before we attempt to assign a user.
        Test.calculatePermissionSetGroup(psg.Id);

        Test.startTest();
        Map<String, Object> result = PermissionSetExplorerController.assignPermissionSet(
            psg.Id,
            'PermissionSetGroup',
            new List<Id>{ u.Id }
        );
        Test.stopTest();

        List<String> errs = (List<String>) result.get('errors');
        System.assertEquals(
            1,
            (Integer) result.get('successCount'),
            'Should have 1 successful group assignment. Errors: ' + (errs == null ? '' : String.join(errs, '; '))
        );

        List<Map<String, String>> assigned = PermissionSetExplorerController.getAssignedUsers(psg.Id, 'PermissionSetGroup');
        System.assertEquals(1, assigned.size(), 'Should now have 1 group assignee');
        System.assertEquals(u.Id, (Id) assigned[0].get('userId'));

        Id assignmentId = (Id) assigned[0].get('assignmentId');
        PermissionSetExplorerController.unassignPermissionSet(assignmentId);

        List<Map<String, String>> afterUnassign = PermissionSetExplorerController.getAssignedUsers(psg.Id, 'PermissionSetGroup');
        System.assertEquals(0, afterUnassign.size(), 'Should be empty after group unassign');
    }

    @IsTest
    static void testAssignSkipsDuplicates() {
        PermissionSet ps = createTestPermissionSet();
        User u = createTestUser();

        PermissionSetExplorerController.assignPermissionSet(ps.Id, 'PermissionSet', new List<Id>{ u.Id });

        Map<String, Object> result = PermissionSetExplorerController.assignPermissionSet(
            ps.Id,
            'PermissionSet',
            new List<Id>{ u.Id }
        );

        System.assertEquals(0, (Integer) result.get('successCount'), 'No new assignments should be created');
        System.assertEquals(1, (Integer) result.get('skippedCount'), 'Existing assignment should be skipped');
    }

    @IsTest
    static void testAssignEmptyList() {
        PermissionSet ps = createTestPermissionSet();
        Map<String, Object> result = PermissionSetExplorerController.assignPermissionSet(
            ps.Id,
            'PermissionSet',
            new List<Id>()
        );
        System.assertEquals(0, (Integer) result.get('successCount'));
    }
}
