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
            throw new AuraHandledException(e.getDmlMessage(0));
        }

        Boolean hasAssignments = (permissionSetIds != null && !permissionSetIds.isEmpty())
            || (groupIds != null && !groupIds.isEmpty())
            || (packageLicenseIds != null && !packageLicenseIds.isEmpty())
            || (permSetLicenseIds != null && !permSetLicenseIds.isEmpty())
            || (permSetGroupIds != null && !permSetGroupIds.isEmpty());

        if (hasAssignments) {
            System.enqueueJob(new UserAssignmentQueueable(
                newUser.Id,
                permissionSetIds != null ? permissionSetIds : new List<Id>(),
                groupIds != null ? groupIds : new List<Id>(),
                packageLicenseIds != null ? packageLicenseIds : new List<Id>(),
                permSetLicenseIds != null ? permSetLicenseIds : new List<Id>(),
                permSetGroupIds != null ? permSetGroupIds : new List<Id>()
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
            throw new AuraHandledException(e.getDmlMessage(0));
        }

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
                packageLicensesToAdd, packageLicensesToRemove
            ));
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
            throw new AuraHandledException(
                'Missing required fields: ' + String.join(missingFields, ', ')
            );
        }
    }
}
