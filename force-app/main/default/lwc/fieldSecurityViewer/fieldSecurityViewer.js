import { LightningElement, api } from 'lwc';

const FIELD_COLUMNS = [
    { label: 'Field', fieldName: 'label', wrapText: true },
    { label: 'API Name', fieldName: 'field', initialWidth: 200 },
    { label: 'Read', fieldName: 'read', type: 'boolean', initialWidth: 80, cellAttributes: { alignment: 'center' } },
    { label: 'Edit', fieldName: 'edit', type: 'boolean', initialWidth: 80, cellAttributes: { alignment: 'center' } }
];

export default class FieldSecurityViewer extends LightningElement {
    @api objectOptions = [];
    @api selectedObject;
    @api isLoading = false;
    @api fieldPermissions = [];
    @api showSources = false;

    fieldColumns = FIELD_COLUMNS;

    get hasObjectOptions() {
        return this.objectOptions && this.objectOptions.length > 0;
    }

    get hasSelection() {
        return !!this.selectedObject;
    }

    get hasFields() {
        return this.fieldPermissions && this.fieldPermissions.length > 0;
    }

    get showEmptyState() {
        return this.hasSelection && !this.isLoading && !this.hasFields;
    }

    handleObjectChange(event) {
        this.dispatchEvent(
            new CustomEvent('objectselect', {
                detail: { objectApiName: event.detail.value }
            })
        );
    }
}
