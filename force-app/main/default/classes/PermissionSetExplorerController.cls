public with sharing class PermissionSetExplorerController {

    private static final String TYPE_PS = 'PermissionSet';
    private static final String TYPE_PSG = 'PermissionSetGroup';

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPermissionSets() {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        for (PermissionSet ps : [
            SELECT Id, Label, Name, Description, NamespacePrefix, IsCustom
            FROM PermissionSet
            WHERE IsOwnedByProfile = false
              AND PermissionSetGroupId = null
            ORDER BY Label
        ]) {
            results.add(new Map<String, Object>{
                'id' => ps.Id,
                'label' => ps.Label,
                'name' => ps.Name,
                'description' => ps.Description,
                'namespacePrefix' => ps.NamespacePrefix,
                'isCustom' => ps.IsCustom,
                'type' => TYPE_PS
            });
        }
        for (PermissionSetGroup psg : [
            SELECT Id, MasterLabel, DeveloperName, Description, NamespacePrefix, Status
            FROM PermissionSetGroup
            ORDER BY MasterLabel
        ]) {
            results.add(new Map<String, Object>{
                'id' => psg.Id,
                'label' => psg.MasterLabel,
                'name' => psg.DeveloperName,
                'description' => psg.Description,
                'namespacePrefix' => psg.NamespacePrefix,
                'isCustom' => true,
                'status' => psg.Status,
                'type' => TYPE_PSG
            });
        }
        results.sort(new MapLabelComparatorObj());
        return results;
    }

    @AuraEnabled
    public static Map<String, Object> getPermissionSetDetail(Id permissionSetId) {
        return buildDetailForPermissionSet(permissionSetId, null);
    }

    @AuraEnabled
    public static Map<String, Object> getPermissionSetGroupDetail(Id permissionSetGroupId) {
        List<PermissionSetGroup> groups = [
            SELECT Id, MasterLabel, DeveloperName, Description, NamespacePrefix, Status
            FROM PermissionSetGroup
            WHERE Id = :permissionSetGroupId
            LIMIT 1
        ];
        if (groups.isEmpty()) {
            throw new AuraHandledException('Permission set group not found.');
        }
        PermissionSetGroup psg = groups[0];

        // The aggregated effective permissions for a PSG are stored on the
        // auto-generated PermissionSet record whose PermissionSetGroupId points
        // to the group. Find it and reuse the standard detail builder.
        List<PermissionSet> aggregated = [
            SELECT Id
            FROM PermissionSet
            WHERE PermissionSetGroupId = :permissionSetGroupId
            LIMIT 1
        ];

        Map<String, Object> detail = new Map<String, Object>();
        Map<String, Object> header = new Map<String, Object>{
            'id' => psg.Id,
            'label' => psg.MasterLabel,
            'name' => psg.DeveloperName,
            'description' => psg.Description,
            'namespacePrefix' => psg.NamespacePrefix,
            'isCustom' => true,
            'status' => psg.Status,
            'type' => TYPE_PSG
        };

        if (!aggregated.isEmpty()) {
            Map<String, Object> aggDetail = buildDetailForPermissionSet(aggregated[0].Id, header);
            return aggDetail;
        }

        detail.put('header', header);
        detail.put('userPermissions', new List<Map<String, String>>());
        detail.put('objectPermissions', new List<Map<String, Object>>());
        detail.put('tabSettings', new List<Map<String, String>>());
        detail.put('appAccesses', new List<Map<String, String>>());
        detail.put('customPermissions', new List<Map<String, String>>());
        detail.put('members', getGroupMembers(permissionSetGroupId));
        return detail;
    }

    private static Map<String, Object> buildDetailForPermissionSet(Id permissionSetId, Map<String, Object> groupHeaderOverride) {
        Map<String, Object> detail = new Map<String, Object>();

        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.PermissionSet.fields.getMap();

        // Only the boolean Permissions* user-permission fields. Apex lowercases
        // map keys, so a naive startsWith('permissions') check also matches the
        // PermissionSetGroupId FK — explicitly require a Boolean type.
        List<String> permissionFieldNames = new List<String>();
        for (String fieldName : fieldMap.keySet()) {
            if (!fieldName.startsWith('permissions')) continue;
            if (fieldMap.get(fieldName).getDescribe().getType() != Schema.DisplayType.Boolean) continue;
            permissionFieldNames.add(fieldName);
        }

        List<String> selectFields = new List<String>{
            'Id', 'Label', 'Name', 'Description', 'NamespacePrefix', 'IsCustom',
            'License.Name'
        };
        selectFields.addAll(permissionFieldNames);
        String soql = 'SELECT ' + String.join(selectFields, ', ') +
                      ' FROM PermissionSet WHERE Id = :permissionSetId LIMIT 1';
        // A non-existent PermissionSet Id normally yields no rows, but some org
        // configurations raise a platform exception when the 18-char Id doesn't
        // resolve to a stored key (pljava "18 vs 15"). Treat either outcome as a
        // clean "not found" so callers always get the friendly error.
        List<PermissionSet> psList;
        try {
            psList = Database.query(soql);
        } catch (Exception e) {
            throw new AuraHandledException('Permission set not found.');
        }
        if (psList.isEmpty()) {
            throw new AuraHandledException('Permission set not found.');
        }
        PermissionSet ps = psList[0];

        if (groupHeaderOverride != null) {
            detail.put('header', groupHeaderOverride);
            detail.put('members', getGroupMembers((Id) groupHeaderOverride.get('id')));
        } else {
            Map<String, Object> header = new Map<String, Object>{
                'id' => ps.Id,
                'label' => ps.Label,
                'name' => ps.Name,
                'description' => ps.Description,
                'namespacePrefix' => ps.NamespacePrefix,
                'isCustom' => ps.IsCustom,
                'licenseName' => ps.License != null ? ps.License.Name : null,
                'type' => TYPE_PS
            };
            detail.put('header', header);
        }

        List<Map<String, String>> enabledUserPermissions = new List<Map<String, String>>();
        for (String fieldName : permissionFieldNames) {
            Object val = ps.get(fieldName);
            if (val == true) {
                Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
                enabledUserPermissions.add(new Map<String, String>{
                    'apiName' => dfr.getName(),
                    'label' => dfr.getLabel()
                });
            }
        }
        enabledUserPermissions.sort(new MapLabelComparator());
        detail.put('userPermissions', enabledUserPermissions);

        List<Map<String, Object>> objectPerms = new List<Map<String, Object>>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        for (ObjectPermissions op : [
            SELECT SobjectType, PermissionsRead, PermissionsCreate, PermissionsEdit,
                   PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords
            FROM ObjectPermissions
            WHERE ParentId = :permissionSetId
            ORDER BY SobjectType
        ]) {
            String objectLabel = op.SobjectType;
            Schema.SObjectType sobjType = globalDescribe.get(op.SobjectType);
            if (sobjType != null) {
                objectLabel = sobjType.getDescribe().getLabel();
            }
            objectPerms.add(new Map<String, Object>{
                'apiName' => op.SobjectType,
                'label' => objectLabel,
                'read' => op.PermissionsRead,
                'create' => op.PermissionsCreate,
                'edit' => op.PermissionsEdit,
                'delete' => op.PermissionsDelete,
                'viewAll' => op.PermissionsViewAllRecords,
                'modifyAll' => op.PermissionsModifyAllRecords
            });
        }
        detail.put('objectPermissions', objectPerms);

        // Tab settings (see comment in earlier impl for the resolution rationale).
        List<Map<String, String>> tabSettings = new List<Map<String, String>>();
        List<PermissionSetTabSetting> rawTabSettings = [
            SELECT Name, Visibility
            FROM PermissionSetTabSetting
            WHERE ParentId = :permissionSetId
        ];
        Set<String> tabRefs = new Set<String>();
        for (PermissionSetTabSetting ts : rawTabSettings) {
            tabRefs.add(ts.Name);
        }
        Map<String, TabDefinition> byName = new Map<String, TabDefinition>();
        Map<String, TabDefinition> byDurableId = new Map<String, TabDefinition>();
        Map<String, TabDefinition> byCoreSuffix = new Map<String, TabDefinition>();
        Set<String> idCores = new Set<String>();
        for (String ref : tabRefs) {
            if (ref != null && ref.length() >= 15 && ref.startsWith('01r')) {
                idCores.add(ref.substring(3, 15));
            }
        }
        Set<String> coreLikePatterns = new Set<String>();
        for (String core : idCores) {
            coreLikePatterns.add('0KD' + core + '%');
        }
        if (!tabRefs.isEmpty()) {
            // TabDefinition does not support queryMore(), so a SOQL for-loop (which
            // pages results in 200-record batches) throws once the result exceeds a
            // single batch. Assign to a List first so each query returns in one batch.
            List<TabDefinition> tabsByName = [
                SELECT DurableId, Name, Label, SobjectName
                FROM TabDefinition
                WHERE Name IN :tabRefs
                LIMIT 2000
            ];
            for (TabDefinition td : tabsByName) {
                if (td.Name != null) byName.put(td.Name, td);
                if (td.DurableId != null) byDurableId.put(td.DurableId, td);
            }
            List<TabDefinition> tabsByDurableId = [
                SELECT DurableId, Name, Label, SobjectName
                FROM TabDefinition
                WHERE DurableId IN :tabRefs
                LIMIT 2000
            ];
            for (TabDefinition td : tabsByDurableId) {
                if (td.Name != null) byName.put(td.Name, td);
                if (td.DurableId != null) byDurableId.put(td.DurableId, td);
            }
            for (String pattern : coreLikePatterns) {
                List<TabDefinition> tabsByCore = [
                    SELECT DurableId, Name, Label, SobjectName
                    FROM TabDefinition
                    WHERE DurableId LIKE :pattern
                    LIMIT 5
                ];
                for (TabDefinition td : tabsByCore) {
                    if (td.DurableId != null && td.DurableId.length() >= 15) {
                        byCoreSuffix.put(td.DurableId.substring(3, 15), td);
                    }
                }
            }
        }
        for (PermissionSetTabSetting ts : rawTabSettings) {
            TabDefinition td = byName.get(ts.Name);
            if (td == null) td = byDurableId.get(ts.Name);
            if (td == null && ts.Name != null && ts.Name.length() >= 15 && ts.Name.startsWith('01r')) {
                td = byCoreSuffix.get(ts.Name.substring(3, 15));
            }
            String label = td != null ? td.Label : ts.Name;
            String apiName = td != null ? td.Name : ts.Name;
            tabSettings.add(new Map<String, String>{
                'apiName' => apiName,
                'label' => label,
                'sobjectName' => td != null ? td.SobjectName : null,
                'visibility' => ts.Visibility
            });
        }
        tabSettings.sort(new MapLabelComparator());
        detail.put('tabSettings', tabSettings);

        List<Map<String, String>> appAccesses = new List<Map<String, String>>();
        Set<Id> appSetupIds = new Set<Id>();
        for (SetupEntityAccess sea : [
            SELECT SetupEntityId
            FROM SetupEntityAccess
            WHERE ParentId = :permissionSetId
              AND SetupEntityType = 'TabSet'
        ]) {
            appSetupIds.add(sea.SetupEntityId);
        }
        if (!appSetupIds.isEmpty()) {
            for (AppMenuItem ami : [
                SELECT ApplicationId, Label, Name, NamespacePrefix
                FROM AppMenuItem
                WHERE ApplicationId IN :appSetupIds
                ORDER BY Label
            ]) {
                appAccesses.add(new Map<String, String>{
                    'name' => ami.Name,
                    'label' => ami.Label,
                    'namespacePrefix' => ami.NamespacePrefix
                });
            }
        }
        detail.put('appAccesses', appAccesses);

        List<Map<String, String>> customPerms = new List<Map<String, String>>();
        Set<Id> customPermIds = new Set<Id>();
        for (SetupEntityAccess sea : [
            SELECT SetupEntityId
            FROM SetupEntityAccess
            WHERE ParentId = :permissionSetId
              AND SetupEntityType = 'CustomPermission'
        ]) {
            customPermIds.add(sea.SetupEntityId);
        }
        if (!customPermIds.isEmpty()) {
            for (CustomPermission cp : [
                SELECT DeveloperName, MasterLabel, NamespacePrefix, Description
                FROM CustomPermission
                WHERE Id IN :customPermIds
                ORDER BY MasterLabel
            ]) {
                customPerms.add(new Map<String, String>{
                    'developerName' => cp.DeveloperName,
                    'label' => cp.MasterLabel,
                    'namespacePrefix' => cp.NamespacePrefix,
                    'description' => cp.Description
                });
            }
        }
        detail.put('customPermissions', customPerms);

        return detail;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getFieldPermissions(Id targetId, String targetType, String objectApiName) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        if (targetId == null || String.isBlank(objectApiName)) {
            return results;
        }

        // For a PSG, the field permissions live on the auto-generated aggregated
        // PermissionSet whose PermissionSetGroupId points at the group.
        Id parentId = targetId;
        if (TYPE_PSG.equals(targetType)) {
            List<PermissionSet> aggregated = [
                SELECT Id
                FROM PermissionSet
                WHERE PermissionSetGroupId = :targetId
                LIMIT 1
            ];
            if (aggregated.isEmpty()) {
                return results;
            }
            parentId = aggregated[0].Id;
        }

        // Resolve field labels via describe (best-effort).
        Map<String, Schema.SObjectField> fieldDescribe = null;
        Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(objectApiName);
        if (sobjType != null) {
            fieldDescribe = sobjType.getDescribe().fields.getMap();
        }

        for (FieldPermissions fp : [
            SELECT Field, PermissionsRead, PermissionsEdit
            FROM FieldPermissions
            WHERE ParentId = :parentId
              AND SobjectType = :objectApiName
            ORDER BY Field
        ]) {
            String fieldApiName = fp.Field;
            Integer dot = fieldApiName.indexOf('.');
            if (dot >= 0) {
                fieldApiName = fieldApiName.substring(dot + 1);
            }
            String label = fieldApiName;
            if (fieldDescribe != null && fieldDescribe.containsKey(fieldApiName.toLowerCase())) {
                label = fieldDescribe.get(fieldApiName.toLowerCase()).getDescribe().getLabel();
            }
            results.add(new Map<String, Object>{
                'field' => fieldApiName,
                'label' => label,
                'read' => fp.PermissionsRead,
                'edit' => fp.PermissionsEdit
            });
        }
        results.sort(new MapLabelComparatorObj());
        return results;
    }

    private static List<Map<String, Object>> getGroupMembers(Id permissionSetGroupId) {
        List<Map<String, Object>> members = new List<Map<String, Object>>();
        for (PermissionSetGroupComponent c : [
            SELECT PermissionSetId, PermissionSet.Label, PermissionSet.Name,
                   PermissionSet.NamespacePrefix, PermissionSet.IsCustom
            FROM PermissionSetGroupComponent
            WHERE PermissionSetGroupId = :permissionSetGroupId
            ORDER BY PermissionSet.Label
        ]) {
            members.add(new Map<String, Object>{
                'id' => c.PermissionSetId,
                'label' => c.PermissionSet.Label,
                'name' => c.PermissionSet.Name,
                'namespacePrefix' => c.PermissionSet.NamespacePrefix,
                'isCustom' => c.PermissionSet.IsCustom
            });
        }
        return members;
    }

    @AuraEnabled
    public static List<Map<String, String>> getUsersByIds(List<Id> userIds) {
        List<Map<String, String>> users = new List<Map<String, String>>();
        if (userIds == null || userIds.isEmpty()) {
            return users;
        }
        for (User u : [
            SELECT Id, Name, Username
            FROM User
            WHERE Id IN :userIds
        ]) {
            users.add(new Map<String, String>{
                'id' => u.Id,
                'name' => u.Name,
                'username' => u.Username
            });
        }
        return users;
    }

    @AuraEnabled
    public static List<Map<String, String>> getAssignedUsers(Id targetId, String targetType) {
        List<Map<String, String>> users = new List<Map<String, String>>();
        Boolean isGroup = TYPE_PSG.equals(targetType);
        List<PermissionSetAssignment> assignments;
        if (isGroup) {
            assignments = [
                SELECT Id, AssigneeId, Assignee.Name, Assignee.Username, Assignee.IsActive
                FROM PermissionSetAssignment
                WHERE PermissionSetGroupId = :targetId
                ORDER BY Assignee.Name
            ];
        } else {
            assignments = [
                SELECT Id, AssigneeId, Assignee.Name, Assignee.Username, Assignee.IsActive
                FROM PermissionSetAssignment
                WHERE PermissionSetId = :targetId
                  AND PermissionSetGroupId = null
                ORDER BY Assignee.Name
            ];
        }
        for (PermissionSetAssignment psa : assignments) {
            users.add(new Map<String, String>{
                'assignmentId' => psa.Id,
                'userId' => psa.AssigneeId,
                'name' => psa.Assignee.Name,
                'username' => psa.Assignee.Username,
                'isActive' => String.valueOf(psa.Assignee.IsActive)
            });
        }
        return users;
    }

    @AuraEnabled
    public static Map<String, Object> assignPermissionSet(Id targetId, String targetType, List<Id> userIds) {
        Boolean isGroup = TYPE_PSG.equals(targetType);
        if (userIds == null || userIds.isEmpty()) {
            return new Map<String, Object>{ 'successCount' => 0, 'errors' => new List<String>() };
        }

        Set<Id> alreadyAssigned = new Set<Id>();
        if (isGroup) {
            for (PermissionSetAssignment existing : [
                SELECT AssigneeId
                FROM PermissionSetAssignment
                WHERE PermissionSetGroupId = :targetId
                  AND AssigneeId IN :userIds
            ]) {
                alreadyAssigned.add(existing.AssigneeId);
            }
        } else {
            for (PermissionSetAssignment existing : [
                SELECT AssigneeId
                FROM PermissionSetAssignment
                WHERE PermissionSetId = :targetId
                  AND AssigneeId IN :userIds
                  AND PermissionSetGroupId = null
            ]) {
                alreadyAssigned.add(existing.AssigneeId);
            }
        }

        List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
        for (Id userId : userIds) {
            if (alreadyAssigned.contains(userId)) continue;
            PermissionSetAssignment psa = new PermissionSetAssignment(AssigneeId = userId);
            if (isGroup) {
                psa.PermissionSetGroupId = targetId;
            } else {
                psa.PermissionSetId = targetId;
            }
            toInsert.add(psa);
        }

        Integer successCount = 0;
        List<String> errors = new List<String>();
        if (!toInsert.isEmpty()) {
            Database.SaveResult[] results = Database.insert(toInsert, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    successCount++;
                } else {
                    String userId = toInsert[i].AssigneeId;
                    String msg = results[i].getErrors()[0].getMessage();
                    errors.add(userId + ': ' + msg);
                }
            }
        }

        String detailJson = JSON.serialize(new Map<String, Object>{
            'targetId' => targetId,
            'targetType' => isGroup ? TYPE_PSG : TYPE_PS,
            'requested' => userIds.size(),
            'alreadyAssigned' => alreadyAssigned.size(),
            'successCount' => successCount,
            'errorCount' => errors.size()
        });
        String status = errors.isEmpty() ? 'Success' : 'Error';
        String action = isGroup ? 'Assign Permission Set Group' : 'Assign Permission Set';
        uBoxLogService.createLogAsync(action, null, UserInfo.getUserId(), status, detailJson, false);

        return new Map<String, Object>{
            'successCount' => successCount,
            'skippedCount' => alreadyAssigned.size(),
            'errors' => errors
        };
    }

    @AuraEnabled
    public static void unassignPermissionSet(Id assignmentId) {
        PermissionSetAssignment psa = [
            SELECT Id, AssigneeId, PermissionSetId, PermissionSetGroupId
            FROM PermissionSetAssignment
            WHERE Id = :assignmentId
            LIMIT 1
        ];
        Boolean isGroup = psa.PermissionSetGroupId != null;
        String action = isGroup ? 'Unassign Permission Set Group' : 'Unassign Permission Set';
        try {
            delete psa;
            String detailJson = JSON.serialize(new Map<String, Object>{
                'targetId' => isGroup ? psa.PermissionSetGroupId : psa.PermissionSetId,
                'targetType' => isGroup ? TYPE_PSG : TYPE_PS,
                'userId' => psa.AssigneeId
            });
            uBoxLogService.createLogAsync(action, psa.AssigneeId, UserInfo.getUserId(), 'Success', detailJson, false);
        } catch (DmlException e) {
            uBoxLogService.createLogAsync(action, psa.AssigneeId, UserInfo.getUserId(), 'Error', e.getDmlMessage(0), false);
            throw new AuraHandledException(e.getDmlMessage(0));
        }
    }

    private class MapLabelComparator implements Comparator<Map<String, String>> {
        public Integer compare(Map<String, String> a, Map<String, String> b) {
            String al = a.get('label');
            String bl = b.get('label');
            if (al == null) al = '';
            if (bl == null) bl = '';
            return al.compareTo(bl);
        }
    }

    private class MapLabelComparatorObj implements Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> a, Map<String, Object> b) {
            String al = (String) a.get('label');
            String bl = (String) b.get('label');
            if (al == null) al = '';
            if (bl == null) bl = '';
            return al.toLowerCase().compareTo(bl.toLowerCase());
        }
    }
}
