import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOverdueVisits from '@salesforce/apex/SchedulingController.getOverdueVisits';
import updateVisitStatus from '@salesforce/apex/SchedulingController.updateVisitStatus';

const STATUS_LABELS = {
    'None': 'Pending',
    'Scheduled': 'Scheduled',
    'Dispatched': 'Confirmed',
    'In Progress': 'In Session',
    'Completed': 'Visit Complete',
    'Cannot Complete': 'Missed',
    'Canceled': 'Canceled'
};

export default class PeerstarOverdueVisits extends NavigationMixin(LightningElement) {
    visits = [];
    isLoading = true;
    error;
    wiredVisitsResult;

    @wire(getOverdueVisits)
    wiredVisits(result) {
        this.wiredVisitsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.visits = result.data.map(v => ({
                ...v,
                statusLabel: STATUS_LABELS[v.status] || v.status,
                isMissed: v.status === 'Cannot Complete',
                badgeClass: v.status === 'Cannot Complete'
                    ? 'slds-m-left_x-small slds-badge_inverse'
                    : 'slds-m-left_x-small',
                displayDate: v.dueDate ? new Date(v.dueDate).toLocaleDateString() : 'No date'
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
        return this.visits ? this.visits.length : 0;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredVisitsResult).then(() => {
            this.isLoading = false;
        });
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

    async handleMarkComplete(event) {
        const visitId = event.currentTarget.dataset.id;
        try {
            await updateVisitStatus({ visitId: visitId, newStatus: 'Completed' });
            this.showToast('Success', 'Visit marked as complete', 'success');
            this.handleRefresh();
        } catch (error) {
            this.showToast('Error', 'Failed to update visit status', 'error');
        }
    }

    handleReschedule(event) {
        const visitId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: visitId,
                objectApiName: 'ServiceAppointment',
                actionName: 'edit'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}