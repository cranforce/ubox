import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getUserEffectivePermissions from '@salesforce/apex/UserManagementController.getUserEffectivePermissions';
import getUserFieldPermissions from '@salesforce/apex/UserManagementController.getUserFieldPermissions';

const SOURCE_BADGE_CLASS = {
    Profile: 'slds-theme_info',
    PermissionSet: 'slds-theme_success',
    PermissionSetGroup: 'slds-theme_warning'
};

export default class UserPermissionInspector extends LightningElement {
    _userId;

    @api
    get userId() {
        return this._userId;
    }
    set userId(value) {
        this._userId = value;
        if (value) {
            this.loadDetail();
        } else {
            this.data = null;
        }
    }

    isLoading = false;
    data;
    sourceById = {};
    activeSections = ['objects', 'tabs', 'apps', 'customPerms', 'userPerms'];
    flsObject;
    flsRows = [];
    flsLoading = false;
    showFlsSources = true;

    get hasData() {
        return !!this.data;
    }

    get sources() {
        return this.data?.sources || [];
    }

    get sourcePills() {
        return (this.data?.sources || []).map(s => ({
            ...s,
            badgeClass: SOURCE_BADGE_CLASS[s.type] || ''
        }));
    }

    get objectPermissions() {
        return (this.data?.objectPermissions || []).map(o => ({
            ...o,
            crudBadges: this.buildCrudBadges(o),
            grantPills: (o.grants || []).map(g => {
                const src = this.sourceById[g.sourceId] || { label: g.sourceId, type: '' };
                return {
                    key: g.sourceId + '|' + (g.read ? 'r' : '') + (g.create ? 'c' : '') +
                         (g.edit ? 'e' : '') + (g.delete ? 'd' : '') +
                         (g.viewAll ? 'v' : '') + (g.modifyAll ? 'm' : ''),
                    label: src.label,
                    detail: this.summarizeCrud(g),
                    badgeClass: SOURCE_BADGE_CLASS[src.type] || ''
                };
            })
        }));
    }

    get objectOptions() {
        return this.objectPermissions.map(o => ({
            label: `${o.label} (${o.apiName})`,
            value: o.apiName
        }));
    }

    get tabSettings() {
        return (this.data?.tabSettings || []).map(t => ({
            ...t,
            grantPills: (t.grants || []).map(g => {
                const src = this.sourceById[g.sourceId] || { label: g.sourceId, type: '' };
                return {
                    key: g.sourceId,
                    label: src.label,
                    detail: g.visibility,
                    badgeClass: SOURCE_BADGE_CLASS[src.type] || ''
                };
            })
        }));
    }

    get appAccesses() {
        return (this.data?.appAccesses || []).map(a => ({
            ...a,
            sourcePills: (a.sources || []).map(sid => {
                const src = this.sourceById[sid] || { label: sid, type: '' };
                return {
                    key: sid,
                    label: src.label,
                    badgeClass: SOURCE_BADGE_CLASS[src.type] || ''
                };
            })
        }));
    }

    get customPermissions() {
        return (this.data?.customPermissions || []).map(cp => ({
            ...cp,
            sourcePills: (cp.sources || []).map(sid => {
                const src = this.sourceById[sid] || { label: sid, type: '' };
                return {
                    key: sid,
                    label: src.label,
                    badgeClass: SOURCE_BADGE_CLASS[src.type] || ''
                };
            })
        }));
    }

    get userPermissions() {
        return (this.data?.userPermissions || []).map(up => ({
            ...up,
            sourcePills: (up.sources || []).map(sid => {
                const src = this.sourceById[sid] || { label: sid, type: '' };
                return {
                    key: sid,
                    label: src.label,
                    badgeClass: SOURCE_BADGE_CLASS[src.type] || ''
                };
            })
        }));
    }

    get hasObjectPermissions() { return this.objectPermissions.length > 0; }
    get hasTabSettings() { return this.tabSettings.length > 0; }
    get hasAppAccesses() { return this.appAccesses.length > 0; }
    get hasCustomPermissions() { return this.customPermissions.length > 0; }
    get hasUserPermissions() { return this.userPermissions.length > 0; }

    get objectCountLabel() { return `Object Settings (${this.objectPermissions.length})`; }
    get tabCountLabel() { return `Tab Settings (${this.tabSettings.length})`; }
    get appCountLabel() { return `App Access (${this.appAccesses.length})`; }
    get customPermCountLabel() { return `Custom Permissions (${this.customPermissions.length})`; }
    get userPermCountLabel() { return `System Permissions (${this.userPermissions.length})`; }

    buildCrudBadges(o) {
        const flags = [
            { label: 'R', on: !!o.read, title: 'Read' },
            { label: 'C', on: !!o.create, title: 'Create' },
            { label: 'E', on: !!o.edit, title: 'Edit' },
            { label: 'D', on: !!o.delete, title: 'Delete' },
            { label: 'VA', on: !!o.viewAll, title: 'View All' },
            { label: 'MA', on: !!o.modifyAll, title: 'Modify All' }
        ];
        return flags.map(f => ({
            ...f,
            key: f.label,
            cssClass: f.on
                ? 'slds-badge slds-theme_success slds-var-m-right_xx-small'
                : 'slds-badge slds-var-m-right_xx-small slds-text-color_weak'
        }));
    }

    summarizeCrud(g) {
        const parts = [];
        if (g.read) parts.push('R');
        if (g.create) parts.push('C');
        if (g.edit) parts.push('E');
        if (g.delete) parts.push('D');
        if (g.viewAll) parts.push('VA');
        if (g.modifyAll) parts.push('MA');
        return parts.length ? parts.join('') : '—';
    }

    async handleFlsObjectSelect(event) {
        const objectApiName = event.detail.objectApiName;
        this.flsObject = objectApiName;
        if (!objectApiName) {
            this.flsRows = [];
            return;
        }
        this.flsLoading = true;
        try {
            const result = await getUserFieldPermissions({
                userId: this._userId,
                objectApiName
            });
            this.flsRows = (result?.fields || []).map(f => ({
                ...f,
                grantPills: (f.grants || []).map(g => {
                    const src = this.sourceById[g.sourceId] || { label: g.sourceId, type: '' };
                    return {
                        key: g.sourceId + '|' + (g.read ? 'r' : '') + (g.edit ? 'e' : ''),
                        label: src.label,
                        detail: this.summarizeReadEdit(g),
                        badgeClass: SOURCE_BADGE_CLASS[src.type] || ''
                    };
                })
            }));
        } catch (error) {
            this.flsRows = [];
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading field permissions',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.flsLoading = false;
        }
    }

    summarizeReadEdit(g) {
        const parts = [];
        if (g.read) parts.push('R');
        if (g.edit) parts.push('E');
        return parts.length ? parts.join('') : '—';
    }

    async loadDetail() {
        this.isLoading = true;
        this.flsObject = undefined;
        this.flsRows = [];
        try {
            const result = await getUserEffectivePermissions({ userId: this._userId });
            this.data = result;
            const map = {};
            (result.sources || []).forEach(s => { map[s.sourceId] = s; });
            this.sourceById = map;
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading permissions',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (typeof error === 'string') return error;
        return JSON.stringify(error);
    }
}
