import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import ELIGIBILITY_VERIFIED from '@salesforce/schema/Opportunity.Eligibility_Verified__c';
import ID_FIELD from '@salesforce/schema/Opportunity.Id';

const FIELDS = [ELIGIBILITY_VERIFIED];

export default class InsuranceVerification extends LightningElement {
    @api recordId;

    isModalOpen = false;
    isSaving = false;
    verificationStatus = 'Verified';
    notes = '';

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    record;

    get isVerified() {
        return getFieldValue(this.record.data, ELIGIBILITY_VERIFIED);
    }

    get statusOptions() {
        return [
            { label: 'Verified', value: 'Verified' },
            { label: 'Pending', value: 'Pending' },
            { label: 'Denied', value: 'Denied' }
        ];
    }

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg'];
    }

    openModal() {
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
    }

    handleStatusChange(event) {
        this.verificationStatus = event.detail.value;
    }

    handleNotesChange(event) {
        this.notes = event.detail.value;
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: `${uploadedFiles.length} file(s) uploaded`,
            variant: 'success'
        }));
    }

    async handleSave() {
        this.isSaving = true;
        try {
            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.recordId;
            fields[ELIGIBILITY_VERIFIED.fieldApiName] = this.verificationStatus === 'Verified';

            await updateRecord({ fields });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Insurance verification saved',
                variant: 'success'
            }));
            this.closeModal();
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'An error occurred',
                variant: 'error'
            }));
        } finally {
            this.isSaving = false;
        }
    }
}
