import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getPendingReviewVisits from '@salesforce/apex/SchedulingController.getPendingReviewVisits';
import reviewVisit from '@salesforce/apex/SchedulingController.reviewVisit';

export default class PeerstarReviewQueue extends NavigationMixin(LightningElement) {
    @track visits = [];
    @track isLoading = true;
    @track error;

    // Modal state
    @track showReviewModal = false;
    @track selectedVisit = null;
    @track isApproving = false;
    @track revisionNotes = '';
    @track isSubmitting = false;

    wiredVisitsResult;

    @wire(getPendingReviewVisits)
    wiredVisits(result) {
        this.wiredVisitsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.visits = result.data.map(v => ({
                ...v,
                formattedDate: v.scheduledStart ?
                    new Date(v.scheduledStart).toLocaleDateString('en-US', {
                        month: 'short', day: 'numeric', year: 'numeric',
                        hour: 'numeric', minute: '2-digit'
                    }) : 'Not scheduled',
                formattedCheckIn: v.checkInTime ?
                    new Date(v.checkInTime).toLocaleTimeString('en-US', {
                        hour: 'numeric', minute: '2-digit'
                    }) : '-',
                formattedCheckOut: v.checkOutTime ?
                    new Date(v.checkOutTime).toLocaleTimeString('en-US', {
                        hour: 'numeric', minute: '2-digit'
                    }) : '-',
                durationDisplay: v.actualDuration ? v.actualDuration + ' min' : '-',
                hasNotes: v.visitNotes && v.visitNotes.length > 0
            }));
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.visits = [];
        }
    }

    get hasVisits() {
        return this.visits && this.visits.length > 0;
    }

    get visitCount() {
        return this.visits.length;
    }

    get modalTitle() {
        return this.isApproving ? 'Approve Visit Documentation' : 'Request Revision';
    }

    get submitButtonLabel() {
        return this.isApproving ? 'Approve' : 'Request Revision';
    }

    get submitButtonVariant() {
        return this.isApproving ? 'brand' : 'destructive';
    }

    get showRevisionNotes() {
        return !this.isApproving;
    }

    handleViewVisit(event) {
        const visitId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: visitId,
                actionName: 'view'
            }
        });
    }

    handleApprove(event) {
        const visitId = event.currentTarget.dataset.id;
        this.selectedVisit = this.visits.find(v => v.id === visitId);
        this.isApproving = true;
        this.revisionNotes = '';
        this.showReviewModal = true;
    }

    handleRequestRevision(event) {
        const visitId = event.currentTarget.dataset.id;
        this.selectedVisit = this.visits.find(v => v.id === visitId);
        this.isApproving = false;
        this.revisionNotes = '';
        this.showReviewModal = true;
    }

    handleRevisionNotesChange(event) {
        this.revisionNotes = event.target.value;
    }

    handleCloseModal() {
        this.showReviewModal = false;
        this.selectedVisit = null;
        this.revisionNotes = '';
    }

    async handleSubmitReview() {
        // Validate revision notes if requesting revision
        if (!this.isApproving && !this.revisionNotes.trim()) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please provide revision notes explaining what needs to be corrected.',
                    variant: 'error'
                })
            );
            return;
        }

        this.isSubmitting = true;

        try {
            await reviewVisit({
                visitId: this.selectedVisit.id,
                approved: this.isApproving,
                revisionNotes: this.revisionNotes
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: this.isApproving
                        ? 'Visit documentation approved.'
                        : 'Revision requested. Specialist will be notified.',
                    variant: 'success'
                })
            );

            this.handleCloseModal();
            await refreshApex(this.wiredVisitsResult);

        } catch (error) {
            console.error('Error submitting review:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to submit review.',
                    variant: 'error'
                })
            );
        } finally {
            this.isSubmitting = false;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        await refreshApex(this.wiredVisitsResult);
        this.isLoading = false;
    }
}