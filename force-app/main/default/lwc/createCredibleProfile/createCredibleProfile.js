import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import pushToCredible from '@salesforce/apex/CredibleIntegrationService.pushToCredible';

const OPPORTUNITY_FIELDS = [
    'Opportunity.pstar__Patient_Admission__c',
    'Opportunity.Name'
];

const PATIENT_ADMISSION_FIELD = 'Opportunity.Patient_Admission__r.Credible_ID__c';

export default class CreateCredibleProfile extends NavigationMixin(LightningElement) {
    @api recordId;
    
    isLoading = false;
    opportunityName = '';
    patientAdmissionId = null;
    credibleId = null;
    hasError = false;
    errorMessage = '';

    @wire(getRecord, { 
        recordId: '$recordId', 
        fields: [OPPORTUNITY_FIELDS[0], OPPORTUNITY_FIELDS[1], PATIENT_ADMISSION_FIELD]
    })
    wiredOpportunity({ error, data }) {
        if (data) {
            this.opportunityName = getFieldValue(data, 'Opportunity.Name');
            this.patientAdmissionId = getFieldValue(data, 'Opportunity.pstar__Patient_Admission__c');
            
            try {
                this.credibleId = data.fields.Patient_Admission__r?.value?.fields?.Credible_ID__c?.value;
            } catch (e) {
                this.credibleId = null;
            }
            
            this.hasError = false;
            this.errorMessage = '';
        } else if (error) {
            this.hasError = true;
            this.errorMessage = 'Unable to load opportunity data.';
            console.error('Error loading opportunity:', error);
        }
    }

    get isButtonDisabled() {
        return this.isLoading || !this.patientAdmissionId || this.hasError;
    }

    get buttonLabel() {
        if (this.isLoading) return 'Creating Profile...';
        if (this.credibleId) return 'Profile Already Exists';
        if (!this.patientAdmissionId) return 'No Patient Admission';
        return 'Create Credible Profile';
    }

    get buttonVariant() {
        return this.credibleId ? 'success' : 'brand';
    }

    get showWarning() {
        return !this.patientAdmissionId;
    }

    get showAlreadyExists() {
        return this.credibleId;
    }

    handleCreateProfile() {
        if (!this.patientAdmissionId) {
            this.showToast(
                'Missing Information',
                'Please create a Patient Admission record first.',
                'warning'
            );
            return;
        }

        if (this.credibleId) {
            this.showToast(
                'Profile Already Exists',
                `Credible ID: ${this.credibleId}`,
                'info'
            );
            return;
        }

        if (!confirm('Create a Credible profile for this opportunity?')) {
            return;
        }

        this.isLoading = true;

        pushToCredible({ 
            patientAdmissionId: this.patientAdmissionId,
            opportunityId: this.recordId 
        })
            .then(result => this.handleSuccess(result))
            .catch(error => this.handleError(error))
            .finally(() => this.isLoading = false);
    }

    handleSuccess(result) {
        if (result === 'success') {
            this.showToast('Success!', 'Credible profile created successfully.', 'success');
            setTimeout(() => this.refreshPage(), 1500);
        } else if (result.startsWith('Warning:')) {
            this.showToast('Warning', result, 'warning');
            setTimeout(() => this.refreshPage(), 2000);
        } else if (result.startsWith('Error:')) {
            this.showToast('Error', result.replace('Error: ', ''), 'error');
        } else {
            this.showToast('Unexpected Response', result, 'warning');
        }
    }

    handleError(error) {
        console.error('Error:', error);
        
        let errorMessage = 'An unexpected error occurred.';
        
        if (error.body?.message) {
            errorMessage = error.body.message;
        } else if (error.message) {
            errorMessage = error.message;
        }

        this.showToast('Error', errorMessage, 'error');
    }

    handleViewPatientAdmission() {
        if (this.patientAdmissionId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.patientAdmissionId,
                    actionName: 'view'
                }
            });
        }
    }

    refreshPage() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        }));
    }
}