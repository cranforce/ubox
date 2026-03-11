@IsTest
private class UserManagementControllerTest {

    @IsTest
    static void testGetUserFormMetadata() {
        Map<String, Object> metadata = UserManagementController.getUserFormMetadata();

        System.assertNotEquals(null, metadata.get('profileOptions'), 'Should return profile options');
        System.assertNotEquals(null, metadata.get('roleOptions'), 'Should return role options');
        System.assertNotEquals(null, metadata.get('timezoneOptions'), 'Should return timezone options');
        System.assertNotEquals(null, metadata.get('localeOptions'), 'Should return locale options');
        System.assertNotEquals(null, metadata.get('emailEncodingOptions'), 'Should return email encoding options');
        System.assertNotEquals(null, metadata.get('languageOptions'), 'Should return language options');

        List<Map<String, String>> profiles = (List<Map<String, String>>) metadata.get('profileOptions');
        System.assert(!profiles.isEmpty(), 'Should have at least one profile');
    }

    @IsTest
    static void testGetAvailablePermissionSets() {
        List<Map<String, String>> permSets = UserManagementController.getAvailablePermissionSets();
        System.assertNotEquals(null, permSets, 'Should return permission set list');
    }

    @IsTest
    static void testGetAvailablePermissionSetGroups() {
        List<Map<String, String>> groups = UserManagementController.getAvailablePermissionSetGroups();
        System.assertNotEquals(null, groups, 'Should return permission set groups list');
    }

    @IsTest
    static void testGetAvailablePublicGroups() {
        List<Map<String, String>> groups = UserManagementController.getAvailablePublicGroups();
        System.assertNotEquals(null, groups, 'Should return public groups list');
    }

    @IsTest
    static void testGetAvailablePackageLicenses() {
        List<Map<String, String>> licenses = UserManagementController.getAvailablePackageLicenses();
        System.assertNotEquals(null, licenses, 'Should return package licenses list');
    }

    @IsTest
    static void testGetCloneSourceData() {
        User currentUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Map<String, Object> cloneData = UserManagementController.getCloneSourceData(currentUser.Id);

        System.assertNotEquals(null, cloneData.get('user'), 'Should return user data');
        System.assertNotEquals(null, cloneData.get('permissionSetIds'), 'Should return permission set IDs');
        System.assertNotEquals(null, cloneData.get('groupIds'), 'Should return group IDs');
        System.assertNotEquals(null, cloneData.get('packageLicenseIds'), 'Should return package license IDs');
        System.assertNotEquals(null, cloneData.get('permSetGroupIds'), 'Should return permission set group IDs');

        Map<String, Object> userData = (Map<String, Object>) cloneData.get('user');
        System.assertEquals('', userData.get('Email'), 'Email should be blanked for clone');
        System.assertEquals('', userData.get('Username'), 'Username should be blanked for clone');
        System.assertEquals('', userData.get('Alias'), 'Alias should be blanked for clone');
    }

    @IsTest
    static void testCreateUser() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        Map<String, Object> userData = new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => 'UserCreate',
            'Email' => 'testuboxcreate@example.com',
            'Username' => 'testuboxcreate' + Datetime.now().getTime() + '@example.com',
            'Alias' => 'tcreate',
            'ProfileId' => stdProfile.Id,
            'TimeZoneSidKey' => 'America/Los_Angeles',
            'LocaleSidKey' => 'en_US',
            'EmailEncodingKey' => 'UTF-8',
            'LanguageLocaleKey' => 'en_US',
            'IsActive' => true
        };

        Test.startTest();
        Id userId = UserManagementController.createUser(
            userData,
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>()
        );
        Test.stopTest();

        System.assertNotEquals(null, userId, 'Should return created user Id');
        User created = [SELECT LastName, Email FROM User WHERE Id = :userId];
        System.assertEquals('UserCreate', created.LastName);
    }

    @IsTest
    static void testGetEditUserData() {
        User currentUser = [SELECT Id, Email, Username, Alias FROM User WHERE Id = :UserInfo.getUserId()];

        Map<String, Object> editData = UserManagementController.getEditUserData(currentUser.Id);

        System.assertNotEquals(null, editData.get('user'), 'Should return user data');
        System.assertNotEquals(null, editData.get('permissionSetIds'), 'Should return permission set IDs');
        System.assertNotEquals(null, editData.get('groupIds'), 'Should return group IDs');
        System.assertNotEquals(null, editData.get('packageLicenseIds'), 'Should return package license IDs');
        System.assertNotEquals(null, editData.get('permSetGroupIds'), 'Should return permission set group IDs');
        System.assertNotEquals(null, editData.get('permSetLicenseIds'), 'Should return permission set license IDs');

        Map<String, Object> userData = (Map<String, Object>) editData.get('user');
        System.assertEquals(currentUser.Email, userData.get('Email'), 'Email should be preserved for edit');
        System.assertEquals(currentUser.Username, userData.get('Username'), 'Username should be preserved for edit');
        System.assertEquals(currentUser.Alias, userData.get('Alias'), 'Alias should be preserved for edit');
    }

    @IsTest
    static void testUpdateUser() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        // Create a user to edit
        User testUser = new User(
            FirstName = 'Edit',
            LastName = 'TestUser',
            Email = 'edituboxtest@example.com',
            Username = 'edituboxtest' + Datetime.now().getTime() + '@example.com',
            Alias = 'etest',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert testUser;

        Map<String, Object> userData = new Map<String, Object>{
            'FirstName' => 'EditUpdated',
            'LastName' => 'TestUserUpdated',
            'Email' => testUser.Email,
            'Username' => testUser.Username,
            'Alias' => testUser.Alias,
            'ProfileId' => stdProfile.Id,
            'TimeZoneSidKey' => 'America/Los_Angeles',
            'LocaleSidKey' => 'en_US',
            'EmailEncodingKey' => 'UTF-8',
            'LanguageLocaleKey' => 'en_US',
            'IsActive' => true
        };

        Test.startTest();
        UserManagementController.updateUser(
            testUser.Id,
            userData,
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>(),
            new List<Id>()
        );
        Test.stopTest();

        User updated = [SELECT FirstName, LastName FROM User WHERE Id = :testUser.Id];
        System.assertEquals('EditUpdated', updated.FirstName, 'FirstName should be updated');
        System.assertEquals('TestUserUpdated', updated.LastName, 'LastName should be updated');
    }

    @IsTest
    static void testUpdateUserValidationFailure() {
        Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User testUser = new User(
            FirstName = 'Val',
            LastName = 'TestUser',
            Email = 'valuboxtest@example.com',
            Username = 'valuboxtest' + Datetime.now().getTime() + '@example.com',
            Alias = 'vtest',
            ProfileId = stdProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert testUser;

        Map<String, Object> userData = new Map<String, Object>{
            'FirstName' => 'Val',
            'LastName' => '',
            'Email' => '',
            'Username' => '',
            'Alias' => '',
            'ProfileId' => null,
            'TimeZoneSidKey' => '',
            'LocaleSidKey' => '',
            'EmailEncodingKey' => '',
            'LanguageLocaleKey' => ''
        };

        try {
            UserManagementController.updateUser(
                testUser.Id,
                userData,
                new List<Id>(),
                new List<Id>(),
                new List<Id>(),
                new List<Id>(),
                new List<Id>()
            );
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Missing required fields'), 'Should list missing fields');
        }
    }

    @IsTest
    static void testCreateUserValidationFailure() {
        Map<String, Object> userData = new Map<String, Object>{
            'FirstName' => 'Test',
            'LastName' => '',
            'Email' => '',
            'Username' => '',
            'Alias' => '',
            'ProfileId' => null,
            'TimeZoneSidKey' => '',
            'LocaleSidKey' => '',
            'EmailEncodingKey' => '',
            'LanguageLocaleKey' => ''
        };

        try {
            UserManagementController.createUser(
                userData,
                new List<Id>(),
                new List<Id>(),
                new List<Id>(),
                new List<Id>(),
                new List<Id>()
            );
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Missing required fields'), 'Should list missing fields');
        }
    }
}
