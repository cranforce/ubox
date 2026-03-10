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
        List<Id> packageLicensesToRemove
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
    }

    public void execute(QueueableContext context) {
        List<String> errors = new List<String>();

        // --- Removals ---

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
                }
            }
        }

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
                }
            }
        }

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
                }
            }
        }

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
                }
            }
        }

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
                }
            }
        }

        // --- Additions ---

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
                }
            }
        }

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
                }
            }
        }

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
                }
            }
        }

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
                }
            }
        }

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
                }
            }
        }

        if (!errors.isEmpty()) {
            System.debug(LoggingLevel.ERROR,
                'UserUpdateAssignmentQueueable errors for User ' + userId + ': ' +
                String.join(errors, '; ')
            );
        }
    }
}
