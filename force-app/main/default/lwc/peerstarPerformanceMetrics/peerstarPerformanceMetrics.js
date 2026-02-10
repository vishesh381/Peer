import { LightningElement, wire, track } from 'lwc';
import getPerformanceMetrics from '@salesforce/apex/SchedulingController.getPerformanceMetrics';
import getPeerSpecialists from '@salesforce/apex/SchedulingController.getPeerSpecialists';

export default class PeerstarPerformanceMetrics extends LightningElement {
    @track metrics = {};
    @track specialists = [];
    @track selectedSpecialistId = '';
    @track isLoading = true;
    @track error;

    // Date range
    @track startDate;
    @track endDate;

    connectedCallback() {
        // Default to last 30 days
        const today = new Date();
        const thirtyDaysAgo = new Date(today);
        thirtyDaysAgo.setDate(today.getDate() - 30);

        this.endDate = this.formatDate(today);
        this.startDate = this.formatDate(thirtyDaysAgo);
    }

    formatDate(date) {
        return date.toISOString().split('T')[0];
    }

    @wire(getPeerSpecialists)
    wiredSpecialists({ error, data }) {
        if (data) {
            this.specialists = [
                { label: 'All Specialists (Team)', value: '' },
                ...data.map(s => ({ label: s.name, value: s.id }))
            ];
        } else if (error) {
            console.error('Error loading specialists:', error);
        }
    }

    @wire(getPerformanceMetrics, {
        specialistId: '$selectedSpecialistId',
        startDate: '$startDate',
        endDate: '$endDate'
    })
    wiredMetrics({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.metrics = {
                ...data,
                completionRateDisplay: data.completionRate + '%',
                missedRateDisplay: data.missedRate + '%',
                cancelRateDisplay: data.cancelRate + '%',
                avgDurationDisplay: data.avgActualDuration + ' min',
                followUpComplianceDisplay: data.followUpComplianceRate + '%',
                // Progress bar widths
                completionBarWidth: 'width: ' + data.completionRate + '%',
                missedBarWidth: 'width: ' + data.missedRate + '%',
                followUpBarWidth: 'width: ' + data.followUpComplianceRate + '%'
            };
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.metrics = {};
        }
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
    }

    handleSpecialistChange(event) {
        this.selectedSpecialistId = event.detail.value || null;
    }

    setLast7Days() {
        const today = new Date();
        const sevenDaysAgo = new Date(today);
        sevenDaysAgo.setDate(today.getDate() - 7);

        this.endDate = this.formatDate(today);
        this.startDate = this.formatDate(sevenDaysAgo);
    }

    setLast30Days() {
        const today = new Date();
        const thirtyDaysAgo = new Date(today);
        thirtyDaysAgo.setDate(today.getDate() - 30);

        this.endDate = this.formatDate(today);
        this.startDate = this.formatDate(thirtyDaysAgo);
    }

    setLast90Days() {
        const today = new Date();
        const ninetyDaysAgo = new Date(today);
        ninetyDaysAgo.setDate(today.getDate() - 90);

        this.endDate = this.formatDate(today);
        this.startDate = this.formatDate(ninetyDaysAgo);
    }

    get hasMetrics() {
        return this.metrics && this.metrics.totalVisits > 0;
    }

    get hasTrends() {
        return this.metrics?.weeklyTrends && this.metrics.weeklyTrends.length > 0;
    }

    get completionRateClass() {
        const rate = this.metrics?.completionRate || 0;
        if (rate >= 90) return 'metric-good';
        if (rate >= 75) return 'metric-warning';
        return 'metric-bad';
    }

    get missedRateClass() {
        const rate = this.metrics?.missedRate || 0;
        if (rate <= 5) return 'metric-good';
        if (rate <= 15) return 'metric-warning';
        return 'metric-bad';
    }

    get followUpComplianceClass() {
        const rate = this.metrics?.followUpComplianceRate || 0;
        if (rate >= 90) return 'metric-good';
        if (rate >= 75) return 'metric-warning';
        return 'metric-bad';
    }

    get dateRangeDisplay() {
        if (!this.startDate || !this.endDate) return '';
        const start = new Date(this.startDate + 'T00:00:00');
        const end = new Date(this.endDate + 'T00:00:00');
        return start.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) +
               ' - ' +
               end.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

    get specialistLabel() {
        if (!this.selectedSpecialistId) return 'Team';
        const specialist = this.specialists.find(s => s.value === this.selectedSpecialistId);
        return specialist ? specialist.label : 'Specialist';
    }
}