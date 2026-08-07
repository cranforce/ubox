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
import prepareImport from '@salesforce/apex/UserManagementController.prepareImport';
import createUser from '@salesforce/apex/UserManagementController.createUser';

export default class CreateUserForm extends NavigationMixin(LightningElement) {
    isLoading = true;
    hasLoaded = false;
    isSubmitting = false;
    // Create User auto-fills Username/Alias from Email and name.
    autoPopulate = true;
    showCloneLookup = false;
    showImportPaste = false;
    importPasteValue = '';
    importWarnings = null;

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

    get hasImportWarnings() {
        return this.importWarnings != null;
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

    // --- Import logic ---

    handleImportClick() {
        const input = this.template.querySelector('input.import-file-input');
        if (input) {
            input.click();
        }
    }

    handleImportFileChange(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        const reader = new FileReader();
        reader.onload = () => {
            this.applyImport(reader.result);
            // Reset so re-selecting the same file fires change again.
            event.target.value = null;
        };
        reader.onerror = () => {
            this.showToast('Error', 'Could not read the selected file.', 'error');
        };
        reader.readAsText(file);
    }

    handleOpenImportPaste() {
        this.importPasteValue = '';
        this.showImportPaste = true;
    }

    handleCancelImportPaste() {
        this.showImportPaste = false;
    }

    handleImportPasteChange(event) {
        this.importPasteValue = event.target.value;
    }

    handleImportPasteConfirm() {
        if (!this.importPasteValue) {
            this.showToast('Error', 'Paste a user definition first.', 'error');
            return;
        }
        this.showImportPaste = false;
        this.applyImport(this.importPasteValue);
    }

    async applyImport(definitionJson) {
        this.isLoading = true;
        try {
            const res = await prepareImport({ definitionJson });
            this.userData = { ...res.user };
            this.selectedPermissionSetIds = [...res.permissionSetIds];
            this.selectedPermSetGroupIds = [...res.permSetGroupIds];
            this.selectedPermSetLicenseIds = [...res.permSetLicenseIds];
            this.selectedGroupIds = [...res.groupIds];
            this.selectedPackageLicenseIds = [...res.packageLicenseIds];

            if (this.userData.UserLicenseId) {
                this.filterProfilesByLicense(this.userData.UserLicenseId);
            }

            this.importWarnings = this.buildImportWarnings(res);
            this.showToast(
                'Imported',
                'Definition loaded. Set email, username, and alias before creating.',
                'success'
            );
        } catch (error) {
            this.showToast('Import Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Flattens the Apex `unresolved`/`originals` payload into a template-friendly
    // shape (keyed items for for:each). Returns null when there's nothing to show.
    buildImportWarnings(res) {
        const unresolved = res.unresolved || {};
        const groups = [];
        const addGroup = (title, items) => {
            if (items && items.length) {
                groups.push({
                    key: title,
                    title,
                    items: items.map((label, i) => ({ id: `${title}-${i}`, label }))
                });
            }
        };
        if (unresolved.profile) {
            addGroup('Profile — pick one manually', [unresolved.profile]);
        }
        if (unresolved.role) {
            addGroup('Role', [unresolved.role]);
        }
        addGroup('Permission Sets', unresolved.permissionSets);
        addGroup('Permission Set Groups', unresolved.permissionSetGroups);
        addGroup('Permission Set Licenses', unresolved.permSetLicenses);
        addGroup('Public Groups', unresolved.publicGroups);
        addGroup('Package Licenses', unresolved.packageLicenses);

        const originals = res.originals || {};
        const hasOriginals = originals.email || originals.username || originals.alias;
        if (!groups.length && !hasOriginals) {
            return null;
        }
        return { groups, originals, hasUnresolved: groups.length > 0 };
    }

    handleDismissWarnings() {
        this.importWarnings = null;
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
        if (error?.body?.output?.errors?.length) {
            return error.body.output.errors.map(e => e.message).join('; ');
        }
        if (error?.body?.pageErrors?.length) {
            return error.body.pageErrors.map(e => e.message).join('; ');
        }
        if (error?.body?.fieldErrors) {
            const msgs = Object.values(error.body.fieldErrors)
                .flat()
                .map(e => e.message);
            if (msgs.length) return msgs.join('; ');
        }
        if (error?.message) return error.message;
        if (typeof error === 'string') return error;
        return JSON.stringify(error);
    }
}
