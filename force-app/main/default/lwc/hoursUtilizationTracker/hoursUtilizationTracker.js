import { LightningElement, api, wire } from 'lwc';
import getHoursUtilization from '@salesforce/apex/ReferralController.getHoursUtilization';

export default class HoursUtilizationTracker extends LightningElement {
    @api recordId;

    hoursData;
    error;

    @wire(getHoursUtilization, { referralId: '$recordId' })
    wiredHoursUtilization({ error, data }) {
        if (data) {
            this.hoursData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.hoursData = undefined;
        }
    }

    get hasData() {
        return this.hoursData !== undefined && this.hoursData !== null;
    }

    get authorizedHours() {
        return this.hoursData?.authorizedHours ?? 0;
    }

    get usedHours() {
        return this.hoursData?.usedHours ?? 0;
    }

    get remainingHours() {
        return this.hoursData?.remainingHours ?? 0;
    }

    get utilizationPercentage() {
        return this.hoursData?.utilizationPercentage ?? 0;
    }

    get progressPercentage() {
        const percentage = this.utilizationPercentage;
        return Math.min(percentage, 100);
    }

    get progressBarStyle() {
        return `width: ${this.progressPercentage}%`;
    }

    get progressBarClass() {
        const percentage = this.utilizationPercentage;
        if (percentage > 90) {
            return 'progress-fill progress-fill-red';
        } else if (percentage > 75) {
            return 'progress-fill progress-fill-orange';
        }
        return 'progress-fill progress-fill-green';
    }

    get authEndDate() {
        return this.hoursData?.authEndDate ?? '';
    }

    get daysRemaining() {
        return this.hoursData?.daysRemaining ?? 0;
    }

    get projectedWeeklyUsage() {
        return this.hoursData?.projectedWeeklyUsage ?? 0;
    }

    get utilizationStatus() {
        return this.hoursData?.utilizationStatus ?? '';
    }

    get statusBadgeClass() {
        const status = this.utilizationStatus;
        switch (status) {
            case 'Near Limit':
                return 'status-badge status-near-limit';
            case 'On Track':
                return 'status-badge status-on-track';
            case 'Moderate':
                return 'status-badge status-moderate';
            case 'Low Usage':
                return 'status-badge status-low-usage';
            default:
                return 'status-badge';
        }
    }

    get formattedPercentage() {
        return `${this.utilizationPercentage.toFixed(1)}%`;
    }

    get formattedProjectedWeeklyUsage() {
        return this.projectedWeeklyUsage.toFixed(1);
    }
}