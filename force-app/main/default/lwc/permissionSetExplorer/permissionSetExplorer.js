import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPermissionSets from '@salesforce/apex/PermissionSetExplorerController.getPermissionSets';

const TYPE_GROUP = 'PermissionSetGroup';

export default class PermissionSetExplorer extends NavigationMixin(LightningElement) {
    isLoading = true;
    permissionSets = [];
    selectedId;
    selectedType;

    get isOpenInSetupDisabled() {
        return !this.selectedId;
    }

    connectedCallback() {
        this.loadPermissionSets();
    }

    async loadPermissionSets() {
        this.isLoading = true;
        try {
            this.permissionSets = await getPermissionSets();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading permission sets',
                    message: this.extractErrorMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    handleSelect(event) {
        this.selectedId = event.detail.permissionSetId;
        this.selectedType = event.detail.permissionSetType;
    }

    handleMemberSelect(event) {
        // A Permission Set Group's member was clicked — drill into that PS.
        const memberId = event.detail.permissionSetId;
        if (!memberId) return;
        this.selectedId = memberId;
        this.selectedType = 'PermissionSet';
    }

    handleOpenInSetup() {
        if (!this.selectedId) return;
        const setupPath = this.selectedType === TYPE_GROUP
            ? 'PermSetGroups'
            : 'PermSets';
        this[NavigationMixin.Navigate](
            {
                type: 'standard__webPage',
                attributes: {
                    url: `/lightning/setup/${setupPath}/page?address=%2F${this.selectedId}`
                }
            },
            false
        );
    }

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (typeof error === 'string') return error;
        return JSON.stringify(error);
    }
}
