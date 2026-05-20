import { LightningElement, api } from 'lwc';

const STATUS_FILTERS = [
    { label: 'Active', value: 'active' },
    { label: 'Inactive', value: 'inactive' },
    { label: 'All', value: 'all' }
];

export default class UserList extends LightningElement {
    @api users = [];
    @api selectedId;

    searchTerm = '';
    statusFilter = 'active';

    statusFilters = STATUS_FILTERS;

    get filteredUsers() {
        const term = this.searchTerm.trim().toLowerCase();
        const status = this.statusFilter;

        const filtered = this.users.filter(u => {
            if (status === 'active' && !u.isActive) return false;
            if (status === 'inactive' && u.isActive) return false;

            if (!term) return true;
            const name = (u.name || '').toLowerCase();
            const username = (u.username || '').toLowerCase();
            const email = (u.email || '').toLowerCase();
            const profile = (u.profileName || '').toLowerCase();
            return (
                name.includes(term) ||
                username.includes(term) ||
                email.includes(term) ||
                profile.includes(term)
            );
        });

        return filtered.map(u => ({
            ...u,
            badgeLabel: u.isActive ? 'Active' : 'Inactive',
            badgeClass: u.isActive
                ? 'slds-var-m-left_x-small slds-theme_success'
                : 'slds-var-m-left_x-small slds-theme_warning',
            cssClass:
                u.id === this.selectedId
                    ? 'slds-item ps-item ps-item_selected'
                    : 'slds-item ps-item'
        }));
    }

    get resultCountLabel() {
        const filtered = this.filteredUsers.length;
        const total = this.users.length;
        return filtered === total
            ? `${total} users`
            : `${filtered} of ${total} users`;
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleStatusChange(event) {
        this.statusFilter = event.detail.value;
    }

    handleSelect(event) {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        this.dispatchEvent(
            new CustomEvent('select', { detail: { userId: id } })
        );
    }
}
