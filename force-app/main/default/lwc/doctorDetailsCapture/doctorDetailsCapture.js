import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveDoctorDetails from '@salesforce/apex/ReferralController.saveDoctorDetails';

import PCP_NAME from '@salesforce/schema/Opportunity.Primary_Care_Physician__c';
import PCP_PHONE from '@salesforce/schema/Opportunity.PCP_Phone__c';
import PCP_ADDRESS from '@salesforce/schema/Opportunity.PCP_Address__c';
import PCP_EMAIL from '@salesforce/schema/Opportunity.PCP_Email__c';
import PSYCH_NAME from '@salesforce/schema/Opportunity.Psychiatrist__c';
import PSYCH_PHONE from '@salesforce/schema/Opportunity.Psychiatrist_Phone__c';
import PSYCH_ADDRESS from '@salesforce/schema/Opportunity.Psychiatrist_Address__c';
import PSYCH_EMAIL from '@salesforce/schema/Opportunity.Psychiatrist_Email__c';
import THERAPIST_NAME from '@salesforce/schema/Opportunity.Therapist_Name__c';
import THERAPIST_PHONE from '@salesforce/schema/Opportunity.Therapist_Phone__c';
import THERAPIST_ADDRESS from '@salesforce/schema/Opportunity.Therapist_Address__c';
import THERAPIST_EMAIL from '@salesforce/schema/Opportunity.Therapist_Email__c';

const FIELDS = [
    PCP_NAME, PCP_PHONE, PCP_ADDRESS, PCP_EMAIL,
    PSYCH_NAME, PSYCH_PHONE, PSYCH_ADDRESS, PSYCH_EMAIL,
    THERAPIST_NAME, THERAPIST_PHONE, THERAPIST_ADDRESS, THERAPIST_EMAIL
];

export default class DoctorDetailsCapture extends LightningElement {
    @api recordId;

    isModalOpen = false;
    isSaving = false;
    selectedType = '';
    modalName = '';
    modalPhone = '';
    modalAddress = '';
    modalEmail = '';

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    record;

    get pcpName() {
        return getFieldValue(this.record.data, PCP_NAME);
    }
    get pcpPhone() {
        return getFieldValue(this.record.data, PCP_PHONE);
    }
    get psychiatristName() {
        return getFieldValue(this.record.data, PSYCH_NAME);
    }
    get psychiatristPhone() {
        return getFieldValue(this.record.data, PSYCH_PHONE);
    }
    get therapistName() {
        return getFieldValue(this.record.data, THERAPIST_NAME);
    }
    get therapistPhone() {
        return getFieldValue(this.record.data, THERAPIST_PHONE);
    }

    get modalTitle() {
        return `${this.selectedType} Details`;
    }

    handleTileClick(event) {
        const type = event.currentTarget.dataset.type;
        this.selectedType = type;

        if (type === 'PCP') {
            this.modalName = getFieldValue(this.record.data, PCP_NAME) || '';
            this.modalPhone = getFieldValue(this.record.data, PCP_PHONE) || '';
            this.modalAddress = getFieldValue(this.record.data, PCP_ADDRESS) || '';
            this.modalEmail = getFieldValue(this.record.data, PCP_EMAIL) || '';
        } else if (type === 'Psychiatrist') {
            this.modalName = getFieldValue(this.record.data, PSYCH_NAME) || '';
            this.modalPhone = getFieldValue(this.record.data, PSYCH_PHONE) || '';
            this.modalAddress = getFieldValue(this.record.data, PSYCH_ADDRESS) || '';
            this.modalEmail = getFieldValue(this.record.data, PSYCH_EMAIL) || '';
        } else if (type === 'Therapist') {
            this.modalName = getFieldValue(this.record.data, THERAPIST_NAME) || '';
            this.modalPhone = getFieldValue(this.record.data, THERAPIST_PHONE) || '';
            this.modalAddress = getFieldValue(this.record.data, THERAPIST_ADDRESS) || '';
            this.modalEmail = getFieldValue(this.record.data, THERAPIST_EMAIL) || '';
        }

        this.isModalOpen = true;
    }

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        if (field === 'name') this.modalName = event.detail.value;
        else if (field === 'phone') this.modalPhone = event.detail.value;
        else if (field === 'address') this.modalAddress = event.detail.value;
        else if (field === 'email') this.modalEmail = event.detail.value;
    }

    async handleSave() {
        this.isSaving = true;
        try {
            await saveDoctorDetails({
                referralId: this.recordId,
                doctorType: this.selectedType,
                name: this.modalName,
                phone: this.modalPhone,
                address: this.modalAddress,
                email: this.modalEmail
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: `${this.selectedType} details saved successfully`,
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

    closeModal() {
        this.isModalOpen = false;
    }
}
