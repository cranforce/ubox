import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getComparison from '@salesforce/apex/PermissionComparisonController.getComparison';

export default class PermissionComparison extends LightningElement {
    userAId;
    userBId;
    data;
    isLoading = false;

    // Exclude the already-chosen User A from the User B picker.
    get userBFilter() {
        return this.userAId
            ? { criteria: [{ fieldPath: 'Id', operator: 'ne', value: this.userAId }] }
            : undefined;
    }

    handleUserAChange(event) {
        this.userAId = event.detail.recordId;
    }

    handleUserBChange(event) {
        this.userBId = event.detail.recordId;
    }

    get compareDisabled() {
        return (
            !this.userAId ||
            !this.userBId ||
            this.userAId === this.userBId ||
            this.isLoading
        );
    }

    async handleCompare() {
        this.isLoading = true;
        this.data = null;
        try {
            this.data = await getComparison({
                userAId: this.userAId,
                userBId: this.userBId
            });
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Comparison failed',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    get hasResult() {
        return !!this.data;
    }

    get userAName() {
        return this.data?.userA?.name || 'User A';
    }

    get userBName() {
        return this.data?.userB?.name || 'User B';
    }

    get identical() {
        return this.data && this.data.hasDifferences === false;
    }

    get hasDifferences() {
        return this.data && this.data.hasDifferences === true;
    }

    // Unified section model so the template renders every category the same way.
    get sections() {
        const d = this.data;
        if (!d || d.hasDifferences === false) {
            return [];
        }
        const s = [];

        const prof = d.mechanisms?.profile;
        if (prof && prof.differs) {
            s.push(
                this.section('mech-profile', 'Profile', [], [], [
                    {
                        key: 'profile',
                        primary: 'Profile',
                        secondary: '',
                        aDetail: prof.a || '—',
                        bDetail: prof.b || '—'
                    }
                ])
            );
        }

        const mechDefs = [
            ['Permission Sets', 'permissionSets'],
            ['Permission Set Groups', 'permissionSetGroups'],
            ['Public Groups', 'publicGroups'],
            ['Permission Set Licenses', 'permSetLicenses'],
            ['Package Licenses', 'packageLicenses']
        ];
        mechDefs.forEach(([title, key]) => {
            const m = d.mechanisms?.[key] || { onlyA: [], onlyB: [] };
            const onlyA = (m.onlyA || []).map((v, i) => this.entry(key + 'a' + i, v, '', ''));
            const onlyB = (m.onlyB || []).map((v, i) => this.entry(key + 'b' + i, v, '', ''));
            if (onlyA.length || onlyB.length) {
                s.push(this.section('mech-' + key, title, onlyA, onlyB, []));
            }
        });

        this.pushLabelSection(s, 'system', 'System Permissions', d.systemPermissions);
        this.pushObjectSection(s, d.objectPermissions);
        this.pushFlsSection(s, d.fieldSecurity);
        this.pushTabSection(s, d.tabSettings);
        this.pushLabelSection(s, 'apps', 'App Access', d.appAccesses);
        this.pushLabelSection(s, 'custom', 'Custom Permissions', d.customPermissions);

        return s;
    }

    // ---- section builders ------------------------------------------------

    pushLabelSection(s, prefix, title, diff) {
        const onlyA = (diff?.onlyA || []).map((e, i) =>
            this.entry(prefix + 'a' + i, e.label, e.apiName, '')
        );
        const onlyB = (diff?.onlyB || []).map((e, i) =>
            this.entry(prefix + 'b' + i, e.label, e.apiName, '')
        );
        if (onlyA.length || onlyB.length) {
            s.push(this.section(prefix, title, onlyA, onlyB, []));
        }
    }

    pushObjectSection(s, diff) {
        if (!diff) return;
        const crud = (o) => {
            const p = [];
            if (o.read) p.push('R');
            if (o.create) p.push('C');
            if (o.edit) p.push('E');
            if (o.delete) p.push('D');
            if (o.viewAll) p.push('VA');
            if (o.modifyAll) p.push('MA');
            return p.join(' ') || '—';
        };
        const onlyA = (diff.onlyA || []).map((e, i) =>
            this.entry('obja' + i, e.label, e.apiName, crud(e))
        );
        const onlyB = (diff.onlyB || []).map((e, i) =>
            this.entry('objb' + i, e.label, e.apiName, crud(e))
        );
        const different = (diff.different || []).map((e, i) => ({
            key: 'objd' + i,
            primary: e.label,
            secondary: e.apiName,
            aDetail: crud(e.a),
            bDetail: crud(e.b)
        }));
        if (onlyA.length || onlyB.length || different.length) {
            s.push(this.section('objects', 'Object Permissions', onlyA, onlyB, different));
        }
    }

    pushFlsSection(s, diff) {
        if (!diff) return;
        const re = (o) => {
            const p = [];
            if (o.read) p.push('R');
            if (o.edit) p.push('E');
            return p.join(' ') || '—';
        };
        const onlyA = (diff.onlyA || []).map((e, i) =>
            this.entry('flsa' + i, e.label, e.objectLabel + ' · ' + e.field, re(e))
        );
        const onlyB = (diff.onlyB || []).map((e, i) =>
            this.entry('flsb' + i, e.label, e.objectLabel + ' · ' + e.field, re(e))
        );
        const different = (diff.different || []).map((e, i) => ({
            key: 'flsd' + i,
            primary: e.label,
            secondary: e.objectLabel + ' · ' + e.field,
            aDetail: re(e.a),
            bDetail: re(e.b)
        }));
        if (onlyA.length || onlyB.length || different.length) {
            s.push(this.section('fls', 'Field-Level Security', onlyA, onlyB, different));
        }
    }

    pushTabSection(s, diff) {
        if (!diff) return;
        const onlyA = (diff.onlyA || []).map((e, i) =>
            this.entry('taba' + i, e.label, e.apiName, e.visibility)
        );
        const onlyB = (diff.onlyB || []).map((e, i) =>
            this.entry('tabb' + i, e.label, e.apiName, e.visibility)
        );
        const different = (diff.different || []).map((e, i) => ({
            key: 'tabd' + i,
            primary: e.label,
            secondary: e.apiName,
            aDetail: e.a,
            bDetail: e.b
        }));
        if (onlyA.length || onlyB.length || different.length) {
            s.push(this.section('tabs', 'Tab Settings', onlyA, onlyB, different));
        }
    }

    entry(key, primary, secondary, detail) {
        return { key, primary, secondary, detail };
    }

    section(key, title, onlyA, onlyB, different) {
        return {
            key,
            title,
            aName: this.userAName,
            bName: this.userBName,
            onlyA,
            onlyB,
            different,
            hasOnlyA: onlyA.length > 0,
            hasOnlyB: onlyB.length > 0,
            hasDifferent: different.length > 0
        };
    }

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (typeof error === 'string') return error;
        return JSON.stringify(error);
    }
}
