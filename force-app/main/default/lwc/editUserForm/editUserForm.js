import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import SetPasswordModal from 'c/setPasswordModal';
import getUserFormMetadata from '@salesforce/apex/UserManagementController.getUserFormMetadata';
import getAvailablePermissionSets from '@salesforce/apex/UserManagementController.getAvailablePermissionSets';
import getAvailablePublicGroups from '@salesforce/apex/UserManagementController.getAvailablePublicGroups';
import getAvailablePermissionSetLicenses from '@salesforce/apex/UserManagementController.getAvailablePermissionSetLicenses';
import getAvailablePermissionSetGroups from '@salesforce/apex/UserManagementController.getAvailablePermissionSetGroups';
import getAvailablePackageLicenses from '@salesforce/apex/UserManagementController.getAvailablePackageLicenses';
import getAllUsers from '@salesforce/apex/UserManagementController.getAllUsers';
import getEditUserData from '@salesforce/apex/UserManagementController.getEditUserData';
import exportUserDefinition from '@salesforce/apex/UserManagementController.exportUserDefinition';
import prepareImport from '@salesforce/apex/UserManagementController.prepareImport';
import updateUser from '@salesforce/apex/UserManagementController.updateUser';

export default class EditUserForm extends NavigationMixin(LightningElement) {
    isLoading = true;
    hasLoaded = false;
    isSubmitting = false;
    selectedUserId = null;
    activeTab = 'details';
    showExportFallback = false;
    exportJson = '';
    showImportPaste = false;
    importPasteValue = '';
    importWarnings = null;

    allUsers = [];

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

    get hasImportWarnings() {
        return this.importWarnings != null;
    }

    get selectedUserName() {
        const u = this.allUsers.find(x => x.id === this.selectedUserId);
        return u ? u.name : '';
    }

    connectedCallback() {
        this.loadFormData();
    }

    async loadFormData() {
        try {
            const [metadata, permSets, permSetGroups, permSetLicenses, groups, licenses, users] = await Promise.all([
                getUserFormMetadata(),
                getAvailablePermissionSets(),
                getAvailablePermissionSetGroups(),
                getAvailablePermissionSetLicenses(),
                getAvailablePublicGroups(),
                getAvailablePackageLicenses(),
                getAllUsers()
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
            this.allUsers = users;
        } catch (error) {
            this.showToast('Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
            this.hasLoaded = true;
        }
    }

    async handleUserSelected(event) {
        // Clear any import state from a previously selected user.
        this.importWarnings = null;
        this.showImportPaste = false;

        const userId = event.detail.userId;
        if (!userId) {
            this.selectedUserId = null;
            this.userData = {};
            this.selectedPermissionSetIds = [];
            this.selectedPermSetGroupIds = [];
            this.selectedPermSetLicenseIds = [];
            this.selectedGroupIds = [];
            this.selectedPackageLicenseIds = [];
            return;
        }

        this.selectedUserId = userId;
        this.isLoading = true;

        try {
            const editData = await getEditUserData({ userId });
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

    async handleExport() {
        this.isLoading = true;
        try {
            const envelope = await exportUserDefinition({ userId: this.selectedUserId });
            const json = JSON.stringify(envelope, null, 2);
            const lastName = ((envelope && envelope.source && envelope.source.userLabel) || 'user')
                .split(',')[0]
                .trim()
                .replace(/[^a-z0-9]+/gi, '-') || 'user';
            const filename = `ubox-user-${lastName}-${Date.now()}.json`;

            if (this.downloadJson(json, filename)) {
                this.showToast('Exported', 'User definition downloaded.', 'success');
            } else {
                // Browser/Locker blocked the download — offer copy-paste instead.
                this.exportJson = json;
                this.showExportFallback = true;
            }
        } catch (error) {
            this.showToast('Export Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    downloadJson(json, filename) {
        try {
            const blob = new Blob([json], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const anchor = document.createElement('a');
            anchor.href = url;
            anchor.download = filename;
            anchor.style.display = 'none';
            document.body.appendChild(anchor);
            anchor.click();
            document.body.removeChild(anchor);
            URL.revokeObjectURL(url);
            return true;
        } catch (e) {
            return false;
        }
    }

    handleCloseExportFallback() {
        this.showExportFallback = false;
    }

    // --- Import logic (applies a definition's permissions to the loaded user) ---
    // Scope: permission assignments only — user fields/identity are never touched.
    // Merge: add-only — imported assignments are unioned onto the current
    // selections and never removed. The admin reviews the dual-lists and clicks
    // Save Changes to apply (updateUser diffs and assigns).

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
            // Permissions-only, add-only: union resolved Ids into current selections
            // without touching userData (name/profile/identity stay as loaded).
            this.selectedPermissionSetIds = this.mergeIds(this.selectedPermissionSetIds, res.permissionSetIds);
            this.selectedPermSetGroupIds = this.mergeIds(this.selectedPermSetGroupIds, res.permSetGroupIds);
            this.selectedPermSetLicenseIds = this.mergeIds(this.selectedPermSetLicenseIds, res.permSetLicenseIds);
            this.selectedGroupIds = this.mergeIds(this.selectedGroupIds, res.groupIds);
            this.selectedPackageLicenseIds = this.mergeIds(this.selectedPackageLicenseIds, res.packageLicenseIds);

            this.importWarnings = this.buildImportWarnings(res);
            this.showToast(
                'Imported',
                "Permissions from the definition were added to this user's selections. Review and click Save Changes to apply.",
                'success'
            );
        } catch (error) {
            this.showToast('Import Error', this.extractErrorMessage(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Union two Id arrays into a new array (new reference so the dual-list re-renders).
    mergeIds(current, incoming) {
        const set = new Set(current || []);
        (incoming || []).forEach(id => set.add(id));
        return [...set];
    }

    // Edit import only touches assignments, so the warnings panel lists just the
    // unresolved assignment categories (no profile/role or identity hints).
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
        addGroup('Permission Sets', unresolved.permissionSets);
        addGroup('Permission Set Groups', unresolved.permissionSetGroups);
        addGroup('Permission Set Licenses', unresolved.permSetLicenses);
        addGroup('Public Groups', unresolved.publicGroups);
        addGroup('Package Licenses', unresolved.packageLicenses);
        return groups.length ? { groups } : null;
    }

    handleDismissWarnings() {
        this.importWarnings = null;
    }

    async handleSetPassword() {
        const result = await SetPasswordModal.open({
            size: 'small',
            userId: this.selectedUserId,
            userName: this.selectedUserName
        });
        if (result?.status === 'success') {
            this.showToast(
                'Password set',
                `Password updated for ${this.selectedUserName}.`,
                'success'
            );
        }
    }

    handleTabActive(event) {
        this.activeTab = event.target.value;
    }

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
