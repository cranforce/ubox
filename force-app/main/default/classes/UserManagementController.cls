public with sharing class UserManagementController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUserFormMetadata() {
        Map<String, Object> metadata = new Map<String, Object>();

        List<Map<String, String>> userLicenseOptions = new List<Map<String, String>>();
        for (UserLicense ul : [SELECT Id, Name FROM UserLicense WHERE Status = 'Active' ORDER BY Name]) {
            userLicenseOptions.add(new Map<String, String>{ 'value' => ul.Id, 'label' => ul.Name });
        }
        metadata.put('userLicenseOptions', userLicenseOptions);

        List<Map<String, String>> profileOptions = new List<Map<String, String>>();
        for (Profile p : [SELECT Id, Name, UserLicenseId FROM Profile ORDER BY Name]) {
            profileOptions.add(new Map<String, String>{
                'value' => p.Id,
                'label' => p.Name,
                'userLicenseId' => p.UserLicenseId
            });
        }
        metadata.put('profileOptions', profileOptions);

        List<Map<String, String>> roleOptions = new List<Map<String, String>>();
        roleOptions.add(new Map<String, String>{ 'value' => '', 'label' => '-- None --' });
        for (UserRole r : [SELECT Id, Name FROM UserRole ORDER BY Name]) {
            roleOptions.add(new Map<String, String>{ 'value' => r.Id, 'label' => r.Name });
        }
        metadata.put('roleOptions', roleOptions);

        Schema.DescribeFieldResult tzField = User.TimeZoneSidKey.getDescribe();
        List<Map<String, String>> tzOptions = new List<Map<String, String>>();
        for (Schema.PicklistEntry pe : tzField.getPicklistValues()) {
            if (pe.isActive()) {
                tzOptions.add(new Map<String, String>{ 'value' => pe.getValue(), 'label' => pe.getLabel() });
            }
        }
        metadata.put('timezoneOptions', tzOptions);

        Schema.DescribeFieldResult localeField = User.LocaleSidKey.getDescribe();
        List<Map<String, String>> localeOptions = new List<Map<String, String>>();
        for (Schema.PicklistEntry pe : localeField.getPicklistValues()) {
            if (pe.isActive()) {
                localeOptions.add(new Map<String, String>{ 'value' => pe.getValue(), 'label' => pe.getLabel() });
            }
        }
        metadata.put('localeOptions', localeOptions);

        Schema.DescribeFieldResult encodingField = User.EmailEncodingKey.getDescribe();
        List<Map<String, String>> encodingOptions = new List<Map<String, String>>();
        for (Schema.PicklistEntry pe : encodingField.getPicklistValues()) {
            if (pe.isActive()) {
                encodingOptions.add(new Map<String, String>{ 'value' => pe.getValue(), 'label' => pe.getLabel() });
            }
        }
        metadata.put('emailEncodingOptions', encodingOptions);

        Schema.DescribeFieldResult langField = User.LanguageLocaleKey.getDescribe();
        List<Map<String, String>> langOptions = new List<Map<String, String>>();
        for (Schema.PicklistEntry pe : langField.getPicklistValues()) {
            if (pe.isActive()) {
                langOptions.add(new Map<String, String>{ 'value' => pe.getValue(), 'label' => pe.getLabel() });
            }
        }
        metadata.put('languageOptions', langOptions);

        return metadata;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailablePermissionSets() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (PermissionSet ps : [
            SELECT Id, Label
            FROM PermissionSet
            WHERE IsOwnedByProfile = false
              AND PermissionSetGroupId = null
            ORDER BY Label
        ]) {
            options.add(new Map<String, String>{ 'value' => ps.Id, 'label' => ps.Label });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailablePublicGroups() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Group g : [
            SELECT Id, Name
            FROM Group
            WHERE Type = 'Regular'
            ORDER BY Name
        ]) {
            options.add(new Map<String, String>{ 'value' => g.Id, 'label' => g.Name });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailablePermissionSetGroups() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (PermissionSetGroup psg : [
            SELECT Id, MasterLabel
            FROM PermissionSetGroup
            WHERE Status = 'Updated'
            ORDER BY MasterLabel
        ]) {
            options.add(new Map<String, String>{ 'value' => psg.Id, 'label' => psg.MasterLabel });
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailablePermissionSetLicenses() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (PermissionSetLicense psl : [
            SELECT Id, MasterLabel, TotalLicenses, UsedLicenses
            FROM PermissionSetLicense
            WHERE Status = 'Active'
            ORDER BY MasterLabel
        ]) {
            Integer remaining = psl.TotalLicenses == -1 ? -1 : psl.TotalLicenses - psl.UsedLicenses;
            if (remaining == -1 || remaining > 0) {
                String label = remaining == -1
                    ? psl.MasterLabel + ' (Unlimited)'
                    : psl.MasterLabel + ' (' + remaining + ' available)';
                options.add(new Map<String, String>{ 'value' => psl.Id, 'label' => label });
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailablePackageLicenses() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        for (PackageLicense pl : [
            SELECT Id, NamespacePrefix, AllowedLicenses, UsedLicenses
            FROM PackageLicense
            ORDER BY NamespacePrefix
        ]) {
            Integer remaining = pl.AllowedLicenses - pl.UsedLicenses;
            String label = pl.NamespacePrefix + ' (' + remaining + ' available)';
            if (remaining > 0) {
                options.add(new Map<String, String>{ 'value' => pl.Id, 'label' => label });
            }
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getAllUsers() {
        List<Map<String, Object>> users = new List<Map<String, Object>>();
        for (User u : [
            SELECT Id, Name, FirstName, LastName, Username, Email, Title,
                   IsActive, Profile.Name
            FROM User
            WHERE UserType = 'Standard'
            ORDER BY Name
            LIMIT 500
        ]) {
            users.add(new Map<String, Object>{
                'id' => u.Id,
                'name' => u.Name,
                'username' => u.Username,
                'email' => u.Email,
                'title' => u.Title,
                'isActive' => u.IsActive,
                'profileName' => u.Profile != null ? u.Profile.Name : null
            });
        }
        return users;
    }

    @AuraEnabled
    public static Map<String, Object> getCloneSourceData(Id sourceUserId) {
        User sourceUser = [
            SELECT FirstName, LastName, Email, Username, Alias,
                   ProfileId, Profile.UserLicenseId, UserRoleId,
                   TimeZoneSidKey, LocaleSidKey,
                   EmailEncodingKey, LanguageLocaleKey, IsActive,
                   Department, Title, CompanyName,
                   UserPermissionsMarketingUser, UserPermissionsKnowledgeUser,
                   UserPermissionsInteractionUser, UserPermissionsSupportUser,
                   UserPermissionsSFContentUser
            FROM User
            WHERE Id = :sourceUserId
            LIMIT 1
        ];

        Map<String, Object> userData = new Map<String, Object>();
        userData.put('FirstName', sourceUser.FirstName);
        userData.put('LastName', sourceUser.LastName);
        userData.put('ProfileId', sourceUser.ProfileId);
        userData.put('UserRoleId', sourceUser.UserRoleId);
        userData.put('TimeZoneSidKey', sourceUser.TimeZoneSidKey);
        userData.put('LocaleSidKey', sourceUser.LocaleSidKey);
        userData.put('EmailEncodingKey', sourceUser.EmailEncodingKey);
        userData.put('LanguageLocaleKey', sourceUser.LanguageLocaleKey);
        userData.put('IsActive', sourceUser.IsActive);
        userData.put('Department', sourceUser.Department);
        userData.put('Title', sourceUser.Title);
        userData.put('CompanyName', sourceUser.CompanyName);
        userData.put('UserLicenseId', sourceUser.Profile.UserLicenseId);
        userData.put('UserPermissionsMarketingUser', sourceUser.UserPermissionsMarketingUser);
        userData.put('UserPermissionsKnowledgeUser', sourceUser.UserPermissionsKnowledgeUser);
        userData.put('UserPermissionsInteractionUser', sourceUser.UserPermissionsInteractionUser);
        userData.put('UserPermissionsSupportUser', sourceUser.UserPermissionsSupportUser);

        userData.put('UserPermissionsSFContentUser', sourceUser.UserPermissionsSFContentUser);
        // Blank out unique fields so the admin must fill them in
        userData.put('Email', '');
        userData.put('Username', '');
        userData.put('Alias', '');

        List<Id> permissionSetIds = new List<Id>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :sourceUserId
              AND PermissionSet.IsOwnedByProfile = false
        ]) {
            permissionSetIds.add(psa.PermissionSetId);
        }

        List<Id> groupIds = new List<Id>();
        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :sourceUserId
              AND Group.Type = 'Regular'
        ]) {
            groupIds.add(gm.GroupId);
        }

        List<Id> packageLicenseIds = new List<Id>();
        for (UserPackageLicense upl : [
            SELECT PackageLicenseId
            FROM UserPackageLicense
            WHERE UserId = :sourceUserId
        ]) {
            packageLicenseIds.add(upl.PackageLicenseId);
        }

        List<Id> permSetLicenseIds = new List<Id>();
        for (PermissionSetLicenseAssign psla : [
            SELECT PermissionSetLicenseId
            FROM PermissionSetLicenseAssign
            WHERE AssigneeId = :sourceUserId
        ]) {
            permSetLicenseIds.add(psla.PermissionSetLicenseId);
        }

        List<Id> permSetGroupIds = new List<Id>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetGroupId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :sourceUserId
              AND PermissionSetGroupId != null
        ]) {
            permSetGroupIds.add(psa.PermissionSetGroupId);
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('user', userData);
        result.put('permissionSetIds', permissionSetIds);
        result.put('groupIds', groupIds);
        result.put('packageLicenseIds', packageLicenseIds);
        result.put('permSetLicenseIds', permSetLicenseIds);
        result.put('permSetGroupIds', permSetGroupIds);
        return result;
    }

    @AuraEnabled
    public static Id createUser(
        Map<String, Object> userData,
        List<Id> permissionSetIds,
        List<Id> groupIds,
        List<Id> packageLicenseIds,
        List<Id> permSetLicenseIds,
        List<Id> permSetGroupIds
    ) {
        User newUser = new User();
        newUser.FirstName = (String) userData.get('FirstName');
        newUser.LastName = (String) userData.get('LastName');
        newUser.Email = (String) userData.get('Email');
        newUser.Username = (String) userData.get('Username');
        newUser.Alias = (String) userData.get('Alias');
        newUser.ProfileId = (Id) userData.get('ProfileId');
        newUser.TimeZoneSidKey = (String) userData.get('TimeZoneSidKey');
        newUser.LocaleSidKey = (String) userData.get('LocaleSidKey');
        newUser.EmailEncodingKey = (String) userData.get('EmailEncodingKey');
        newUser.LanguageLocaleKey = (String) userData.get('LanguageLocaleKey');
        newUser.IsActive = userData.get('IsActive') == true;

        if (userData.containsKey('UserRoleId') && userData.get('UserRoleId') != null && String.isNotBlank((String) userData.get('UserRoleId'))) {
            newUser.UserRoleId = (Id) userData.get('UserRoleId');
        }
        if (userData.containsKey('Department')) {
            newUser.Department = (String) userData.get('Department');
        }
        if (userData.containsKey('Title')) {
            newUser.Title = (String) userData.get('Title');
        }
        if (userData.containsKey('CompanyName')) {
            newUser.CompanyName = (String) userData.get('CompanyName');
        }

        newUser.UserPermissionsMarketingUser = userData.get('UserPermissionsMarketingUser') == true;
        newUser.UserPermissionsKnowledgeUser = userData.get('UserPermissionsKnowledgeUser') == true;
        newUser.UserPermissionsInteractionUser = userData.get('UserPermissionsInteractionUser') == true;
        newUser.UserPermissionsSupportUser = userData.get('UserPermissionsSupportUser') == true;

        newUser.UserPermissionsSFContentUser = userData.get('UserPermissionsSFContentUser') == true;

        validateRequiredFields(newUser);

        try {
            insert newUser;
        } catch (DmlException e) {
            uBoxLogService.createLogAsync('Create User', null, UserInfo.getUserId(), 'Error', e.getDmlMessage(0), false);
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        Integer assignmentCount =
            (permissionSetIds != null ? permissionSetIds.size() : 0) +
            (groupIds != null ? groupIds.size() : 0) +
            (packageLicenseIds != null ? packageLicenseIds.size() : 0) +
            (permSetLicenseIds != null ? permSetLicenseIds.size() : 0) +
            (permSetGroupIds != null ? permSetGroupIds.size() : 0);

        String detailJson = JSON.serialize(new Map<String, Object>{
            'user' => newUser.LastName + ', ' + newUser.FirstName,
            'permissionSets' => permissionSetIds != null ? permissionSetIds.size() : 0,
            'groups' => groupIds != null ? groupIds.size() : 0,
            'packageLicenses' => packageLicenseIds != null ? packageLicenseIds.size() : 0,
            'permSetLicenses' => permSetLicenseIds != null ? permSetLicenseIds.size() : 0,
            'permSetGroups' => permSetGroupIds != null ? permSetGroupIds.size() : 0
        });
        uBoxLogService.createLogAsync('Create User', newUser.Id, UserInfo.getUserId(), 'Success', detailJson, false);

        Boolean hasAssignments = assignmentCount > 0;

        if (hasAssignments) {
            System.enqueueJob(new UserAssignmentQueueable(
                newUser.Id,
                permissionSetIds != null ? permissionSetIds : new List<Id>(),
                groupIds != null ? groupIds : new List<Id>(),
                packageLicenseIds != null ? packageLicenseIds : new List<Id>(),
                permSetLicenseIds != null ? permSetLicenseIds : new List<Id>(),
                permSetGroupIds != null ? permSetGroupIds : new List<Id>(),
                UserInfo.getUserId()
            ));
        }

        return newUser.Id;
    }

    @AuraEnabled
    public static Map<String, Object> getEditUserData(Id userId) {
        User sourceUser = [
            SELECT FirstName, LastName, Email, Username, Alias,
                   ProfileId, Profile.UserLicenseId, UserRoleId,
                   TimeZoneSidKey, LocaleSidKey,
                   EmailEncodingKey, LanguageLocaleKey, IsActive,
                   Department, Title, CompanyName,
                   UserPermissionsMarketingUser, UserPermissionsKnowledgeUser,
                   UserPermissionsInteractionUser, UserPermissionsSupportUser,
                   UserPermissionsSFContentUser
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        Map<String, Object> userData = new Map<String, Object>();
        userData.put('FirstName', sourceUser.FirstName);
        userData.put('LastName', sourceUser.LastName);
        userData.put('Email', sourceUser.Email);
        userData.put('Username', sourceUser.Username);
        userData.put('Alias', sourceUser.Alias);
        userData.put('ProfileId', sourceUser.ProfileId);
        userData.put('UserRoleId', sourceUser.UserRoleId);
        userData.put('TimeZoneSidKey', sourceUser.TimeZoneSidKey);
        userData.put('LocaleSidKey', sourceUser.LocaleSidKey);
        userData.put('EmailEncodingKey', sourceUser.EmailEncodingKey);
        userData.put('LanguageLocaleKey', sourceUser.LanguageLocaleKey);
        userData.put('IsActive', sourceUser.IsActive);
        userData.put('Department', sourceUser.Department);
        userData.put('Title', sourceUser.Title);
        userData.put('CompanyName', sourceUser.CompanyName);
        userData.put('UserLicenseId', sourceUser.Profile.UserLicenseId);
        userData.put('UserPermissionsMarketingUser', sourceUser.UserPermissionsMarketingUser);
        userData.put('UserPermissionsKnowledgeUser', sourceUser.UserPermissionsKnowledgeUser);
        userData.put('UserPermissionsInteractionUser', sourceUser.UserPermissionsInteractionUser);
        userData.put('UserPermissionsSupportUser', sourceUser.UserPermissionsSupportUser);
        userData.put('UserPermissionsSFContentUser', sourceUser.UserPermissionsSFContentUser);

        List<Id> permissionSetIds = new List<Id>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
              AND PermissionSet.IsOwnedByProfile = false
              AND PermissionSetGroupId = null
        ]) {
            permissionSetIds.add(psa.PermissionSetId);
        }

        List<Id> permSetGroupIds = new List<Id>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetGroupId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
              AND PermissionSetGroupId != null
        ]) {
            permSetGroupIds.add(psa.PermissionSetGroupId);
        }

        List<Id> permSetLicenseIds = new List<Id>();
        for (PermissionSetLicenseAssign psla : [
            SELECT PermissionSetLicenseId
            FROM PermissionSetLicenseAssign
            WHERE AssigneeId = :userId
        ]) {
            permSetLicenseIds.add(psla.PermissionSetLicenseId);
        }

        List<Id> groupIds = new List<Id>();
        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :userId
              AND Group.Type = 'Regular'
        ]) {
            groupIds.add(gm.GroupId);
        }

        List<Id> packageLicenseIds = new List<Id>();
        for (UserPackageLicense upl : [
            SELECT PackageLicenseId
            FROM UserPackageLicense
            WHERE UserId = :userId
        ]) {
            packageLicenseIds.add(upl.PackageLicenseId);
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('user', userData);
        result.put('permissionSetIds', permissionSetIds);
        result.put('permSetGroupIds', permSetGroupIds);
        result.put('permSetLicenseIds', permSetLicenseIds);
        result.put('groupIds', groupIds);
        result.put('packageLicenseIds', packageLicenseIds);
        return result;
    }

    @AuraEnabled
    public static void updateUser(
        Id userId,
        Map<String, Object> userData,
        List<Id> permissionSetIds,
        List<Id> permSetGroupIds,
        List<Id> permSetLicenseIds,
        List<Id> groupIds,
        List<Id> packageLicenseIds
    ) {
        User existingUser = [SELECT Id FROM User WHERE Id = :userId LIMIT 1];

        existingUser.FirstName = (String) userData.get('FirstName');
        existingUser.LastName = (String) userData.get('LastName');
        existingUser.Email = (String) userData.get('Email');
        existingUser.Username = (String) userData.get('Username');
        existingUser.Alias = (String) userData.get('Alias');
        existingUser.ProfileId = (Id) userData.get('ProfileId');
        existingUser.TimeZoneSidKey = (String) userData.get('TimeZoneSidKey');
        existingUser.LocaleSidKey = (String) userData.get('LocaleSidKey');
        existingUser.EmailEncodingKey = (String) userData.get('EmailEncodingKey');
        existingUser.LanguageLocaleKey = (String) userData.get('LanguageLocaleKey');
        existingUser.IsActive = userData.get('IsActive') == true;

        if (userData.containsKey('UserRoleId') && userData.get('UserRoleId') != null && String.isNotBlank((String) userData.get('UserRoleId'))) {
            existingUser.UserRoleId = (Id) userData.get('UserRoleId');
        } else {
            existingUser.UserRoleId = null;
        }
        if (userData.containsKey('Department')) {
            existingUser.Department = (String) userData.get('Department');
        }
        if (userData.containsKey('Title')) {
            existingUser.Title = (String) userData.get('Title');
        }
        if (userData.containsKey('CompanyName')) {
            existingUser.CompanyName = (String) userData.get('CompanyName');
        }

        existingUser.UserPermissionsMarketingUser = userData.get('UserPermissionsMarketingUser') == true;
        existingUser.UserPermissionsKnowledgeUser = userData.get('UserPermissionsKnowledgeUser') == true;
        existingUser.UserPermissionsInteractionUser = userData.get('UserPermissionsInteractionUser') == true;
        existingUser.UserPermissionsSupportUser = userData.get('UserPermissionsSupportUser') == true;
        existingUser.UserPermissionsSFContentUser = userData.get('UserPermissionsSFContentUser') == true;

        validateRequiredFields(existingUser);

        try {
            update existingUser;
        } catch (DmlException e) {
            uBoxLogService.createLogAsync('Edit User', userId, UserInfo.getUserId(), 'Error', e.getDmlMessage(0), false);
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        String editDetailJson = JSON.serialize(new Map<String, Object>{
            'user' => existingUser.LastName + ', ' + existingUser.FirstName,
            'permissionSets' => permissionSetIds != null ? permissionSetIds.size() : 0,
            'permSetGroups' => permSetGroupIds != null ? permSetGroupIds.size() : 0,
            'permSetLicenses' => permSetLicenseIds != null ? permSetLicenseIds.size() : 0,
            'groups' => groupIds != null ? groupIds.size() : 0,
            'packageLicenses' => packageLicenseIds != null ? packageLicenseIds.size() : 0
        });
        uBoxLogService.createLogAsync('Edit User', userId, UserInfo.getUserId(), 'Success', editDetailJson, false);

        // Compute diffs for assignments
        if (permissionSetIds == null) permissionSetIds = new List<Id>();
        if (permSetGroupIds == null) permSetGroupIds = new List<Id>();
        if (permSetLicenseIds == null) permSetLicenseIds = new List<Id>();
        if (groupIds == null) groupIds = new List<Id>();
        if (packageLicenseIds == null) packageLicenseIds = new List<Id>();

        Set<Id> desiredPermSets = new Set<Id>(permissionSetIds);
        Set<Id> desiredPermSetGroups = new Set<Id>(permSetGroupIds);
        Set<Id> desiredPermSetLicenses = new Set<Id>(permSetLicenseIds);
        Set<Id> desiredGroups = new Set<Id>(groupIds);
        Set<Id> desiredPackageLicenses = new Set<Id>(packageLicenseIds);

        // Current assignments
        Set<Id> currentPermSets = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetId FROM PermissionSetAssignment
            WHERE AssigneeId = :userId AND PermissionSet.IsOwnedByProfile = false AND PermissionSetGroupId = null
        ]) {
            currentPermSets.add(psa.PermissionSetId);
        }

        Set<Id> currentPermSetGroups = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetGroupId FROM PermissionSetAssignment
            WHERE AssigneeId = :userId AND PermissionSetGroupId != null
        ]) {
            currentPermSetGroups.add(psa.PermissionSetGroupId);
        }

        Set<Id> currentPermSetLicenses = new Set<Id>();
        for (PermissionSetLicenseAssign psla : [
            SELECT PermissionSetLicenseId FROM PermissionSetLicenseAssign
            WHERE AssigneeId = :userId
        ]) {
            currentPermSetLicenses.add(psla.PermissionSetLicenseId);
        }

        Set<Id> currentGroups = new Set<Id>();
        for (GroupMember gm : [
            SELECT GroupId FROM GroupMember
            WHERE UserOrGroupId = :userId AND Group.Type = 'Regular'
        ]) {
            currentGroups.add(gm.GroupId);
        }

        Set<Id> currentPackageLicenses = new Set<Id>();
        for (UserPackageLicense upl : [
            SELECT PackageLicenseId FROM UserPackageLicense WHERE UserId = :userId
        ]) {
            currentPackageLicenses.add(upl.PackageLicenseId);
        }

        // Compute adds and removes
        List<Id> permSetsToAdd = new List<Id>();
        List<Id> permSetsToRemove = new List<Id>();
        for (Id psId : desiredPermSets) {
            if (!currentPermSets.contains(psId)) permSetsToAdd.add(psId);
        }
        for (Id psId : currentPermSets) {
            if (!desiredPermSets.contains(psId)) permSetsToRemove.add(psId);
        }

        List<Id> permSetGroupsToAdd = new List<Id>();
        List<Id> permSetGroupsToRemove = new List<Id>();
        for (Id psgId : desiredPermSetGroups) {
            if (!currentPermSetGroups.contains(psgId)) permSetGroupsToAdd.add(psgId);
        }
        for (Id psgId : currentPermSetGroups) {
            if (!desiredPermSetGroups.contains(psgId)) permSetGroupsToRemove.add(psgId);
        }

        List<Id> permSetLicensesToAdd = new List<Id>();
        List<Id> permSetLicensesToRemove = new List<Id>();
        for (Id pslId : desiredPermSetLicenses) {
            if (!currentPermSetLicenses.contains(pslId)) permSetLicensesToAdd.add(pslId);
        }
        for (Id pslId : currentPermSetLicenses) {
            if (!desiredPermSetLicenses.contains(pslId)) permSetLicensesToRemove.add(pslId);
        }

        List<Id> groupsToAdd = new List<Id>();
        List<Id> groupsToRemove = new List<Id>();
        for (Id gId : desiredGroups) {
            if (!currentGroups.contains(gId)) groupsToAdd.add(gId);
        }
        for (Id gId : currentGroups) {
            if (!desiredGroups.contains(gId)) groupsToRemove.add(gId);
        }

        List<Id> packageLicensesToAdd = new List<Id>();
        List<Id> packageLicensesToRemove = new List<Id>();
        for (Id plId : desiredPackageLicenses) {
            if (!currentPackageLicenses.contains(plId)) packageLicensesToAdd.add(plId);
        }
        for (Id plId : currentPackageLicenses) {
            if (!desiredPackageLicenses.contains(plId)) packageLicensesToRemove.add(plId);
        }

        Boolean hasDiffs = !permSetsToAdd.isEmpty() || !permSetsToRemove.isEmpty()
            || !permSetGroupsToAdd.isEmpty() || !permSetGroupsToRemove.isEmpty()
            || !permSetLicensesToAdd.isEmpty() || !permSetLicensesToRemove.isEmpty()
            || !groupsToAdd.isEmpty() || !groupsToRemove.isEmpty()
            || !packageLicensesToAdd.isEmpty() || !packageLicensesToRemove.isEmpty();

        if (hasDiffs) {
            System.enqueueJob(new UserUpdateAssignmentQueueable(
                userId,
                permSetsToAdd, permSetsToRemove,
                permSetGroupsToAdd, permSetGroupsToRemove,
                permSetLicensesToAdd, permSetLicensesToRemove,
                groupsToAdd, groupsToRemove,
                packageLicensesToAdd, packageLicensesToRemove,
                UserInfo.getUserId()
            ));
        }
    }

    @AuraEnabled
    public static Map<String, Object> getUserEffectivePermissions(Id userId) {
        User u = [
            SELECT Id, Name, IsActive, ProfileId, Profile.Name
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];

        Map<String, Object> userInfo = new Map<String, Object>{
            'id' => u.Id,
            'name' => u.Name,
            'isActive' => u.IsActive,
            'profileId' => u.ProfileId,
            'profileName' => u.Profile != null ? u.Profile.Name : null
        };

        // Build the set of "sources" that contribute to this user's permissions.
        // sourceById maps the PermissionSet id we'll query (profile-owned PS,
        // standalone PS, or PSG-aggregated PS) to a source descriptor that
        // names the *user-facing* origin (profile name, PS label, or PSG label).
        Map<Id, Map<String, Object>> sourceByPsId = new Map<Id, Map<String, Object>>();
        // Maintain stable insertion order (Profile first, then PS, then PSG).
        List<Map<String, Object>> sourcesOrdered = new List<Map<String, Object>>();

        // 1. Profile source: PermissionSet where IsOwnedByProfile = true and Profile.Id = user's profile.
        if (u.ProfileId != null) {
            List<PermissionSet> profilePerms = [
                SELECT Id
                FROM PermissionSet
                WHERE IsOwnedByProfile = true
                  AND ProfileId = :u.ProfileId
                LIMIT 1
            ];
            if (!profilePerms.isEmpty()) {
                Map<String, Object> src = new Map<String, Object>{
                    'sourceId' => 'profile:' + u.ProfileId,
                    'label' => 'Profile: ' + u.Profile.Name,
                    'type' => 'Profile',
                    'originId' => u.ProfileId
                };
                sourceByPsId.put(profilePerms[0].Id, src);
                sourcesOrdered.add(src);
            }
        }

        // 2. Direct PermissionSet assignments (PermissionSetGroupId is null).
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetId, PermissionSet.Label, PermissionSet.Name,
                   PermissionSet.NamespacePrefix
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
              AND PermissionSet.IsOwnedByProfile = false
              AND PermissionSetGroupId = null
            ORDER BY PermissionSet.Label
        ]) {
            Map<String, Object> src = new Map<String, Object>{
                'sourceId' => 'ps:' + psa.PermissionSetId,
                'label' => 'Permission Set: ' + psa.PermissionSet.Label,
                'type' => 'PermissionSet',
                'originId' => psa.PermissionSetId
            };
            sourceByPsId.put(psa.PermissionSetId, src);
            sourcesOrdered.add(src);
        }

        // 3. Permission Set Group assignments. For each PSG the user is assigned to,
        //    the aggregated permissions live on the PermissionSet record where
        //    PermissionSetGroupId points at the group — query for that PS id.
        Set<Id> psgIds = new Set<Id>();
        Map<Id, String> psgLabel = new Map<Id, String>();
        for (PermissionSetAssignment psa : [
            SELECT PermissionSetGroupId, PermissionSetGroup.MasterLabel
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
              AND PermissionSetGroupId != null
        ]) {
            psgIds.add(psa.PermissionSetGroupId);
            psgLabel.put(psa.PermissionSetGroupId, psa.PermissionSetGroup.MasterLabel);
        }
        if (!psgIds.isEmpty()) {
            for (PermissionSet aggregated : [
                SELECT Id, PermissionSetGroupId
                FROM PermissionSet
                WHERE PermissionSetGroupId IN :psgIds
            ]) {
                Id psgId = aggregated.PermissionSetGroupId;
                Map<String, Object> src = new Map<String, Object>{
                    'sourceId' => 'psg:' + psgId,
                    'label' => 'Permission Set Group: ' + psgLabel.get(psgId),
                    'type' => 'PermissionSetGroup',
                    'originId' => psgId
                };
                sourceByPsId.put(aggregated.Id, src);
                sourcesOrdered.add(src);
            }
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('user', userInfo);
        result.put('sources', sourcesOrdered);

        if (sourceByPsId.isEmpty()) {
            result.put('userPermissions', new List<Object>());
            result.put('objectPermissions', new List<Object>());
            result.put('tabSettings', new List<Object>());
            result.put('appAccesses', new List<Object>());
            result.put('customPermissions', new List<Object>());
            return result;
        }

        Set<Id> psIds = sourceByPsId.keySet();

        // --- User / System Permissions: read all Permissions* boolean fields on each source PS.
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.PermissionSet.fields.getMap();
        List<String> permFieldNames = new List<String>();
        for (String f : fieldMap.keySet()) {
            if (!f.startsWith('permissions')) continue;
            if (fieldMap.get(f).getDescribe().getType() != Schema.DisplayType.Boolean) continue;
            permFieldNames.add(f);
        }
        String soql = 'SELECT Id, ' + String.join(permFieldNames, ', ') +
                      ' FROM PermissionSet WHERE Id IN :psIds';
        Map<String, Map<String, Object>> userPermsAgg = new Map<String, Map<String, Object>>();
        for (PermissionSet psRec : (List<PermissionSet>) Database.query(soql)) {
            Map<String, Object> src = sourceByPsId.get(psRec.Id);
            if (src == null) continue;
            for (String fName : permFieldNames) {
                if (psRec.get(fName) == true) {
                    Schema.DescribeFieldResult dfr = fieldMap.get(fName).getDescribe();
                    String apiName = dfr.getName();
                    Map<String, Object> entry = userPermsAgg.get(apiName);
                    if (entry == null) {
                        entry = new Map<String, Object>{
                            'apiName' => apiName,
                            'label' => dfr.getLabel(),
                            'sources' => new List<String>()
                        };
                        userPermsAgg.put(apiName, entry);
                    }
                    ((List<String>) entry.get('sources')).add((String) src.get('sourceId'));
                }
            }
        }
        List<Map<String, Object>> userPerms = new List<Map<String, Object>>(userPermsAgg.values());
        userPerms.sort(new MapLabelObjComparator());
        result.put('userPermissions', userPerms);

        // --- Object Permissions
        Map<String, Map<String, Object>> objAgg = new Map<String, Map<String, Object>>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        for (ObjectPermissions op : [
            SELECT ParentId, SobjectType, PermissionsRead, PermissionsCreate,
                   PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords,
                   PermissionsModifyAllRecords
            FROM ObjectPermissions
            WHERE ParentId IN :psIds
        ]) {
            Map<String, Object> src = sourceByPsId.get(op.ParentId);
            if (src == null) continue;
            String key = op.SobjectType;
            Map<String, Object> entry = objAgg.get(key);
            if (entry == null) {
                String objLabel = key;
                Schema.SObjectType sobjType = globalDescribe.get(key);
                if (sobjType != null) {
                    objLabel = sobjType.getDescribe().getLabel();
                }
                entry = new Map<String, Object>{
                    'apiName' => key,
                    'label' => objLabel,
                    'read' => false, 'create' => false, 'edit' => false,
                    'delete' => false, 'viewAll' => false, 'modifyAll' => false,
                    'grants' => new List<Map<String, Object>>()
                };
                objAgg.put(key, entry);
            }
            if (op.PermissionsRead) entry.put('read', true);
            if (op.PermissionsCreate) entry.put('create', true);
            if (op.PermissionsEdit) entry.put('edit', true);
            if (op.PermissionsDelete) entry.put('delete', true);
            if (op.PermissionsViewAllRecords) entry.put('viewAll', true);
            if (op.PermissionsModifyAllRecords) entry.put('modifyAll', true);
            ((List<Map<String, Object>>) entry.get('grants')).add(new Map<String, Object>{
                'sourceId' => src.get('sourceId'),
                'read' => op.PermissionsRead,
                'create' => op.PermissionsCreate,
                'edit' => op.PermissionsEdit,
                'delete' => op.PermissionsDelete,
                'viewAll' => op.PermissionsViewAllRecords,
                'modifyAll' => op.PermissionsModifyAllRecords
            });
        }
        List<Map<String, Object>> objectPerms = new List<Map<String, Object>>(objAgg.values());
        objectPerms.sort(new MapLabelObjComparator());
        result.put('objectPermissions', objectPerms);

        // --- Tab Settings. Same name-resolution logic as the Permission Set Explorer.
        Map<String, Map<String, Object>> tabAgg = new Map<String, Map<String, Object>>();
        List<PermissionSetTabSetting> rawTabs = [
            SELECT ParentId, Name, Visibility
            FROM PermissionSetTabSetting
            WHERE ParentId IN :psIds
        ];
        Set<String> tabRefs = new Set<String>();
        for (PermissionSetTabSetting ts : rawTabs) tabRefs.add(ts.Name);
        Map<String, TabDefinition> byName = new Map<String, TabDefinition>();
        Map<String, TabDefinition> byDurableId = new Map<String, TabDefinition>();
        Map<String, TabDefinition> byCoreSuffix = new Map<String, TabDefinition>();
        Set<String> coreLikePatterns = new Set<String>();
        for (String ref : tabRefs) {
            if (ref != null && ref.length() >= 15 && ref.startsWith('01r')) {
                coreLikePatterns.add('0KD' + ref.substring(3, 15) + '%');
            }
        }
        if (!tabRefs.isEmpty()) {
            // TabDefinition does not support queryMore(); the SOQL-iterator
            // pattern will throw if results exceed the cursor batch size.
            // Materialize to a List with LIMIT 200 to guarantee one batch.
            List<TabDefinition> byNameTabs = [
                SELECT DurableId, Name, Label FROM TabDefinition
                WHERE Name IN :tabRefs LIMIT 200
            ];
            for (TabDefinition td : byNameTabs) {
                if (td.Name != null) byName.put(td.Name, td);
                if (td.DurableId != null) byDurableId.put(td.DurableId, td);
            }
            List<TabDefinition> byDurableTabs = [
                SELECT DurableId, Name, Label FROM TabDefinition
                WHERE DurableId IN :tabRefs LIMIT 200
            ];
            for (TabDefinition td : byDurableTabs) {
                if (td.Name != null) byName.put(td.Name, td);
                if (td.DurableId != null) byDurableId.put(td.DurableId, td);
            }
            for (String pattern : coreLikePatterns) {
                for (TabDefinition td : [
                    SELECT DurableId, Name, Label FROM TabDefinition
                    WHERE DurableId LIKE :pattern LIMIT 5
                ]) {
                    if (td.DurableId != null && td.DurableId.length() >= 15) {
                        byCoreSuffix.put(td.DurableId.substring(3, 15), td);
                    }
                }
            }
        }
        for (PermissionSetTabSetting ts : rawTabs) {
            Map<String, Object> src = sourceByPsId.get(ts.ParentId);
            if (src == null) continue;
            TabDefinition td = byName.get(ts.Name);
            if (td == null) td = byDurableId.get(ts.Name);
            if (td == null && ts.Name != null && ts.Name.length() >= 15 && ts.Name.startsWith('01r')) {
                td = byCoreSuffix.get(ts.Name.substring(3, 15));
            }
            String label = td != null ? td.Label : ts.Name;
            String apiName = td != null ? td.Name : ts.Name;
            Map<String, Object> entry = tabAgg.get(apiName);
            if (entry == null) {
                entry = new Map<String, Object>{
                    'apiName' => apiName,
                    'label' => label,
                    'grants' => new List<Map<String, Object>>()
                };
                tabAgg.put(apiName, entry);
            }
            ((List<Map<String, Object>>) entry.get('grants')).add(new Map<String, Object>{
                'sourceId' => src.get('sourceId'),
                'visibility' => ts.Visibility
            });
        }
        List<Map<String, Object>> tabSettings = new List<Map<String, Object>>(tabAgg.values());
        tabSettings.sort(new MapLabelObjComparator());
        result.put('tabSettings', tabSettings);

        // --- Apps + Custom Permissions via SetupEntityAccess.
        List<SetupEntityAccess> seaRecs = [
            SELECT ParentId, SetupEntityId, SetupEntityType
            FROM SetupEntityAccess
            WHERE ParentId IN :psIds
              AND SetupEntityType IN ('TabSet', 'CustomPermission')
        ];
        Set<Id> appIds = new Set<Id>();
        Set<Id> customPermIds = new Set<Id>();
        for (SetupEntityAccess sea : seaRecs) {
            if (sea.SetupEntityType == 'TabSet') appIds.add(sea.SetupEntityId);
            else customPermIds.add(sea.SetupEntityId);
        }
        Map<Id, AppMenuItem> appsById = new Map<Id, AppMenuItem>();
        if (!appIds.isEmpty()) {
            for (AppMenuItem ami : [
                SELECT ApplicationId, Label, Name, NamespacePrefix
                FROM AppMenuItem
                WHERE ApplicationId IN :appIds
            ]) {
                appsById.put(ami.ApplicationId, ami);
            }
        }
        Map<Id, CustomPermission> cpsById = new Map<Id, CustomPermission>();
        if (!customPermIds.isEmpty()) {
            for (CustomPermission cp : [
                SELECT Id, DeveloperName, MasterLabel, NamespacePrefix
                FROM CustomPermission
                WHERE Id IN :customPermIds
            ]) {
                cpsById.put(cp.Id, cp);
            }
        }

        Map<Id, Map<String, Object>> appAgg = new Map<Id, Map<String, Object>>();
        Map<Id, Map<String, Object>> cpAgg = new Map<Id, Map<String, Object>>();
        for (SetupEntityAccess sea : seaRecs) {
            Map<String, Object> src = sourceByPsId.get(sea.ParentId);
            if (src == null) continue;
            if (sea.SetupEntityType == 'TabSet') {
                AppMenuItem ami = appsById.get(sea.SetupEntityId);
                if (ami == null) continue;
                Map<String, Object> entry = appAgg.get(ami.ApplicationId);
                if (entry == null) {
                    entry = new Map<String, Object>{
                        'name' => ami.Name,
                        'label' => ami.Label,
                        'namespacePrefix' => ami.NamespacePrefix,
                        'sources' => new List<String>()
                    };
                    appAgg.put(ami.ApplicationId, entry);
                }
                ((List<String>) entry.get('sources')).add((String) src.get('sourceId'));
            } else {
                CustomPermission cp = cpsById.get(sea.SetupEntityId);
                if (cp == null) continue;
                Map<String, Object> entry = cpAgg.get(cp.Id);
                if (entry == null) {
                    entry = new Map<String, Object>{
                        'developerName' => cp.DeveloperName,
                        'label' => cp.MasterLabel,
                        'namespacePrefix' => cp.NamespacePrefix,
                        'sources' => new List<String>()
                    };
                    cpAgg.put(cp.Id, entry);
                }
                ((List<String>) entry.get('sources')).add((String) src.get('sourceId'));
            }
        }
        List<Map<String, Object>> appAccesses = new List<Map<String, Object>>(appAgg.values());
        appAccesses.sort(new MapLabelObjComparator());
        result.put('appAccesses', appAccesses);

        List<Map<String, Object>> customPerms = new List<Map<String, Object>>(cpAgg.values());
        customPerms.sort(new MapLabelObjComparator());
        result.put('customPermissions', customPerms);

        return result;
    }

    private class MapLabelObjComparator implements Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> a, Map<String, Object> b) {
            String al = (String) a.get('label');
            String bl = (String) b.get('label');
            if (al == null) al = '';
            if (bl == null) bl = '';
            return al.toLowerCase().compareTo(bl.toLowerCase());
        }
    }

    private static void validateRequiredFields(User u) {
        List<String> missingFields = new List<String>();

        if (String.isBlank(u.LastName)) missingFields.add('Last Name');
        if (String.isBlank(u.Email)) missingFields.add('Email');
        if (String.isBlank(u.Username)) missingFields.add('Username');
        if (String.isBlank(u.Alias)) missingFields.add('Alias');
        if (u.ProfileId == null) missingFields.add('Profile');
        if (String.isBlank(u.TimeZoneSidKey)) missingFields.add('Time Zone');
        if (String.isBlank(u.LocaleSidKey)) missingFields.add('Locale');
        if (String.isBlank(u.EmailEncodingKey)) missingFields.add('Email Encoding');
        if (String.isBlank(u.LanguageLocaleKey)) missingFields.add('Language');

        if (!missingFields.isEmpty()) {
            String msg = 'Missing required fields: ' + String.join(missingFields, ', ');
            AuraHandledException ex = new AuraHandledException(msg);
            ex.setMessage(msg);
            throw ex;
        }
    }
}
