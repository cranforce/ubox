import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getUserFormMetadata from '@salesforce/apex/UserManagementController.getUserFormMetadata';
import getAvailablePermissionSets from '@salesforce/apex/UserManagementController.getAvailablePermissionSets';
import getAvailablePublicGroups from '@salesforce/apex/UserManagementController.getAvailablePublicGroups';
import getAvailablePermissionSetLicenses from '@salesforce/apex/UserManagementController.getAvailablePermissionSetLicenses';
import getAvailablePermissionSetGroups from '@salesforce/apex/UserManagementController.getAvailablePermissionSetGroups';
import getAvailablePackageLicenses from '@salesforce/apex/UserManagementController.getAvailablePackageLicenses';
import getCloneSourceData from '@salesforce/apex/UserManagementController.getCloneSourceData';
import createUser from '@salesforce/apex/UserManagementController.createUser';

export default class CreateUserForm extends NavigationMixin(LightningElement) {
    isLoading = true;
    hasLoaded = false;
    isSubmitting = false;
    showCloneLookup = false;

    userData = {};
    selectedPermissionSetIds = [];
    selectedPermSetGroupIds = [];
    selectedPermSetLicenseIds = [];
    selectedGroupIds = [];
    selectedPackageLicenseIds = [];

    userLicenseOptions = [];
    allProfileOptions = [];
    profileOptions = [];
    roleOptions = [];
    timezoneOptions = [];
    localeOptions = [];
    emailEncodingOptions = [];
    languageOptions = [];
    permissionSetOptions = [];
    permSetGroupOptions = [];
    permSetLicenseOptions = [];
    publicGroupOptions = [];
    packageLicenseOptions = [];

    activeSections = ['permSets', 'permSetGroups', 'permSetLicenses', 'groups', 'licenses'];

    get hasPermSetLicenseOptions() {
        return this.permSetLicenseOptions.length > 0;
    }

    get hasPackageLicenseOptions() {
        return this.packageLicenseOptions.length > 0;
    }

    connectedCallback() {
        this.loadFormData();
    }

    async loadFormData() {
        try {
            const [metadata, permSets, permSetGroups, permSetLicenses, groups, licenses] = await Promise.all([
                getUserFormMetadata(),
                getAvailablePermissionSets(),
                getAvailablePermissionSetGroups(),
                getAvailablePermissionSetLicenses(),
                getAvailablePublicGroups(),
                getAvailablePackageLicenses()
            ]);

            this.userLicenseOptions = metadata.userLicenseOptions;
            this.allProfileOptions = metadata.profileOptions;
            this.profileOptions = metadata.profileOptions;
            this.roleOptions = metadata.roleOptions;
            this.timezoneOptions = metadata.timezoneOptions;
            this.localeOptions = metadata.localeOptions;
            this.emailEncodingOptions = metadata.emailEncodingOptions;
            this.languageOptions = metadata.languageOptions;

            this.permissionSetOptions = permSets;
            this.permSetGroupOptions = permSetGroups;
            this.permSetLicenseOptions = permSetLicenses;
            this.publicGroupOptions = groups;
            this.packageLicenseOptions = licenses;

            this.resetForm();
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
            this.hasLoaded = true;
        }
    }

    resetForm() {
        this.userData = {
            IsActive: true,
            TimeZoneSidKey: 'America/Los_Angeles',
            LocaleSidKey: 'en_US',
            EmailEncodingKey: 'UTF-8',
            LanguageLocaleKey: 'en_US'
        };
        this.selectedPermissionSetIds = [];
        this.selectedPermSetGroupIds = [];
        this.selectedPermSetLicenseIds = [];
        this.selectedGroupIds = [];
        this.selectedPackageLicenseIds = [];
    }

    // --- Clone logic ---

    handleOpenCloneLookup() {
        this.showCloneLookup = true;
    }

    handleCancelClone() {
        this.showCloneLookup = false;
    }

    async handleCloneUserSelected(event) {
        const selectedUserId = event.detail.recordId;
        if (!selectedUserId) {
            return;
        }

        this.showCloneLookup = false;
        this.isLoading = true;

        try {
            const cloneData = await getCloneSourceData({ sourceUserId: selectedUserId });
            this.userData = { ...cloneData.user };
            this.selectedPermissionSetIds = [...cloneData.permissionSetIds];
            this.selectedPermSetGroupIds = [...cloneData.permSetGroupIds];
            this.selectedPermSetLicenseIds = [...cloneData.permSetLicenseIds];
            this.selectedGroupIds = [...cloneData.groupIds];
            this.selectedPackageLicenseIds = [...cloneData.packageLicenseIds];

            if (this.userData.UserLicenseId) {
                this.filterProfilesByLicense(this.userData.UserLicenseId);
            }

            this.showToast('Cloned', 'User data loaded. Fill in email, username, and alias before creating.', 'info');
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // --- Field change handlers ---

    handleUserFieldChange(event) {
        const { fieldName, value } = event.detail;
        this.userData = { ...this.userData, [fieldName]: value };

        if (fieldName === 'UserLicenseId') {
            this.filterProfilesByLicense(value);
        }
    }

    filterProfilesByLicense(userLicenseId) {
        if (userLicenseId) {
            this.profileOptions = this.allProfileOptions.filter(
                p => p.userLicenseId === userLicenseId
            );
        } else {
            this.profileOptions = [...this.allProfileOptions];
        }
        // Clear profile selection if it no longer matches the filtered list
        const currentProfileId = this.userData.ProfileId;
        if (currentProfileId) {
            const stillValid = this.profileOptions.some(p => p.value === currentProfileId);
            if (!stillValid) {
                this.userData = { ...this.userData, ProfileId: '' };
            }
        }
    }

    handlePermSetChange(event) {
        this.selectedPermissionSetIds = event.detail.value;
    }

    handlePermSetGroupChange(event) {
        this.selectedPermSetGroupIds = event.detail.value;
    }

    handleGroupChange(event) {
        this.selectedGroupIds = event.detail.value;
    }

    handlePermSetLicenseChange(event) {
        this.selectedPermSetLicenseIds = event.detail.value;
    }

    handleLicenseChange(event) {
        this.selectedPackageLicenseIds = event.detail.value;
    }

    // --- Create ---

    async handleCreate() {
        const userInfoSection = this.template.querySelector('c-user-info-section');
        if (userInfoSection && !userInfoSection.validate()) {
            this.showToast('Validation Error', 'Please fill in all required fields.', 'error');
            return;
        }

        this.isSubmitting = true;
        try {
            const userId = await createUser({
                userData: this.userData,
                permissionSetIds: this.selectedPermissionSetIds,
                groupIds: this.selectedGroupIds,
                packageLicenseIds: this.selectedPackageLicenseIds,
                permSetLicenseIds: this.selectedPermSetLicenseIds,
                permSetGroupIds: this.selectedPermSetGroupIds
            });

            this.showToast(
                'Success',
                'User created successfully. Permission sets, groups, and licenses are being assigned in the background.',
                'success'
            );

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: userId,
                    objectApiName: 'User',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.showToast('Error Creating User', this.extractErrorMessage(error), 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    // --- Utilities ---

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'An unexpected error occurred.';
    }
}
