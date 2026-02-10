import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDayRouteVisits from '@salesforce/apex/SchedulingController.getDayRouteVisits';
import updateVisitTime from '@salesforce/apex/SchedulingController.updateVisitTime';

export default class PeerstarRoutePlanner extends NavigationMixin(LightningElement) {
    @track visits = [];
    @track isLoading = true;
    @track error;
    @track selectedDate;

    // Time edit modal
    @track showTimeModal = false;
    @track editingVisit = null;
    @track newTime = '';
    @track isUpdating = false;

    wiredVisitsResult;

    connectedCallback() {
        // Default to today
        this.selectedDate = this.formatDate(new Date());
    }

    formatDate(date) {
        return date.toISOString().split('T')[0];
    }

    @wire(getDayRouteVisits, { targetDate: '$selectedDate', specialistId: null })
    wiredVisits(result) {
        this.wiredVisitsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.visits = result.data.map((v, index) => ({
                ...v,
                isFirst: index === 0,
                isLast: index === result.data.length - 1,
                statusClass: this.getStatusClass(v.status),
                hasAddress: v.fullAddress && v.fullAddress.length > 0
            }));
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.visits = [];
        }
    }

    getStatusClass(status) {
        const classes = {
            'Completed': 'slds-badge slds-theme_success',
            'In Progress': 'slds-badge slds-theme_warning',
            'Scheduled': 'slds-badge slds-theme_info',
            'Dispatched': 'slds-badge slds-theme_info'
        };
        return classes[status] || 'slds-badge';
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value;
    }

    setToday() {
        this.selectedDate = this.formatDate(new Date());
    }

    setTomorrow() {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        this.selectedDate = this.formatDate(tomorrow);
    }

    handleVisitClick(event) {
        const visitId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: visitId,
                actionName: 'view'
            }
        });
    }

    handleGetDirections(event) {
        event.stopPropagation();
        const mapsUrl = event.currentTarget.dataset.url;
        if (mapsUrl) {
            window.open(mapsUrl, '_blank');
        }
    }

    handleEditTime(event) {
        event.stopPropagation();
        const visitId = event.currentTarget.dataset.id;
        this.editingVisit = this.visits.find(v => v.visitId === visitId);

        // Extract time from scheduled start
        if (this.editingVisit.scheduledStart) {
            const date = new Date(this.editingVisit.scheduledStart);
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');
            this.newTime = `${hours}:${minutes}`;
        }

        this.showTimeModal = true;
    }

    handleTimeChange(event) {
        this.newTime = event.target.value;
    }

    handleCloseTimeModal() {
        this.showTimeModal = false;
        this.editingVisit = null;
        this.newTime = '';
    }

    async handleSaveTime() {
        if (!this.newTime) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please select a time.',
                    variant: 'error'
                })
            );
            return;
        }

        this.isUpdating = true;

        try {
            // Build new datetime
            const [hours, minutes] = this.newTime.split(':');
            const newDateTime = new Date(this.selectedDate + 'T' + this.newTime + ':00');

            await updateVisitTime({
                visitId: this.editingVisit.visitId,
                newStartTime: newDateTime.toISOString()
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Visit time updated.',
                    variant: 'success'
                })
            );

            this.handleCloseTimeModal();
            await refreshApex(this.wiredVisitsResult);

        } catch (error) {
            console.error('Error updating time:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to update visit time.',
                    variant: 'error'
                })
            );
        } finally {
            this.isUpdating = false;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        await refreshApex(this.wiredVisitsResult);
        this.isLoading = false;
    }

    // Get full route directions URL (all stops)
    handleGetFullRoute() {
        if (this.visits.length === 0) return;

        const addresses = this.visits
            .filter(v => v.hasAddress)
            .map(v => encodeURIComponent(v.fullAddress));

        if (addresses.length === 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'No Addresses',
                    message: 'No visits have addresses to route.',
                    variant: 'warning'
                })
            );
            return;
        }

        // Google Maps directions URL with waypoints
        let mapsUrl = 'https://www.google.com/maps/dir/';
        mapsUrl += addresses.join('/');

        window.open(mapsUrl, '_blank');
    }

    get hasVisits() {
        return this.visits && this.visits.length > 0;
    }

    get noVisits() {
        return !this.hasVisits;
    }

    get visitCount() {
        return this.visits.length;
    }

    get totalDuration() {
        const minutes = this.visits.reduce((sum, v) => sum + (v.durationMinutes || 0), 0);
        const hours = Math.floor(minutes / 60);
        const mins = minutes % 60;
        if (hours > 0) {
            return `${hours}h ${mins}m`;
        }
        return `${mins}m`;
    }

    get formattedDate() {
        if (!this.selectedDate) return '';
        const date = new Date(this.selectedDate + 'T00:00:00');
        return date.toLocaleDateString('en-US', {
            weekday: 'long',
            month: 'long',
            day: 'numeric'
        });
    }

    get isToday() {
        return this.selectedDate === this.formatDate(new Date());
    }
}