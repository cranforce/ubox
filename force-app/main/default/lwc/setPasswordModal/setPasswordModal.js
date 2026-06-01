import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import isSandboxOrg from '@salesforce/apex/UserManagementController.isSandboxOrg';
import setUserPassword from '@salesforce/apex/UserManagementController.setUserPassword';

const MIN_LENGTH = 8;
const GENERATED_LENGTH = 14;
const UPPER = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
const LOWER = 'abcdefghijkmnpqrstuvwxyz';
const DIGITS = '23456789';
const SYMBOLS = '!@#$%^&*-_=+';

export default class SetPasswordModal extends LightningModal {
    @api userId;
    @api userName;

    password = '';
    confirmPassword = '';
    isSandbox = true;
    isSubmitting = false;
    errorMessage = '';
    isDone = false;
    finalPassword = '';
    showPassword = false;

    get passwordInputType() {
        return this.showPassword ? 'text' : 'password';
    }

    handleToggleShow(event) {
        this.showPassword = event.target.checked;
    }

    connectedCallback() {
        isSandboxOrg()
            .then((result) => {
                this.isSandbox = result;
            })
            .catch(() => {
                // Leave the server-side guard authoritative if we can't determine it.
                this.isSandbox = true;
            });
    }

    get notSandbox() {
        return !this.isSandbox;
    }

    get setDisabled() {
        return this.isSubmitting || this.notSandbox;
    }

    handlePasswordChange(event) {
        this.password = event.target.value;
    }

    handleConfirmChange(event) {
        this.confirmPassword = event.target.value;
    }

    handleGenerate() {
        const generated = this.generatePassword();
        this.password = generated;
        this.confirmPassword = generated;
        const inputs = this.template.querySelectorAll('lightning-input[data-pwd], lightning-input[data-pwd-confirm]');
        inputs.forEach((i) => {
            i.value = generated;
        });
    }

    generatePassword() {
        const all = UPPER + LOWER + DIGITS + SYMBOLS;
        // Guarantee at least one character from each class.
        const required = [
            this.pick(UPPER),
            this.pick(LOWER),
            this.pick(DIGITS),
            this.pick(SYMBOLS)
        ];
        const chars = [...required];
        while (chars.length < GENERATED_LENGTH) {
            chars.push(this.pick(all));
        }
        return this.shuffle(chars).join('');
    }

    pick(set) {
        return set.charAt(this.randomInt(set.length));
    }

    randomInt(max) {
        const cryptoObj = window.crypto || window.msCrypto;
        if (cryptoObj && cryptoObj.getRandomValues) {
            const arr = new Uint32Array(1);
            cryptoObj.getRandomValues(arr);
            return arr[0] % max;
        }
        return Math.floor(Math.random() * max);
    }

    shuffle(arr) {
        for (let i = arr.length - 1; i > 0; i--) {
            const j = this.randomInt(i + 1);
            [arr[i], arr[j]] = [arr[j], arr[i]];
        }
        return arr;
    }

    handleCancel() {
        this.close(null);
    }

    handleDone() {
        this.close({ status: 'success' });
    }

    async handleCopy() {
        try {
            await navigator.clipboard.writeText(this.finalPassword);
        } catch (e) {
            // Clipboard may be unavailable; the value remains visible to copy manually.
        }
    }

    async handleSetPassword() {
        this.errorMessage = '';
        if (!this.password || this.password.length < MIN_LENGTH) {
            this.errorMessage = `Password must be at least ${MIN_LENGTH} characters.`;
            return;
        }
        if (this.password !== this.confirmPassword) {
            this.errorMessage = 'The password and confirmation must match.';
            return;
        }

        this.isSubmitting = true;
        try {
            await setUserPassword({ userId: this.userId, password: this.password });
            // Keep the modal open on a success screen so the admin can copy the
            // password — no email is sent, so they need it to relay to the user.
            this.finalPassword = this.password;
            this.isDone = true;
        } catch (error) {
            this.errorMessage = this.extractErrorMessage(error);
        } finally {
            this.isSubmitting = false;
        }
    }

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (typeof error === 'string') return error;
        return JSON.stringify(error);
    }
}
