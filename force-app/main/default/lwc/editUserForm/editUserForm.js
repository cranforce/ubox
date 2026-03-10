import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getUserFormMetadata from '@salesforce/apex/UserManagementController.getUserFormMetadata';
import getAvailablePermissionSets from '@salesforce/apex/UserManagementController.getAvailablePermissionSets';
import getAvailablePublicGroups from '@salesforce/apex/UserManagementController.getAvailablePublicGroups';
import getAvailablePermissionSetLicenses from '@salesforce/apex/UserManagementController.getAvailablePermissionSetLicenses';
import getAvailablePermissionSetGroups from '@salesforce/apex/UserManagementController.getAvailablePermissionSetGroups';
import getAvailablePackageLicenses from '@salesforce/apex/UserManagementController.getAvailablePackageLicenses';
import getEditUserData from '@salesforce/apex/UserManagementController.getEditUserData';
import updateUser from '@salesforce/apex/UserManagementController.updateUser';

export default class EditUserForm extends NavigationMixin(LightningElement) {
    isLoading = true;
    hasLoaded = false;
    isSubmitting = false;
    selectedUserId = null;

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

    get hasUserSelected() {
        return this.selectedUserId != null;
    }

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
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
            this.hasLoaded = true;
        }
    }

    async handleUserSelected(event) {
        const recordId = event.detail.recordId;
        if (!recordId) {
            this.selectedUserId = null;
            this.userData = {};
            this.selectedPermissionSetIds = [];
            this.selectedPermSetGroupIds = [];
            this.selectedPermSetLicenseIds = [];
            this.selectedGroupIds = [];
            this.selectedPackageLicenseIds = [];
            return;
        }

        this.selectedUserId = recordId;
        this.isLoading = true;

        try {
            const editData = await getEditUserData({ userId: recordId });
            this.userData = { ...editData.user };
            this.selectedPermissionSetIds = [...editData.permissionSetIds];
            this.selectedPermSetGroupIds = [...editData.permSetGroupIds];
            this.selectedPermSetLicenseIds = [...editData.permSetLicenseIds];
            this.selectedGroupIds = [...editData.groupIds];
            this.selectedPackageLicenseIds = [...editData.packageLicenseIds];

            if (this.userData.UserLicenseId) {
                this.filterProfilesByLicense(this.userData.UserLicenseId);
            }
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleOpenUserRecord() {
        window.open('/lightning/r/User/' + encodeURIComponent(this.selectedUserId) + '/view', '_blank');
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

    // --- Save ---

    async handleSave() {
        const userInfoSection = this.template.querySelector('c-user-info-section');
        if (userInfoSection && !userInfoSection.validate()) {
            this.showToast('Validation Error', 'Please fill in all required fields.', 'error');
            return;
        }

        this.isSubmitting = true;
        try {
            await updateUser({
                userId: this.selectedUserId,
                userData: this.userData,
                permissionSetIds: this.selectedPermissionSetIds,
                permSetGroupIds: this.selectedPermSetGroupIds,
                permSetLicenseIds: this.selectedPermSetLicenseIds,
                groupIds: this.selectedGroupIds,
                packageLicenseIds: this.selectedPackageLicenseIds
            });

            this.showToast(
                'Success',
                'User updated successfully. Assignment changes are being processed in the background.',
                'success'
            );
        } catch (error) {
            this.showToast('Error Updating User', this.extractErrorMessage(error), 'error');
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
