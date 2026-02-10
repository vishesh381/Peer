import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMyPeerVisits from '@salesforce/apex/SchedulingController.getMyPeerVisits';
import updateVisitStatus from '@salesforce/apex/SchedulingController.updateVisitStatus';

export default class PeerstarVisitsList extends NavigationMixin(LightningElement) {
    @track visits = [];
    @track isLoading = true;
    @track error;

    // Filter values
    @track selectedStatus = '';
    @track startDate;
    @track endDate;

    wiredVisitsResult;

    statusOptions = [
        { label: 'All Statuses', value: '' },
        { label: 'Pending', value: 'None' },
        { label: 'Confirmed', value: 'Scheduled' },
        { label: 'In Session', value: 'Dispatched' },
        { label: 'Complete', value: 'Completed' },
        { label: 'Missed', value: 'Cannot Complete' },
        { label: 'Canceled', value: 'Canceled' }
    ];

    connectedCallback() {
        // Default to this week
        const today = new Date();
        const startOfWeek = new Date(today);
        startOfWeek.setDate(today.getDate() - today.getDay());
        const endOfWeek = new Date(startOfWeek);
        endOfWeek.setDate(startOfWeek.getDate() + 6);

        this.startDate = startOfWeek.toISOString().split('T')[0];
        this.endDate = endOfWeek.toISOString().split('T')[0];
    }

    @wire(getMyPeerVisits, {
        startDate: '$startDate',
        endDate: '$endDate',
        statuses: '$statusList'
    })
    wiredVisits(result) {
        this.wiredVisitsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.visits = result.data.map(visit => ({
                ...visit,
                statusClass: this.getStatusClass(visit.status),
                formattedDateTime: this.formatDateTime(visit.scheduledStart)
            }));
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error.body?.message || 'Error loading visits';
            this.visits = [];
        }
    }

    get statusList() {
        return this.selectedStatus ? [this.selectedStatus] : null;
    }

    get hasVisits() {
        return this.visits && this.visits.length > 0;
    }

    get visitCount() {
        return this.visits ? this.visits.length : 0;
    }

    getStatusClass(status) {
        const statusMap = {
            'None': 'slds-badge slds-badge_lightest',
            'Scheduled': 'slds-badge slds-theme_success',
            'Dispatched': 'slds-badge slds-theme_warning',
            'Completed': 'slds-badge slds-theme_success',
            'Cannot Complete': 'slds-badge slds-theme_error',
            'Canceled': 'slds-badge slds-theme_inverse'
        };
        return statusMap[status] || 'slds-badge';
    }

    formatDateTime(dateTimeStr) {
        if (!dateTimeStr) return '';
        const dt = new Date(dateTimeStr);
        return dt.toLocaleDateString('en-US', {
            weekday: 'short',
            month: 'short',
            day: 'numeric',
            hour: 'numeric',
            minute: '2-digit'
        });
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.isLoading = true;
    }

    handleStartDateChange(event) {
        this.startDate = event.detail.value;
        this.isLoading = true;
    }

    handleEndDateChange(event) {
        this.endDate = event.detail.value;
        this.isLoading = true;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredVisitsResult);
    }

    handleViewVisit(event) {
        const visitId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: visitId,
                objectApiName: 'ServiceAppointment',
                actionName: 'view'
            }
        });
    }

    handleMarkComplete(event) {
        const visitId = event.currentTarget.dataset.id;
        this.isLoading = true;

        updateVisitStatus({ appointmentId: visitId, newStatus: 'Completed' })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Visit marked as complete',
                    variant: 'success'
                }));
                return refreshApex(this.wiredVisitsResult);
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Error updating visit',
                    variant: 'error'
                }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleViewParticipant(event) {
        const caseId = event.currentTarget.dataset.caseid;
        if (caseId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: caseId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
        }
    }
}