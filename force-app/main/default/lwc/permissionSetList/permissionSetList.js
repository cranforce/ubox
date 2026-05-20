import { LightningElement, api } from 'lwc';

const TYPE_GROUP = 'PermissionSetGroup';

export default class PermissionSetList extends LightningElement {
    @api permissionSets = [];
    @api selectedId;

    searchTerm = '';

    get filteredSets() {
        const term = this.searchTerm.trim().toLowerCase();
        const source = term
            ? this.permissionSets.filter(ps => {
                const label = (ps.label || '').toLowerCase();
                const name = (ps.name || '').toLowerCase();
                const typeLabel = ps.type === TYPE_GROUP ? 'group' : 'set';
                return (
                    label.includes(term) ||
                    name.includes(term) ||
                    typeLabel.includes(term)
                );
            })
            : this.permissionSets;

        return source.map(ps => {
            const isGroup = ps.type === TYPE_GROUP;
            return {
                ...ps,
                badgeLabel: isGroup ? 'Group' : 'Set',
                badgeClass: isGroup
                    ? 'slds-var-m-left_x-small slds-theme_info'
                    : 'slds-var-m-left_x-small',
                cssClass:
                    ps.id === this.selectedId
                        ? 'slds-item ps-item ps-item_selected'
                        : 'slds-item ps-item'
            };
        });
    }

    get resultCountLabel() {
        const filtered = this.filteredSets.length;
        const total = this.permissionSets.length;
        const noun = 'permission sets & groups';
        return filtered === total
            ? `${total} ${noun}`
            : `${filtered} of ${total} ${noun}`;
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleSelect(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        const type = event.currentTarget.dataset.type;
        this.dispatchEvent(
            new CustomEvent('select', {
                detail: { permissionSetId: id, permissionSetType: type }
            })
        );
    }
}
