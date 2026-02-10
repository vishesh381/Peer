import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import getOpportunityCredibleInfo from '@salesforce/apex/CredibleIntegrationService.getOpportunityCredibleInfo';
import pushToCredible from '@salesforce/apex/CredibleIntegrationService.pushToCredible';

export default class CredibleProfileWizard extends LightningElement {
    _recordId;
    _initialized = false;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value && !this._initialized) {
            this._initialized = true;
            this.initializeWizard();
        }
    }

    // State management
    currentStep = 'loading'; // loading, editForm, pushing, result
    credibleId;
    resultMessage = '';
    resultType = ''; // success, warning, error
    loadingMessage = 'Loading referral details...';

    async initializeWizard() {
        try {
            this.currentStep = 'loading';
            this.loadingMessage = 'Loading referral details...';

            const result = await getOpportunityCredibleInfo({ opportunityId: this.recordId });

            this.credibleId = result.credibleId;
            this.currentStep = 'editForm';
        } catch (error) {
            this.resultMessage = error.body?.message || error.message || 'Failed to load referral.';
            this.resultType = 'error';
            this.currentStep = 'result';
        }
    }

    handleRecordSaved() {
        // Opportunity saved successfully - now push to Credible
        this.doPushToCredible();
    }

    handleRecordError() {
        // The lightning-record-form handles its own error display
    }

    async doPushToCredible() {
        try {
            this.currentStep = 'pushing';

            const result = await pushToCredible({
                opportunityId: this.recordId
            });

            if (result === 'success') {
                this.resultType = 'success';
                this.resultMessage = 'Credible profile created successfully.';
            } else if (result.startsWith('Warning:')) {
                this.resultType = 'warning';
                this.resultMessage = result;
            } else if (result.startsWith('Error:')) {
                this.resultType = 'error';
                this.resultMessage = result.replace('Error: ', '');
            } else {
                this.resultType = 'warning';
                this.resultMessage = result;
            }

            this.currentStep = 'result';
        } catch (error) {
            this.resultType = 'error';
            this.resultMessage = error.body?.message || error.message || 'An unexpected error occurred.';
            this.currentStep = 'result';
        }
    }

    handleClose() {
        // Notify Lightning to refresh the record data
        notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
        // Close the quick action modal
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // --- Computed properties ---

    get panelHeader() {
        if (this.currentStep === 'loading') return 'Create Credible Profile';
        if (this.currentStep === 'editForm') {
            return this.hasCredibleId
                ? 'Edit Referral & Update Credible Profile'
                : 'Complete Referral & Push to Credible';
        }
        if (this.currentStep === 'pushing') return 'Pushing to Credible...';
        if (this.currentStep === 'result') {
            if (this.resultType === 'success') return 'Credible Profile Created';
            if (this.resultType === 'warning') return 'Credible Profile - Warning';
            return 'Credible Profile - Error';
        }
        return 'Create Credible Profile';
    }

    get isLoading() {
        return this.currentStep === 'loading';
    }

    get showEditForm() {
        return this.currentStep === 'editForm';
    }

    get isPushing() {
        return this.currentStep === 'pushing';
    }

    get showResult() {
        return this.currentStep === 'result';
    }

    get isSuccess() {
        return this.resultType === 'success';
    }

    get isWarning() {
        return this.resultType === 'warning';
    }

    get hasCredibleId() {
        return this.credibleId != null && this.credibleId !== '' && this.credibleId !== 'null';
    }
}
