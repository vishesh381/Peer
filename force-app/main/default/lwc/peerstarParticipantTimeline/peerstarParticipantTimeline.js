import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getParticipantTimeline from '@salesforce/apex/SchedulingController.getParticipantTimeline';

export default class PeerstarParticipantTimeline extends NavigationMixin(LightningElement) {
    @api recordId;
    @track timelineEvents = [];
    @track error;
    @track isLoading = true;
    @track displayCount = 10;

    @wire(getParticipantTimeline, { caseId: '$recordId' })
    wiredTimeline({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.timelineEvents = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.timelineEvents = [];
        }
    }

    get hasEvents() {
        return this.timelineEvents && this.timelineEvents.length > 0;
    }

    get visibleEvents() {
        return this.timelineEvents.slice(0, this.displayCount);
    }

    get hasMoreEvents() {
        return this.timelineEvents.length > this.displayCount;
    }

    get remainingCount() {
        return this.timelineEvents.length - this.displayCount;
    }

    get totalEventCount() {
        return this.timelineEvents.length;
    }

    get completedCount() {
        return this.timelineEvents.filter(e => e.itemClass?.includes('success')).length;
    }

    get missedCount() {
        return this.timelineEvents.filter(e => e.itemClass?.includes('error')).length;
    }

    handleShowMore() {
        this.displayCount += 10;
    }

    handleShowAll() {
        this.displayCount = this.timelineEvents.length;
    }

    handleEventClick(event) {
        const recordId = event.currentTarget.dataset.id;
        if (recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            });
        }
    }
}