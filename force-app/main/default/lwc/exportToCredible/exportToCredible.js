import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import pushToCredible from '@salesforce/apex/CredibleIntegrationService.pushToCredible';

export default class ExportToCredible extends NavigationMixin(LightningElement) {
    // Inputs from Flow
    @api patientAdmissionId;
    @api recordId; // Opportunity ID
    @api shouldNavigate = false;

    // Component state
    isLoading = false;
    isSuccess = false;
    isError = false;
    message = '';
    credibleId = '';

    connectedCallback() {
        // Auto-start the push when component loads
        this.handlePushToCredible();
    }

    handlePushToCredible() {
        if (!this.patientAdmissionId) {
            this.showError('Patient Admission ID is required');
            return;
        }

        this.isLoading = true;
        this.isError = false;
        this.isSuccess = false;
        this.message = 'Connecting to Credible...';

        pushToCredible({ 
            patientAdmissionId: this.patientAdmissionId,
            opportunityId: this.recordId 
        })
            .then(result => {
                this.handleSuccess(result);
            })
            .catch(error => {
                this.handleError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleSuccess(result) {
        if (result === 'success') {
            this.isSuccess = true;
            this.message = 'Credible profile created successfully!';
            this.showToast('Success', this.message, 'success');
            
            // Navigate to Opportunity if shouldNavigate is true
            if (this.shouldNavigate && this.recordId) {
                setTimeout(() => {
                    this.navigateToRecord(this.recordId);
                }, 2000);
            }
        } else if (result.startsWith('Warning:')) {
            this.isSuccess = true;
            this.message = result;
            this.showToast('Warning', result, 'warning');
            
            if (this.shouldNavigate && this.recordId) {
                setTimeout(() => {
                    this.navigateToRecord(this.recordId);
                }, 2500);
            }
        } else if (result.startsWith('Error:')) {
            this.showError(result.replace('Error: ', ''));
        } else {
            this.showError(result);
        }
    }

    handleError(error) {
        console.error('Error:', error);
        
        let errorMessage = 'An unexpected error occurred while creating the Credible profile.';
        
        if (error.body?.message) {
            errorMessage = error.body.message;
        } else if (error.message) {
            errorMessage = error.message;
        }

        this.showError(errorMessage);
    }

    showError(errorMessage) {
        this.isError = true;
        this.isSuccess = false;
        this.message = errorMessage;
        this.showToast('Error', errorMessage, 'error');
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'sticky'
        }));
    }

    // Retry button handler
    handleRetry() {
        this.handlePushToCredible();
    }
}