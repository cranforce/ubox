@IsTest
private class PermissionComparisonControllerTest {

    private static Integer seq = 0;
    private static String uniq() {
        seq++;
        return String.valueOf(Datetime.now().getTime()) + '_' + seq;
    }

    private static User makeUser(String lastName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String u = uniq();
        User usr = new User(
            FirstName = 'Cmp',
            LastName = lastName,
            Email = 'cmp@example.com',
            Username = 'cmp' + u + '@example.com.ubox',
            Alias = lastName.left(8),
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert usr;
        return usr;
    }

    private static PermissionSet makePermSet(String devBase, String label, Boolean apiEnabled) {
        PermissionSet ps = new PermissionSet(
            Name = devBase + '_' + uniq(),
            Label = label,
            PermissionsApiEnabled = apiEnabled
        );
        insert ps;
        return ps;
    }

    private static void addFieldPerm(Id psId, String obj, String field, Boolean edit) {
        insert new FieldPermissions(
            ParentId = psId, SobjectType = obj, Field = field,
            PermissionsRead = true, PermissionsEdit = edit
        );
    }

    private static Group makeGroup(String label) {
        Group g = new Group(
            Name = label,
            DeveloperName = 'Cmp_Grp_' + uniq(),
            Type = 'Regular'
        );
        insert g;
        return g;
    }

    private static Boolean hasApiName(List<Object> entries, String apiName) {
        for (Object o : entries) {
            if (apiName == (String) ((Map<String, Object>) o).get('apiName')) return true;
        }
        return false;
    }

    @IsTest
    static void testComparison() {
        User a = makeUser('Alpha');
        User b = makeUser('Beta');

        // User A: full Account access incl. View All / Modify All (the shared
        // Standard User profile grants R/C/E/D but NOT View/Modify All, so those
        // flags are the deterministic difference), plus Fax edit.
        PermissionSet psA = makePermSet('Cmp_PS_A', 'Cmp PS A', true);
        insert new ObjectPermissions(
            ParentId = psA.Id, SobjectType = 'Account',
            PermissionsRead = true, PermissionsCreate = true, PermissionsEdit = true,
            PermissionsDelete = true, PermissionsViewAllRecords = true,
            PermissionsModifyAllRecords = true
        );
        addFieldPerm(psA.Id, 'Account', 'Account.Fax', true);
        insert new PermissionSetAssignment(AssigneeId = a.Id, PermissionSetId = psA.Id);

        // User B: only baseline Account read via its permission set.
        PermissionSet psB = makePermSet('Cmp_PS_B', 'Cmp PS B', false);
        insert new ObjectPermissions(
            ParentId = psB.Id, SobjectType = 'Account', PermissionsRead = true
        );
        addFieldPerm(psB.Id, 'Account', 'Account.Fax', false);
        insert new PermissionSetAssignment(AssigneeId = b.Id, PermissionSetId = psB.Id);

        insert new GroupMember(GroupId = makeGroup('Cmp Grp A').Id, UserOrGroupId = a.Id);
        insert new GroupMember(GroupId = makeGroup('Cmp Grp B').Id, UserOrGroupId = b.Id);

        Test.startTest();
        Map<String, Object> r = PermissionComparisonController.getComparison(a.Id, b.Id);
        Test.stopTest();

        System.assertEquals(true, r.get('hasDifferences'), 'Should report differences');

        // Mechanisms: each user has a distinct permission set and public group.
        Map<String, Object> mech = (Map<String, Object>) r.get('mechanisms');
        Map<String, Object> psDiff = (Map<String, Object>) mech.get('permissionSets');
        System.assert(!((List<Object>) psDiff.get('onlyA')).isEmpty(), 'Permission set only in A');
        System.assert(!((List<Object>) psDiff.get('onlyB')).isEmpty(), 'Permission set only in B');
        Map<String, Object> grpDiff = (Map<String, Object>) mech.get('publicGroups');
        System.assert(!((List<Object>) grpDiff.get('onlyA')).isEmpty(), 'Group only in A');
        System.assert(!((List<Object>) grpDiff.get('onlyB')).isEmpty(), 'Group only in B');

        // Object permissions: Account is present for both (via profile) but the
        // View/Modify All flags diverge, so it lands in `different`.
        Map<String, Object> objDiff = (Map<String, Object>) r.get('objectPermissions');
        System.assert(
            hasApiName((List<Object>) objDiff.get('different'), 'Account'),
            'Account should differ (View/Modify All)'
        );

        // FLS diff path executed; structure present.
        Map<String, Object> fls = (Map<String, Object>) r.get('fieldSecurity');
        System.assertNotEquals(null, fls.get('onlyA'), 'FLS onlyA list present');
        System.assertNotEquals(null, fls.get('different'), 'FLS different list present');

        System.assertNotEquals(null, r.get('systemPermissions'), 'System perms diff present');
        System.assertNotEquals(null, r.get('appAccesses'), 'App access diff present');
        System.assertNotEquals(null, r.get('customPermissions'), 'Custom perm diff present');
    }

    @IsTest
    static void testGuards() {
        User a = makeUser('Solo');

        // Missing id
        try {
            PermissionComparisonController.getComparison(null, a.Id);
            System.assert(false, 'Null id should throw');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected exception');
        }

        // Identical users
        try {
            PermissionComparisonController.getComparison(a.Id, a.Id);
            System.assert(false, 'Identical users should throw');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected exception');
        }

        // Non-user id
        PermissionSet ps = makePermSet('Cmp_Guard', 'Cmp Guard', false);
        try {
            PermissionComparisonController.getComparison(a.Id, ps.Id);
            System.assert(false, 'Non-user id should throw');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected exception');
        }

        // Well-formed but non-existent user id
        Id missing = '005000000000000';
        try {
            PermissionComparisonController.getComparison(a.Id, missing);
            System.assert(false, 'Missing user should throw');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected exception');
        }
    }
}
