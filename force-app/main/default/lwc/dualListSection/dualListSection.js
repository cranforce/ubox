import { LightningElement, api } from 'lwc';

export default class DualListSection extends LightningElement {
    @api label = '';
    @api sourceLabel = 'Available';
    @api selectedLabel = 'Selected';
    @api options = [];
    @api values = [];

    handleChange(event) {
        this.dispatchEvent(new CustomEvent('selectionchange', {
            detail: { value: event.detail.value }
        }));
    }
}
