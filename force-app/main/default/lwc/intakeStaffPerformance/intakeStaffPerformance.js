import { LightningElement, wire, track } from 'lwc';
import getIntakeStaffPerformance from '@salesforce/apex/ReferralController.getIntakeStaffPerformance';

export default class IntakeStaffPerformance extends LightningElement {
    @track startDate;
    @track endDate;
    @track staffPerformanceData = [];
    @track error;
    @track isLoading = true;
    @track dateError;

    connectedCallback() {
        // Set default date range to last 30 days
        const today = new Date();
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(today.getDate() - 30);

        this.endDate = this.formatDate(today);
        this.startDate = this.formatDate(thirtyDaysAgo);
    }

    formatDate(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    @wire(getIntakeStaffPerformance, { startDate: '$startDate', endDate: '$endDate' })
    wiredStaffPerformance({ error, data }) {
        this.isLoading = false;
        if (data) {
            // Sort by admissions descending and add rank
            this.staffPerformanceData = this.processStaffData(data);
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'An error occurred while fetching staff performance data';
            this.staffPerformanceData = [];
        }
    }

    processStaffData(data) {
        // Sort by admitted referrals descending
        const sorted = [...data].sort((a, b) => b.admittedReferrals - a.admittedReferrals);

        // Add rank and formatting
        return sorted.map((staff, index) => ({
            ...staff,
            rank: index + 1,
            isTopPerformer: index === 0,
            formattedConversionRate: this.formatPercentage(staff.conversionRate),
            formattedAvgDays: this.formatDays(staff.avgDaysToAdmission),
            rankClass: this.getRankClass(index),
            conversionRateBadgeClass: this.getConversionBadgeClass(staff.conversionRate),
            rowClass: index === 0 ? 'leaderboard-row top-performer' : 'leaderboard-row'
        }));
    }

    formatPercentage(value) {
        return Number(value || 0).toFixed(1) + '%';
    }

    formatDays(value) {
        if (value === null || value === undefined) {
            return 'N/A';
        }
        return Number(value).toFixed(1);
    }

    getRankClass(index) {
        if (index === 0) return 'rank rank-gold';
        if (index === 1) return 'rank rank-silver';
        if (index === 2) return 'rank rank-bronze';
        return 'rank';
    }

    getConversionBadgeClass(rate) {
        if (rate >= 75) return 'conversion-badge badge-high';
        if (rate >= 50) return 'conversion-badge badge-medium';
        return 'conversion-badge badge-low';
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
        if (this.validateDates()) {
            this.isLoading = true;
        }
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
        if (this.validateDates()) {
            this.isLoading = true;
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

    get maxDate() {
        return this.formatDate(new Date());
    }

    get startDateMax() {
        return this.endDate || this.maxDate;
    }

    get endDateMin() {
        return this.startDate || null;
    }

    get hasData() {
        return this.staffPerformanceData && this.staffPerformanceData.length > 0 && !this.error;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get noData() {
        return !this.hasData;
    }

    get noError() {
        return !this.error;
    }

    get noDataMessage() {
        return 'No staff performance data available for the selected date range.';
    }
}