import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getVisitDetails from '@salesforce/apex/SchedulingController.getVisitDetails';
import checkInVisit from '@salesforce/apex/SchedulingController.checkInVisit';
import checkOutVisit from '@salesforce/apex/SchedulingController.checkOutVisit';
import saveVisitNotes from '@salesforce/apex/SchedulingController.saveVisitNotes';
import submitForReview from '@salesforce/apex/SchedulingController.submitForReview';
import updateVisitStatus from '@salesforce/apex/SchedulingController.updateVisitStatus';

export default class PeerstarVisitActions extends LightningElement {
    @api recordId;
    @track visitDetails;
    @track isLoading = false;
    @track showNotesModal = false;
    @track notesContent = '';
    @track selectedStatus = '';

    wiredVisitResult;

    statusOptions = [
        { label: 'Pending', value: 'None' },
        { label: 'Scheduled', value: 'Scheduled' },
        { label: 'Confirmed', value: 'Dispatched' },
        { label: 'In Session', value: 'In Progress' },
        { label: 'Visit Complete', value: 'Completed' },
        { label: 'Missed', value: 'Cannot Complete' },
        { label: 'Canceled', value: 'Canceled' }
    ];

    @wire(getVisitDetails, { visitId: '$recordId' })
    wiredVisit(result) {
        this.wiredVisitResult = result;
        if (result.data) {
            this.visitDetails = result.data;
            this.selectedStatus = result.data.status;
            this.notesContent = result.data.visitNotes || '';
        } else if (result.error) {
            this.showError('Error loading visit details', result.error);
        }
    }

    // Getters for UI state
    get canCheckIn() {
        return this.visitDetails?.canCheckIn;
    }

    get canCheckOut() {
        return this.visitDetails?.canCheckOut;
    }

    get canSubmitForReview() {
        return this.visitDetails?.canSubmitForReview;
    }

    get isCheckedIn() {
        return this.visitDetails?.checkInTime != null;
    }

    get isCompleted() {
        return this.visitDetails?.status === 'Completed';
    }

    get checkInTimeFormatted() {
        if (!this.visitDetails?.checkInTime) return '';
        return new Date(this.visitDetails.checkInTime).toLocaleTimeString();
    }

    get checkOutTimeFormatted() {
        if (!this.visitDetails?.checkOutTime) return '';
        return new Date(this.visitDetails.checkOutTime).toLocaleTimeString();
    }

    get actualDurationFormatted() {
        if (!this.visitDetails?.actualDuration) return '';
        const mins = Math.round(this.visitDetails.actualDuration);
        const hours = Math.floor(mins / 60);
        const remainingMins = mins % 60;
        if (hours > 0) {
            return `${hours}h ${remainingMins}m`;
        }
        return `${mins} minutes`;
    }

    get reviewStatusBadgeClass() {
        const status = this.visitDetails?.reviewStatus;
        if (status === 'Approved') return 'slds-badge slds-theme_success';
        if (status === 'Needs Revision') return 'slds-badge slds-theme_error';
        if (status === 'Pending Review') return 'slds-badge slds-theme_warning';
        return 'slds-badge';
    }

    get hasRevisionNotes() {
        return this.visitDetails?.revisionNotes && this.visitDetails?.reviewStatus === 'Needs Revision';
    }

    // Actions
    async handleCheckIn() {
        this.isLoading = true;
        try {
            // Get GPS location
            const position = await this.getCurrentPosition();
            const latitude = position?.coords?.latitude || null;
            const longitude = position?.coords?.longitude || null;

            await checkInVisit({
                visitId: this.recordId,
                latitude: latitude,
                longitude: longitude
            });

            this.showSuccess('Checked in successfully!');
            await refreshApex(this.wiredVisitResult);
        } catch (error) {
            this.showError('Check-in failed', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleCheckOut() {
        this.isLoading = true;
        try {
            // Get GPS location
            const position = await this.getCurrentPosition();
            const latitude = position?.coords?.latitude || null;
            const longitude = position?.coords?.longitude || null;

            const result = await checkOutVisit({
                visitId: this.recordId,
                latitude: latitude,
                longitude: longitude
            });

            const duration = result.actualDuration;
            const message = duration
                ? `Checked out! Visit duration: ${Math.round(duration)} minutes`
                : 'Checked out successfully!';
            this.showSuccess(message);
            await refreshApex(this.wiredVisitResult);
        } catch (error) {
            this.showError('Check-out failed', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.updateStatus();
    }

    async updateStatus() {
        this.isLoading = true;
        try {
            await updateVisitStatus({
                visitId: this.recordId,
                newStatus: this.selectedStatus
            });
            this.showSuccess('Status updated');
            await refreshApex(this.wiredVisitResult);
        } catch (error) {
            this.showError('Failed to update status', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleOpenNotes() {
        this.showNotesModal = true;
    }

    handleCloseNotes() {
        this.showNotesModal = false;
    }

    handleNotesChange(event) {
        this.notesContent = event.target.value;
    }

    async handleSaveNotes() {
        this.isLoading = true;
        try {
            await saveVisitNotes({
                visitId: this.recordId,
                notes: this.notesContent
            });
            this.showSuccess('Notes saved');
            this.showNotesModal = false;
            await refreshApex(this.wiredVisitResult);
        } catch (error) {
            this.showError('Failed to save notes', error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSubmitForReview() {
        this.isLoading = true;
        try {
            await submitForReview({ visitId: this.recordId });
            this.showSuccess('Submitted for supervisor review');
            await refreshApex(this.wiredVisitResult);
        } catch (error) {
            this.showError('Failed to submit for review', error);
        } finally {
            this.isLoading = false;
        }
    }

    // Helpers
    getCurrentPosition() {
        return new Promise((resolve, reject) => {
            if (!navigator.geolocation) {
                resolve(null);
                return;
            }
            navigator.geolocation.getCurrentPosition(
                (position) => resolve(position),
                (error) => {
                    console.warn('GPS not available:', error.message);
                    resolve(null);
                },
                { enableHighAccuracy: true, timeout: 10000, maximumAge: 60000 }
            );
        });
    }

    showSuccess(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: message,
            variant: 'success'
        }));
    }

    showError(title, error) {
        const message = error?.body?.message || error?.message || 'Unknown error';
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: 'error'
        }));
    }
}