import { LightningElement, api, wire } from 'lwc';
import getAddressMetadata from '@salesforce/apex/UserManagementController.getAddressMetadata';

export default class UserInfoSection extends LightningElement {
    // State & Country Picklist (CCP) metadata, loaded once (cacheable).
    ccpEnabled = false;
    countryOptions = [];
    stateOptionsByCountry = {};

    @wire(getAddressMetadata)
    wiredAddressMetadata({ data }) {
        if (data) {
            this.ccpEnabled = data.stateCountryPicklistsEnabled;
            this.countryOptions = data.countryOptions || [];
            this.stateOptionsByCountry = data.stateOptionsByCountry || {};
        }
    }

    @api userData = {};
    // When true (Create User), Username/Alias auto-populate from Email and name.
    // Edit User sets this false so editing one field never mutates another.
    @api autoPopulate = false;
    @api userLicenseOptions = [];
    @api profileOptions = [];
    @api roleOptions = [];
    @api timezoneOptions = [];
    @api localeOptions = [];
    @api emailEncodingOptions = [];
    @api languageOptions = [];

    // Tracks whether username/alias have been manually edited by the user.
    // Cleared if the field is blanked out, allowing auto-fill to resume.
    _usernameManuallyEdited = false;
    _aliasManuallyEdited = false;

    get firstName() { return this.userData.FirstName || ''; }
    get lastName() { return this.userData.LastName || ''; }
    get email() { return this.userData.Email || ''; }
    get username() { return this.userData.Username || ''; }
    get alias() { return this.userData.Alias || ''; }
    get userLicenseId() { return this.userData.UserLicenseId || ''; }
    get profileId() { return this.userData.ProfileId || ''; }
    get userRoleId() { return this.userData.UserRoleId || ''; }
    get timeZoneSidKey() { return this.userData.TimeZoneSidKey || ''; }
    get localeSidKey() { return this.userData.LocaleSidKey || ''; }
    get emailEncodingKey() { return this.userData.EmailEncodingKey || ''; }
    get languageLocaleKey() { return this.userData.LanguageLocaleKey || ''; }
    get department() { return this.userData.Department || ''; }
    get title() { return this.userData.Title || ''; }
    get companyName() { return this.userData.CompanyName || ''; }

    // Address
    get street() { return this.userData.Street || ''; }
    get city() { return this.userData.City || ''; }
    get state() { return this.userData.State || ''; }
    get postalCode() { return this.userData.PostalCode || ''; }
    get country() { return this.userData.Country || ''; }

    // CCP picklist values (codes)
    get countryCode() { return this.userData.CountryCode || ''; }
    get stateCode() { return this.userData.StateCode || ''; }
    get stateOptions() { return this.stateOptionsByCountry[this.countryCode] || []; }
    get stateSelectDisabled() { return !this.countryCode || this.stateOptions.length === 0; }
    get isActive() { return this.userData.IsActive !== false; }

    // Feature licenses
    get marketingUser() { return this.userData.UserPermissionsMarketingUser === true; }
    get knowledgeUser() { return this.userData.UserPermissionsKnowledgeUser === true; }
    get interactionUser() { return this.userData.UserPermissionsInteractionUser === true; }
    get supportUser() { return this.userData.UserPermissionsSupportUser === true; }

    get sfContentUser() { return this.userData.UserPermissionsSFContentUser === true; }

    handleFieldChange(event) {
        const fieldName = event.target.dataset.field;
        let value;
        if (event.target.type === 'toggle' || event.target.type === 'checkbox') {
            value = event.target.checked;
        } else {
            value = event.detail.value;
        }

        // Track manual edits to username and alias so auto-fill doesn't override them.
        // If the user clears the field, allow auto-fill to resume.
        if (fieldName === 'Username') {
            this._usernameManuallyEdited = value.length > 0;
        }
        if (fieldName === 'Alias') {
            this._aliasManuallyEdited = value.length > 0;
        }

        this.dispatchChange(fieldName, value);

        // Changing country clears the dependent state selection (CCP orgs).
        if (fieldName === 'CountryCode') {
            this.dispatchChange('StateCode', '');
        }

        // Edit User disables auto-population so changing one field never
        // silently rewrites another (e.g. Email overwriting Username).
        if (!this.autoPopulate) {
            return;
        }

        // Auto-populate username and alias when email changes
        if (fieldName === 'Email') {
            if (!this._usernameManuallyEdited) {
                this.dispatchChange('Username', value);
            }
            if (!this._aliasManuallyEdited) {
                this.dispatchChange('Alias', this.generateAlias(
                    this.getFieldValue('FirstName'),
                    this.getFieldValue('LastName'),
                    value
                ));
            }
        }

        // Re-derive alias when first or last name changes
        if (fieldName === 'FirstName' || fieldName === 'LastName') {
            if (!this._aliasManuallyEdited) {
                const firstName = fieldName === 'FirstName' ? value : this.getFieldValue('FirstName');
                const lastName  = fieldName === 'LastName'  ? value : this.getFieldValue('LastName');
                this.dispatchChange('Alias', this.generateAlias(
                    firstName,
                    lastName,
                    this.getFieldValue('Email')
                ));
            }
        }
    }

    // Reads the current live value from a form field by data-field attribute.
    // Used to get sibling field values without waiting for the parent re-render cycle.
    getFieldValue(fieldName) {
        const el = this.template.querySelector(`[data-field="${fieldName}"]`);
        return el ? el.value : '';
    }

    // Mirrors Salesforce's standard alias generation:
    // first char of first name + last name (stripped of spaces), max 8 chars, lowercased.
    // Falls back to the email local-part if no name is available.
    generateAlias(firstName, lastName, email) {
        const fn = (firstName || '').trim();
        const ln = (lastName || '').trim().replace(/\s+/g, '');
        if (fn || ln) {
            return (fn.charAt(0) + ln).slice(0, 8).toLowerCase();
        }
        if (email) {
            return email.split('@')[0].replace(/[^a-zA-Z0-9]/g, '').slice(0, 8).toLowerCase();
        }
        return '';
    }

    dispatchChange(fieldName, value) {
        this.dispatchEvent(new CustomEvent('userchange', {
            detail: { fieldName, value }
        }));
    }

    @api
    validate() {
        const inputs = this.template.querySelectorAll('lightning-input, lightning-combobox');
        let isValid = true;
        inputs.forEach(input => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });
        return isValid;
    }
}
