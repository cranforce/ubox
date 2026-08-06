import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getComparison from '@salesforce/apex/PermissionComparisonController.getComparison';

const PRESENT = '✓'; // ✓
const ABSENT = '—'; // —

export default class PermissionComparison extends LightningElement {
    userAId;
    userBId;
    data;
    isLoading = false;
    activeSections = [];

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
        this.activeSections = [];
        try {
            this.data = await getComparison({
                userAId: this.userAId,
                userBId: this.userBId
            });
            // Open every section by default; users can collapse from there.
            this.activeSections = this.sections.map((s) => s.key);
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

    // Every category renders as a single aligned table: each differing item is
    // one row with the value each user has (or a dash if that user lacks it).
    get sections() {
        const d = this.data;
        if (!d || d.hasDifferences === false) {
            return [];
        }
        const out = [];

        // Profile is a single "both present but different" row.
        const prof = d.mechanisms?.profile;
        if (prof && prof.differs) {
            out.push(
                this.buildSection('profile', 'Profile', [
                    this.row('profile', 'Profile', '', prof.a || ABSENT, prof.b || ABSENT)
                ])
            );
        }

        // Presence-only mechanisms (arrays of name strings).
        [
            ['Permission Sets', 'permissionSets'],
            ['Permission Set Groups', 'permissionSetGroups'],
            ['Public Groups', 'publicGroups'],
            ['Permission Set Licenses', 'permSetLicenses'],
            ['Package Licenses', 'packageLicenses']
        ].forEach(([title, key]) => {
            const m = d.mechanisms?.[key] || { onlyA: [], onlyB: [] };
            const rows = [];
            (m.onlyA || []).forEach((v, i) => rows.push(this.row(key + 'a' + i, v, '', PRESENT, ABSENT)));
            (m.onlyB || []).forEach((v, i) => rows.push(this.row(key + 'b' + i, v, '', ABSENT, PRESENT)));
            this.pushSection(out, 'mech-' + key, title, rows);
        });

        this.presenceSection(out, 'system', 'System Permissions', d.systemPermissions);
        this.valueSection(out, 'objects', 'Object Permissions', d.objectPermissions, (e) => this.crud(e));
        this.flsSection(out, d.fieldSecurity);
        this.tabSection(out, d.tabSettings);
        this.presenceSection(out, 'apps', 'App Access', d.appAccesses);
        this.presenceSection(out, 'custom', 'Custom Permissions', d.customPermissions);

        return out;
    }

    // ---- section builders (each pushes 0 or 1 section) --------------------

    presenceSection(out, key, title, diff) {
        if (!diff) return;
        const rows = [];
        (diff.onlyA || []).forEach((e, i) =>
            rows.push(this.row(key + 'a' + i, e.label, e.apiName, PRESENT, ABSENT))
        );
        (diff.onlyB || []).forEach((e, i) =>
            rows.push(this.row(key + 'b' + i, e.label, e.apiName, ABSENT, PRESENT))
        );
        this.pushSection(out, key, title, rows);
    }

    valueSection(out, key, title, diff, fmt) {
        if (!diff) return;
        const rows = [];
        (diff.onlyA || []).forEach((e, i) =>
            rows.push(this.row(key + 'a' + i, e.label, e.apiName, fmt(e), ABSENT))
        );
        (diff.onlyB || []).forEach((e, i) =>
            rows.push(this.row(key + 'b' + i, e.label, e.apiName, ABSENT, fmt(e)))
        );
        (diff.different || []).forEach((e, i) =>
            rows.push(this.row(key + 'd' + i, e.label, e.apiName, fmt(e.a), fmt(e.b)))
        );
        this.pushSection(out, key, title, rows);
    }

    flsSection(out, diff) {
        if (!diff) return;
        const re = (e) => this.readEdit(e);
        const rows = [];
        const sub = (e) => e.objectLabel + ' · ' + e.field;
        (diff.onlyA || []).forEach((e, i) =>
            rows.push(this.row('flsa' + i, e.label, sub(e), re(e), ABSENT))
        );
        (diff.onlyB || []).forEach((e, i) =>
            rows.push(this.row('flsb' + i, e.label, sub(e), ABSENT, re(e)))
        );
        (diff.different || []).forEach((e, i) =>
            rows.push(this.row('flsd' + i, e.label, sub(e), re(e.a), re(e.b)))
        );
        this.pushSection(out, 'fls', 'Field-Level Security', rows);
    }

    tabSection(out, diff) {
        if (!diff) return;
        const rows = [];
        (diff.onlyA || []).forEach((e, i) =>
            rows.push(this.row('taba' + i, e.label, e.apiName, e.visibility || ABSENT, ABSENT))
        );
        (diff.onlyB || []).forEach((e, i) =>
            rows.push(this.row('tabb' + i, e.label, e.apiName, ABSENT, e.visibility || ABSENT))
        );
        (diff.different || []).forEach((e, i) =>
            rows.push(this.row('tabd' + i, e.label, e.apiName, e.a || ABSENT, e.b || ABSENT))
        );
        this.pushSection(out, 'tabs', 'Tab Settings', rows);
    }

    // ---- helpers ----------------------------------------------------------

    crud(o) {
        const p = [];
        if (o.read) p.push('R');
        if (o.create) p.push('C');
        if (o.edit) p.push('E');
        if (o.delete) p.push('D');
        if (o.viewAll) p.push('VA');
        if (o.modifyAll) p.push('MA');
        return p.join(' ') || ABSENT;
    }

    readEdit(o) {
        const p = [];
        if (o.read) p.push('R');
        if (o.edit) p.push('E');
        return p.join(' ') || ABSENT;
    }

    row(key, item, secondary, aValue, bValue) {
        return {
            key,
            item,
            secondary,
            aValue,
            bValue,
            aClass: this.cellClass(aValue, 'a'),
            bClass: this.cellClass(bValue, 'b')
        };
    }

    cellClass(value, side) {
        if (value === ABSENT) return 'cmp-cell cmp-none';
        return side === 'a' ? 'cmp-cell cmp-a' : 'cmp-cell cmp-b';
    }

    pushSection(out, key, title, rows) {
        if (!rows.length) return;
        rows.sort(
            (x, y) =>
                (x.item || '').localeCompare(y.item || '') ||
                (x.secondary || '').localeCompare(y.secondary || '')
        );
        out.push(this.buildSection(key, title, rows));
    }

    buildSection(key, title, rows) {
        return {
            key,
            title: title + ' (' + rows.length + ')',
            aName: this.userAName,
            bName: this.userBName,
            rows
        };
    }

    // Quick-link jump: scroll the chosen accordion section into view. (Open
    // state is left to the user's own toggles so we don't fight the accordion.)
    handleJump(event) {
        const key = event.currentTarget.dataset.key;
        const el = this.template.querySelector(
            `lightning-accordion-section[data-name="${key}"]`
        );
        if (el) {
            el.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    }

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (typeof error === 'string') return error;
        return JSON.stringify(error);
    }
}
