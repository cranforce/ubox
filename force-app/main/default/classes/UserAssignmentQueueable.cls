public without sharing class UserAssignmentQueueable implements Queueable {

    private Id userId;
    private List<Id> permissionSetIds;
    private List<Id> groupIds;
    private List<Id> packageLicenseIds;
    private List<Id> permSetLicenseIds;
    private List<Id> permSetGroupIds;
    private Id performedById;

    public UserAssignmentQueueable(
        Id userId,
        List<Id> permissionSetIds,
        List<Id> groupIds,
        List<Id> packageLicenseIds,
        List<Id> permSetLicenseIds,
        List<Id> permSetGroupIds,
        Id performedById
    ) {
        this.userId = userId;
        this.permissionSetIds = permissionSetIds;
        this.groupIds = groupIds;
        this.packageLicenseIds = packageLicenseIds;
        this.permSetLicenseIds = permSetLicenseIds;
        this.permSetGroupIds = permSetGroupIds;
        this.performedById = performedById;
    }

    public void execute(QueueableContext context) {
        List<String> errors = new List<String>();
        List<String> successes = new List<String>();

        if (!permissionSetIds.isEmpty()) {
            List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
            for (Id psId : permissionSetIds) {
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
                    successes.add('Permission Set assigned');
                }
            }
        }

        if (!permSetLicenseIds.isEmpty()) {
            List<PermissionSetLicenseAssign> pslas = new List<PermissionSetLicenseAssign>();
            for (Id pslId : permSetLicenseIds) {
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
                    successes.add('Permission Set License assigned');
                }
            }
        }

        if (!groupIds.isEmpty()) {
            List<GroupMember> gms = new List<GroupMember>();
            for (Id gId : groupIds) {
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
                    successes.add('Group member added');
                }
            }
        }

        if (!packageLicenseIds.isEmpty()) {
            List<UserPackageLicense> upls = new List<UserPackageLicense>();
            for (Id plId : packageLicenseIds) {
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
                    successes.add('Package License assigned');
                }
            }
        }

        if (!permSetGroupIds.isEmpty()) {
            List<PermissionSetAssignment> psgAs = new List<PermissionSetAssignment>();
            for (Id psgId : permSetGroupIds) {
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
                    successes.add('Permission Set Group assigned');
                }
            }
        }

        String status = errors.isEmpty() ? 'Success' : 'Partial Success';
        String detail = 'Assignments completed: ' + successes.size() + '.';
        if (!errors.isEmpty()) {
            detail += ' Errors: ' + String.join(errors, '; ');
            System.debug(LoggingLevel.ERROR,
                'UserAssignmentQueueable errors for User ' + userId + ': ' +
                String.join(errors, '; ')
            );
        }

        uBoxLogService.createLogAsync('Create User', userId, performedById, status, detail, true);
    }
}
