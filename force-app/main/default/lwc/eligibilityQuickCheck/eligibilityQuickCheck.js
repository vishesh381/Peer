import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAuthorizationTimeline from '@salesforce/apex/ReferralController.getAuthorizationTimeline';
import verifyEligibility from '@salesforce/apex/ReferralController.verifyEligibility';

export default class EligibilityQuickCheck extends LightningElement {
    @api recordId;

    timelineData;
    wiredTimelineResult;
    isVerifying = false;
    error;

    @wire(getAuthorizationTimeline, { referralId: '$recordId' })
    wiredTimeline(result) {
        this.wiredTimelineResult = result;
        const { error, data } = result;
        if (data) {
            this.timelineData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.timelineData = undefined;
        }
    }

    get hasData() {
        return this.timelineData && !this.error;
    }

    get maId() {
        return this.timelineData?.maId || 'Not Available';
    }

    get isVerified() {
        return this.timelineData?.eligibilityVerified === true;
    }

    get statusLabel() {
        return this.isVerified ? 'Verified' : 'Not Verified';
    }

    get statusClass() {
        return this.isVerified ? 'status-badge verified' : 'status-badge not-verified';
    }

    get statusIconName() {
        return this.isVerified ? 'utility:check' : 'utility:close';
    }

    get lastVerifiedDate() {
        // If verified, we use the last modified date from events as a proxy
        if (this.isVerified && this.timelineData?.events) {
            const verifiedEvent = this.timelineData.events.find(
                (event) => event.label === 'Eligibility Verified'
            );
            if (verifiedEvent?.eventDate) {
                return this.formatDate(verifiedEvent.eventDate);
            }
        }
        return null;
    }

    get showLastVerified() {
        return this.isVerified && this.lastVerifiedDate;
    }

    get buttonLabel() {
        return this.isVerifying ? 'Verifying...' : 'Verify Eligibility';
    }

    get isButtonDisabled() {
        return this.isVerifying || this.isVerified;
    }

    formatDate(dateValue) {
        if (!dateValue) return '';
        const date = new Date(dateValue);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    async handleVerifyEligibility() {
        if (!this.recordId) {
            this.showToast('Error', 'No record ID available', 'error');
            return;
        }

        this.isVerifying = true;

        try {
            await verifyEligibility({ referralId: this.recordId });

            this.showToast(
                'Success',
                'Eligibility has been verified successfully',
                'success'
            );

            // Refresh the wire adapter to get updated data
            await refreshApex(this.wiredTimelineResult);
        } catch (error) {
            const errorMessage =
                error.body?.message || 'An error occurred while verifying eligibility';
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isVerifying = false;
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
}