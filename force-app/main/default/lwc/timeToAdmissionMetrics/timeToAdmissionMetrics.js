import { LightningElement, track } from 'lwc';
import getTimeToAdmissionMetrics from '@salesforce/apex/ReferralController.getTimeToAdmissionMetrics';

export default class TimeToAdmissionMetrics extends LightningElement {
    @track startDate;
    @track endDate;
    @track metrics;
    @track error;
    @track isLoading = true;
    @track dateError;

    connectedCallback() {
        // Set default date range: last 90 days
        const today = new Date();
        const ninetyDaysAgo = new Date(today);
        ninetyDaysAgo.setDate(today.getDate() - 90);

        this.endDate = today.toISOString().split('T')[0];
        this.startDate = ninetyDaysAgo.toISOString().split('T')[0];

        // Load initial data
        this.loadMetrics();
    }

    // Sorted source data for display
    get sortedSourceData() {
        if (!this.metrics || !this.metrics.bySource) {
            return [];
        }
        // Sort by average days ascending
        return [...this.metrics.bySource].sort((a, b) => a.averageDays - b.averageDays);
    }

    // Sorted specialist data for display
    get sortedSpecialistData() {
        if (!this.metrics || !this.metrics.bySpecialist) {
            return [];
        }
        // Sort by average days ascending
        return [...this.metrics.bySpecialist].sort((a, b) => a.averageDays - b.averageDays);
    }

    get hasSourceData() {
        return this.sortedSourceData && this.sortedSourceData.length > 0;
    }

    get hasSpecialistData() {
        return this.sortedSpecialistData && this.sortedSpecialistData.length > 0;
    }

    get hasMetrics() {
        return this.metrics && this.metrics.averageDays !== undefined;
    }

    get noMetrics() {
        return !this.hasMetrics;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get noError() {
        return !this.error;
    }

    get formattedAverageDays() {
        if (!this.metrics || this.metrics.averageDays === undefined) {
            return '--';
        }
        return this.metrics.averageDays.toFixed(1);
    }

    get totalAdmissions() {
        if (!this.metrics || this.metrics.totalAdmissions === undefined) {
            return 0;
        }
        return this.metrics.totalAdmissions;
    }

    loadMetrics() {
        if (!this.startDate || !this.endDate) {
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        this.error = undefined;

        getTimeToAdmissionMetrics({ startDate: this.startDate, endDate: this.endDate })
            .then(data => {
                this.metrics = data;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error.body?.message || 'An error occurred while fetching metrics';
                this.metrics = undefined;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
        if (this.validateDates()) {
            this.loadMetrics();
        }
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
        if (this.validateDates()) {
            this.loadMetrics();
        }
    }

    validateDates() {
        this.dateError = undefined;
        if (this.startDate && this.endDate) {
            if (new Date(this.endDate) < new Date(this.startDate)) {
                this.dateError = 'End date cannot be before start date.';
                return false;
            }
        }
        return true;
    }

    formatDateForMax(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    get maxDate() {
        return this.formatDateForMax(new Date());
    }

    get startDateMax() {
        return this.endDate || this.maxDate;
    }

    get endDateMin() {
        return this.startDate || null;
    }
}