import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getPermissionSetDetail from '@salesforce/apex/PermissionSetExplorerController.getPermissionSetDetail';
import getPermissionSetGroupDetail from '@salesforce/apex/PermissionSetExplorerController.getPermissionSetGroupDetail';
import getAssignedUsers from '@salesforce/apex/PermissionSetExplorerController.getAssignedUsers';
import getUsersByIds from '@salesforce/apex/PermissionSetExplorerController.getUsersByIds';
import assignPermissionSet from '@salesforce/apex/PermissionSetExplorerController.assignPermissionSet';
import unassignPermissionSet from '@salesforce/apex/PermissionSetExplorerController.unassignPermissionSet';

const TYPE_GROUP = 'PermissionSetGroup';
const TYPE_SET = 'PermissionSet';

const OBJECT_COLUMNS = [
    { label: 'Object', fieldName: 'label', wrapText: true },
    { label: 'API Name', fieldName: 'apiName', initialWidth: 200 },
    { label: 'Read', fieldName: 'read', type: 'boolean', initialWidth: 70, cellAttributes: { alignment: 'center' } },
    { label: 'Create', fieldName: 'create', type: 'boolean', initialWidth: 80, cellAttributes: { alignment: 'center' } },
    { label: 'Edit', fieldName: 'edit', type: 'boolean', initialWidth: 70, cellAttributes: { alignment: 'center' } },
    { label: 'Delete', fieldName: 'delete', type: 'boolean', initialWidth: 80, cellAttributes: { alignment: 'center' } },
    { label: 'View All', fieldName: 'viewAll', type: 'boolean', initialWidth: 90, cellAttributes: { alignment: 'center' } },
    { label: 'Modify All', fieldName: 'modifyAll', type: 'boolean', initialWidth: 100, cellAttributes: { alignment: 'center' } }
];

const ASSIGNED_COLUMNS = [
    { label: 'Name', fieldName: 'name', wrapText: true },
    { label: 'Username', fieldName: 'username', wrapText: true },
    { label: 'Active', fieldName: 'isActive', initialWidth: 90 },
    {
        type: 'button-icon',
        initialWidth: 50,
        typeAttributes: {
            iconName: 'utility:delete',
            name: 'unassign',
            title: 'Unassign',
            variant: 'bare',
            alternativeText: 'Unassign'
        }
    }
];

export default class PermissionSetDetail extends LightningElement {
    _permissionSetId;
    _permissionSetType = TYPE_SET;

    @api
    get permissionSetId() {
        return this._permissionSetId;
    }
    set permissionSetId(value) {
        this._permissionSetId = value;
        this.scheduleLoad();
    }

    @api
    get permissionSetType() {
        return this._permissionSetType;
    }
    set permissionSetType(value) {
        this._permissionSetType = value || TYPE_SET;
        this.scheduleLoad();
    }

    _loadScheduled = false;

    scheduleLoad() {
        // Coalesce simultaneous changes to id + type into a single load.
        // Without this, swapping from a PS to a PSG (or vice versa) fires
        // loadDetail once with the new id and the *old* type and toasts a
        // spurious "not found" error before the second setter runs.
        if (this._loadScheduled) return;
        this._loadScheduled = true;
        Promise.resolve().then(() => {
            this._loadScheduled = false;
            if (this._permissionSetId) {
                this.loadDetail();
            } else {
                this.detail = null;
                this.assignedUsers = [];
            }
        });
    }

    isLoading = false;
    detail;
    assignedUsers = [];
    pendingUsers = [];
    isAssigning = false;
    activeSections = ['objects', 'tabs', 'apps', 'customPerms', 'userPerms', 'members', 'assignment'];

    objectColumns = OBJECT_COLUMNS;
    assignedColumns = ASSIGNED_COLUMNS;

    get isGroup() {
        return this._permissionSetType === TYPE_GROUP;
    }

    get hasDetail() {
        return !!this.detail;
    }

    get header() {
        return this.detail?.header;
    }

    get headerStatus() {
        return this.detail?.header?.status;
    }

    get hasHeaderStatus() {
        return !!this.detail?.header?.status;
    }

    get headerStatusVariant() {
        const status = this.headerStatus;
        if (!status) return 'base';
        if (status === 'Updated') return 'success';
        if (status === 'Outdated') return 'warning';
        return 'base';
    }

    get objectPermissions() {
        return this.detail?.objectPermissions || [];
    }

    get tabSettings() {
        return this.detail?.tabSettings || [];
    }

    get appAccesses() {
        return this.detail?.appAccesses || [];
    }

    get customPermissions() {
        return this.detail?.customPermissions || [];
    }

    get userPermissions() {
        return this.detail?.userPermissions || [];
    }

    get members() {
        return this.detail?.members || [];
    }

    get hasObjectPermissions() {
        return this.objectPermissions.length > 0;
    }

    get hasTabSettings() {
        return this.tabSettings.length > 0;
    }

    get hasAppAccesses() {
        return this.appAccesses.length > 0;
    }

    get hasCustomPermissions() {
        return this.customPermissions.length > 0;
    }

    get hasUserPermissions() {
        return this.userPermissions.length > 0;
    }

    get hasMembers() {
        return this.members.length > 0;
    }

    get hasAssignedUsers() {
        return this.assignedUsers.length > 0;
    }

    get assignDisabled() {
        return this.isAssigning || this.pendingUsers.length === 0;
    }

    get assignButtonLabel() {
        const count = this.pendingUsers.length;
        return count > 0 ? `Assign (${count})` : 'Assign';
    }

    get hasPendingUsers() {
        return this.pendingUsers.length > 0;
    }

    get pendingUserPills() {
        return this.pendingUsers.map(u => ({
            type: 'icon',
            label: u.name,
            name: u.id,
            iconName: 'standard:user'
        }));
    }

    get objectCountLabel() {
        return `Object Settings (${this.objectPermissions.length})`;
    }

    get tabCountLabel() {
        return `Tab Settings (${this.tabSettings.length})`;
    }

    get appCountLabel() {
        return `App Access (${this.appAccesses.length})`;
    }

    get customPermCountLabel() {
        return `Custom Permissions (${this.customPermissions.length})`;
    }

    get userPermCountLabel() {
        return `System Permissions (${this.userPermissions.length})`;
    }

    get membersCountLabel() {
        return `Member Permission Sets (${this.members.length})`;
    }

    get assignedCountLabel() {
        return `Assigned Users (${this.assignedUsers.length})`;
    }

    get unassignConfirmNoun() {
        return this.isGroup ? 'permission set group' : 'permission set';
    }

    get noAssignmentsLabel() {
        return this.isGroup
            ? 'No users currently assigned to this permission set group.'
            : 'No users currently assigned to this permission set.';
    }

    get assignmentFilter() {
        const ids = [
            ...this.assignedUsers.map(u => u.userId),
            ...this.pendingUsers.map(u => u.id)
        ];
        return {
            criteria: ids.length
                ? [{ fieldPath: 'Id', operator: 'nin', value: ids }]
                : []
        };
    }

    async loadDetail() {
        this.isLoading = true;
        this.pendingUsers = [];
        try {
            const detailPromise = this.isGroup
                ? getPermissionSetGroupDetail({ permissionSetGroupId: this._permissionSetId })
                : getPermissionSetDetail({ permissionSetId: this._permissionSetId });
            const [detail, assigned] = await Promise.all([
                detailPromise,
                getAssignedUsers({
                    targetId: this._permissionSetId,
                    targetType: this._permissionSetType
                })
            ]);
            this.detail = detail;
            this.assignedUsers = assigned;
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleMemberClick(event) {
        event.preventDefault();
        const memberId = event.currentTarget.dataset.id;
        if (!memberId) return;
        this.dispatchEvent(
            new CustomEvent('memberselect', {
                detail: { permissionSetId: memberId }
            })
        );
    }

    async handleUserSelect(event) {
        const recordId = event.detail.recordId;
        const picker = event.target;
        if (!recordId) {
            return;
        }
        if (this.pendingUsers.some(u => u.id === recordId)) {
            picker.clearSelection?.();
            return;
        }
        try {
            const users = await getUsersByIds({ userIds: [recordId] });
            if (users.length > 0) {
                this.pendingUsers = [...this.pendingUsers, users[0]];
            }
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            picker.clearSelection?.();
        }
    }

    handleRemovePending(event) {
        const userId = event.detail.item?.name;
        if (!userId) return;
        this.pendingUsers = this.pendingUsers.filter(u => u.id !== userId);
    }

    async handleAssign() {
        if (this.pendingUsers.length === 0) {
            return;
        }
        this.isAssigning = true;
        try {
            const result = await assignPermissionSet({
                targetId: this._permissionSetId,
                targetType: this._permissionSetType,
                userIds: this.pendingUsers.map(u => u.id)
            });
            const errors = result.errors || [];
            if (errors.length > 0) {
                this.showToast(
                    'Assignment completed with errors',
                    `Success: ${result.successCount}. Errors: ${errors.join('; ')}`,
                    'warning'
                );
            } else {
                const msg = result.skippedCount
                    ? `Assigned ${result.successCount}. Skipped ${result.skippedCount} already-assigned.`
                    : `Assigned ${result.successCount} user(s).`;
                this.showToast('Success', msg, 'success');
            }
            this.pendingUsers = [];
            const assigned = await getAssignedUsers({
                targetId: this._permissionSetId,
                targetType: this._permissionSetType
            });
            this.assignedUsers = assigned;
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isAssigning = false;
        }
    }

    async handleRowAction(event) {
        if (event.detail.action.name !== 'unassign') {
            return;
        }
        const row = event.detail.row;
        const confirmed = await LightningConfirm.open({
            message: `Unassign ${row.name} from this ${this.unassignConfirmNoun}?`,
            variant: 'header',
            label: 'Confirm unassignment',
            theme: 'warning'
        });
        if (!confirmed) {
            return;
        }
        try {
            await unassignPermissionSet({ assignmentId: row.assignmentId });
            this.assignedUsers = this.assignedUsers.filter(
                u => u.assignmentId !== row.assignmentId
            );
            this.showToast('Removed', `${row.name} unassigned.`, 'success');
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (typeof error === 'string') return error;
        return JSON.stringify(error);
    }
}
