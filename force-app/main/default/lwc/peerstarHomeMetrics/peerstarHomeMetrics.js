import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getPeerSpecialistMetrics from '@salesforce/apex/SchedulingController.getPeerSpecialistMetrics';

export default class PeerstarHomeMetrics extends LightningElement {
    metrics = {};
    isLoading = true;
    error;
    wiredMetricsResult;

    @wire(getPeerSpecialistMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        this.isLoading = false;
        if (result.data) {
            this.metrics = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.metrics = {};
        }
    }

    get todayCount() {
        return this.metrics.todayCount || 0;
    }

    get thisWeekCount() {
        return this.metrics.thisWeekCount || 0;
    }

    get pendingCount() {
        return this.metrics.pendingCount || 0;
    }

    get confirmedCount() {
        return this.metrics.confirmedCount || 0;
    }

    get inSessionCount() {
        return this.metrics.inSessionCount || 0;
    }

    get completedCount() {
        return this.metrics.completedCount || 0;
    }

    get missedCount() {
        return this.metrics.missedCount || 0;
    }

    get overdueCount() {
        return this.metrics.overdueCount || 0;
    }

    get followUpsNeededCount() {
        return this.metrics.followUpsNeededCount || 0;
    }

    get hasOverdue() {
        return this.overdueCount > 0;
    }

    get hasFollowUps() {
        return this.followUpsNeededCount > 0;
    }

    get overdueClass() {
        return this.hasOverdue ? 'metric-tile overdue alert' : 'metric-tile overdue';
    }

    get followUpClass() {
        return this.hasFollowUps ? 'metric-tile followup alert' : 'metric-tile followup';
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredMetricsResult).then(() => {
            this.isLoading = false;
        });
    }
}