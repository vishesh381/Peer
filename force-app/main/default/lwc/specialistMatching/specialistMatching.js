import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSpecialistMatches from '@salesforce/apex/ReferralController.getSpecialistMatches';
import assignSpecialist from '@salesforce/apex/ReferralController.assignSpecialist';

export default class SpecialistMatching extends LightningElement {
    @api recordId;

    matches = [];
    isLoading = false;
    error;

    @wire(getSpecialistMatches, { recordId: '$recordId' })
    wiredMatches({ error, data }) {
        if (data) {
            this.matches = data.map((match) => ({
                ...match,
                capacityClass: this.getCapacityClass(match.capacityStatus),
                progressVariant: this.getProgressVariant(match.matchScore)
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.matches = [];
        }
    }

    get hasMatches() {
        return this.matches && this.matches.length > 0;
    }

    get hasError() {
        return this.error !== undefined;
    }

    get noMatches() {
        return !this.hasMatches;
    }

    get noError() {
        return !this.hasError;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get errorMessage() {
        if (!this.error) {
            return '';
        }
        return this.error.body?.message || this.error.message || 'An unknown error occurred';
    }

    getCapacityClass(status) {
        const statusLower = (status || '').toLowerCase();
        if (statusLower === 'available') {
            return 'capacity-badge capacity-available';
        } else if (statusLower === 'moderate') {
            return 'capacity-badge capacity-moderate';
        } else if (statusLower === 'high') {
            return 'capacity-badge capacity-high';
        }
        return 'capacity-badge';
    }

    getProgressVariant(score) {
        if (score >= 70) {
            return 'success';
        } else if (score >= 40) {
            return 'warning';
        }
        return 'error';
    }

    async handleAssign(event) {
        const resourceId = event.target.dataset.resourceId;
        const specialistName = event.target.dataset.specialistName;

        this.isLoading = true;

        try {
            await assignSpecialist({
                recordId: this.recordId,
                resourceId: resourceId
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `${specialistName} has been assigned successfully`,
                    variant: 'success'
                })
            );
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to assign specialist',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
}