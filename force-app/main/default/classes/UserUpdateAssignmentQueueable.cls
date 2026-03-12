public without sharing class UserUpdateAssignmentQueueable implements Queueable {

    private Id userId;
    private List<Id> permSetsToAdd;
    private List<Id> permSetsToRemove;
    private List<Id> permSetGroupsToAdd;
    private List<Id> permSetGroupsToRemove;
    private List<Id> permSetLicensesToAdd;
    private List<Id> permSetLicensesToRemove;
    private List<Id> groupsToAdd;
    private List<Id> groupsToRemove;
    private List<Id> packageLicensesToAdd;
    private List<Id> packageLicensesToRemove;
    private Id performedById;

    public UserUpdateAssignmentQueueable(
        Id userId,
        List<Id> permSetsToAdd,
        List<Id> permSetsToRemove,
        List<Id> permSetGroupsToAdd,
        List<Id> permSetGroupsToRemove,
        List<Id> permSetLicensesToAdd,
        List<Id> permSetLicensesToRemove,
        List<Id> groupsToAdd,
        List<Id> groupsToRemove,
        List<Id> packageLicensesToAdd,
        List<Id> packageLicensesToRemove,
        Id performedById
    ) {
        this.userId = userId;
        this.permSetsToAdd = permSetsToAdd;
        this.permSetsToRemove = permSetsToRemove;
        this.permSetGroupsToAdd = permSetGroupsToAdd;
        this.permSetGroupsToRemove = permSetGroupsToRemove;
        this.permSetLicensesToAdd = permSetLicensesToAdd;
        this.permSetLicensesToRemove = permSetLicensesToRemove;
        this.groupsToAdd = groupsToAdd;
        this.groupsToRemove = groupsToRemove;
        this.packageLicensesToAdd = packageLicensesToAdd;
        this.packageLicensesToRemove = packageLicensesToRemove;
        this.performedById = performedById;
    }

    public void execute(QueueableContext context) {
        List<String> errors = new List<String>();
        Integer successCount = 0;

        // --- Removals (reverse order: perm sets first, then licenses last) ---

        // 1. Groups — no dependencies
        if (!groupsToRemove.isEmpty()) {
            List<GroupMember> toDelete = [
                SELECT Id FROM GroupMember
                WHERE UserOrGroupId = :userId
                  AND GroupId IN :groupsToRemove
            ];
            for (Database.DeleteResult r : Database.delete(toDelete, false)) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        errors.add('Remove Group: ' + e.getMessage());
                    }
                } else {
                    successCount++;
                }
            }
        }

        // 2. Permission Sets — remove before removing licenses they depend on
        if (!permSetsToRemove.isEmpty()) {
            List<PermissionSetAssignment> toDelete = [
                SELECT Id FROM PermissionSetAssignment
                WHERE AssigneeId = :userId
                  AND PermissionSetId IN :permSetsToRemove
                  AND PermissionSetGroupId = null
            ];
            for (Database.DeleteResult r : Database.delete(toDelete, false)) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        errors.add('Remove Permission Set: ' + e.getMessage());
                    }
                } else {
                    successCount++;
                }
            }
        }

        // 3. Permission Set Groups — remove before removing licenses
        if (!permSetGroupsToRemove.isEmpty()) {
            List<PermissionSetAssignment> toDelete = [
                SELECT Id FROM PermissionSetAssignment
                WHERE AssigneeId = :userId
                  AND PermissionSetGroupId IN :permSetGroupsToRemove
            ];
            for (Database.DeleteResult r : Database.delete(toDelete, false)) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        errors.add('Remove Permission Set Group: ' + e.getMessage());
                    }
                } else {
                    successCount++;
                }
            }
        }

        // 4. Package Licenses — remove after perm sets that may depend on them
        if (!packageLicensesToRemove.isEmpty()) {
            List<UserPackageLicense> toDelete = [
                SELECT Id FROM UserPackageLicense
                WHERE UserId = :userId
                  AND PackageLicenseId IN :packageLicensesToRemove
            ];
            for (Database.DeleteResult r : Database.delete(toDelete, false)) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        errors.add('Remove Package License: ' + e.getMessage());
                    }
                } else {
                    successCount++;
                }
            }
        }

        // 5. Permission Set Licenses — remove last since perm sets depend on them
        if (!permSetLicensesToRemove.isEmpty()) {
            List<PermissionSetLicenseAssign> toDelete = [
                SELECT Id FROM PermissionSetLicenseAssign
                WHERE AssigneeId = :userId
                  AND PermissionSetLicenseId IN :permSetLicensesToRemove
            ];
            for (Database.DeleteResult r : Database.delete(toDelete, false)) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        errors.add('Remove Permission Set License: ' + e.getMessage());
                    }
                } else {
                    successCount++;
                }
            }
        }

        // --- Additions (ordered: licenses first, then perm sets, then groups) ---

        // 1. Permission Set Licenses first — required by some permission sets
        if (!permSetLicensesToAdd.isEmpty()) {
            List<PermissionSetLicenseAssign> pslas = new List<PermissionSetLicenseAssign>();
            for (Id pslId : permSetLicensesToAdd) {
                pslas.add(new PermissionSetLicenseAssign(
                    AssigneeId = userId,
                    PermissionSetLicenseId = pslId
                ));
            }
            for (Database.SaveResult r : Database.insert(pslas, false)) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        errors.add('Permission Set License: ' + e.getMessage());
                    }
                } else {
                    successCount++;
                }
            }
        }

        // 2. Package Licenses — may also be prerequisites
        if (!packageLicensesToAdd.isEmpty()) {
            List<UserPackageLicense> upls = new List<UserPackageLicense>();
            for (Id plId : packageLicensesToAdd) {
                upls.add(new UserPackageLicense(
                    UserId = userId,
                    PackageLicenseId = plId
                ));
            }
            for (Database.SaveResult r : Database.insert(upls, false)) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        errors.add('Package License: ' + e.getMessage());
                    }
                } else {
                    successCount++;
                }
            }
        }

        // 3. Permission Set Groups — may contain permission sets needing licenses
        if (!permSetGroupsToAdd.isEmpty()) {
            List<PermissionSetAssignment> psgAs = new List<PermissionSetAssignment>();
            for (Id psgId : permSetGroupsToAdd) {
                psgAs.add(new PermissionSetAssignment(
                    AssigneeId = userId,
                    PermissionSetGroupId = psgId
                ));
            }
            for (Database.SaveResult r : Database.insert(psgAs, false)) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        errors.add('Permission Set Group: ' + e.getMessage());
                    }
                } else {
                    successCount++;
                }
            }
        }

        // 4. Permission Sets — depend on licenses being assigned first
        if (!permSetsToAdd.isEmpty()) {
            List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
            for (Id psId : permSetsToAdd) {
                psas.add(new PermissionSetAssignment(
                    AssigneeId = userId,
                    PermissionSetId = psId
                ));
            }
            for (Database.SaveResult r : Database.insert(psas, false)) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        errors.add('Permission Set: ' + e.getMessage());
                    }
                } else {
                    successCount++;
                }
            }
        }

        // 5. Groups — no dependencies
        if (!groupsToAdd.isEmpty()) {
            List<GroupMember> gms = new List<GroupMember>();
            for (Id gId : groupsToAdd) {
                gms.add(new GroupMember(
                    UserOrGroupId = userId,
                    GroupId = gId
                ));
            }
            for (Database.SaveResult r : Database.insert(gms, false)) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) {
                        errors.add('Group: ' + e.getMessage());
                    }
                } else {
                    successCount++;
                }
            }
        }

        String status = errors.isEmpty() ? 'Success' : 'Partial Success';
        String detail = 'Assignment changes completed: ' + successCount + '.';
        if (!errors.isEmpty()) {
            detail += ' Errors: ' + String.join(errors, '; ');
            System.debug(LoggingLevel.ERROR,
                'UserUpdateAssignmentQueueable errors for User ' + userId + ': ' +
                String.join(errors, '; ')
            );
        }

        uBoxLogService.createLogAsync('Edit User', userId, performedById, status, detail, true);
    }
}
