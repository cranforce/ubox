@IsTest
private class UserPermissionsPdfControllerTest {

    private static User createUserWithPerms() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String stamp = String.valueOf(Datetime.now().getTime());
        User u = new User(
            FirstName = 'PDF',
            LastName = 'Tester',
            Email = 'pdftester@example.com',
            Username = 'pdftester' + stamp + '@example.com.ubox',
            Alias = 'pdft',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert u;

        PermissionSet ps = new PermissionSet(
            Name = 'uBox_Pdf_Test_' + stamp,
            Label = 'uBox PDF Test',
            PermissionsApiEnabled = true
        );
        insert ps;
        insert new ObjectPermissions(
            ParentId = ps.Id, SobjectType = 'Account',
            PermissionsRead = true, PermissionsCreate = true, PermissionsEdit = true
        );
        insert new FieldPermissions(
            ParentId = ps.Id, SobjectType = 'Account', Field = 'Account.Fax',
            PermissionsRead = true, PermissionsEdit = true
        );
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);

        Group g = new Group(
            Name = 'uBox PDF Grp ' + stamp,
            DeveloperName = 'uBox_Pdf_Grp_' + stamp,
            Type = 'Regular'
        );
        insert g;
        insert new GroupMember(GroupId = g.Id, UserOrGroupId = u.Id);

        return u;
    }

    @IsTest
    static void testReportForUser() {
        User u = createUserWithPerms();

        Test.startTest();
        PageReference ref = Page.UserPermissionsPdf;
        ref.getParameters().put('id', u.Id);
        Test.setCurrentPage(ref);
        UserPermissionsPdfController ctrl = new UserPermissionsPdfController();
        Test.stopTest();

        System.assertEquals(true, ctrl.hasUser, 'User should be found');
        System.assertEquals('PDF Tester', ctrl.header.name, 'Header name');
        System.assertEquals('Active', ctrl.header.status, 'Header status');
        System.assertNotEquals(null, ctrl.generatedDate, 'Generated date set');

        System.assert(ctrl.getHasSources(), 'Should have permission sources');
        System.assert(ctrl.getHasObjectPermissions(), 'Should have object permissions');
        System.assert(ctrl.getHasFieldSecurity(), 'Should have field-level security');
        System.assert(ctrl.getHasPublicGroups(), 'Should list the public group');

        Boolean foundAccountObject = false;
        for (UserPermissionsPdfController.ObjectRow o : ctrl.objectPermissions) {
            if (o.apiName == 'Account') {
                foundAccountObject = true;
                System.assertEquals('Yes', o.read, 'Account read should be marked');
            }
        }
        System.assert(foundAccountObject, 'Account object permission expected');

        Boolean foundAccountFls = false;
        for (UserPermissionsPdfController.FlsObject fo : ctrl.fieldSecurity) {
            if (fo.apiName == 'Account') {
                foundAccountFls = true;
                System.assert(!fo.fields.isEmpty(), 'Account FLS fields expected');
            }
        }
        System.assert(foundAccountFls, 'Account field-level security expected');
    }

    @IsTest
    static void testNoIdParam() {
        Test.setCurrentPage(Page.UserPermissionsPdf);
        UserPermissionsPdfController ctrl = new UserPermissionsPdfController();

        System.assertEquals(false, ctrl.hasUser, 'No id should not resolve a user');
        System.assert(!ctrl.getHasObjectPermissions(), 'No sections without a user');
        System.assertNotEquals(null, ctrl.generatedDate, 'Generated date still set');
    }

    @IsTest
    static void testInvalidId() {
        PageReference ref = Page.UserPermissionsPdf;
        ref.getParameters().put('id', 'not-an-id');
        Test.setCurrentPage(ref);
        UserPermissionsPdfController ctrl = new UserPermissionsPdfController();

        System.assertEquals(false, ctrl.hasUser, 'Malformed id should not resolve a user');
    }

    @IsTest
    static void testNonUserId() {
        PermissionSet ps = new PermissionSet(
            Name = 'uBox_Pdf_NonUser_' + String.valueOf(Datetime.now().getTime()),
            Label = 'uBox PDF NonUser'
        );
        insert ps;

        PageReference ref = Page.UserPermissionsPdf;
        ref.getParameters().put('id', ps.Id);
        Test.setCurrentPage(ref);
        UserPermissionsPdfController ctrl = new UserPermissionsPdfController();

        System.assertEquals(false, ctrl.hasUser, 'A non-User id should not resolve a user');
    }
}
