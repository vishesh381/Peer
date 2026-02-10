import { LightningElement, wire, track } from 'lwc';
import getReferralSourceMetrics from '@salesforce/apex/ReferralController.getReferralSourceMetrics';

export default class ReferralSourceRoi extends LightningElement {
    @track startDate;
    @track endDate;
    @track referralSources = [];
    @track error;
    @track isLoading = false;
    @track dateError;

    maxReferrals = 0;

    connectedCallback() {
        // Initialize with default date range (last 30 days)
        const today = new Date();
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(today.getDate() - 30);

        this.endDate = this.formatDate(today);
        this.startDate = this.formatDate(thirtyDaysAgo);
    }

    formatDate(date) {
        return date.toISOString().split('T')[0];
    }

    @wire(getReferralSourceMetrics, { startDate: '$startDate', endDate: '$endDate' })
    wiredMetrics(result) {
        this.isLoading = true;
        if (result.data) {
            this.processMetrics(result.data);
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error.body?.message || 'An error occurred while fetching referral metrics.';
            this.referralSources = [];
        }
        this.isLoading = false;
    }

    processMetrics(data) {
        if (!data || data.length === 0) {
            this.referralSources = [];
            this.maxReferrals = 0;
            return;
        }

        // Sort by total referrals descending
        const sorted = [...data].sort((a, b) => b.totalReferrals - a.totalReferrals);

        // Find max for bar width calculation
        this.maxReferrals = sorted[0]?.totalReferrals || 1;

        // Process each source with additional display properties
        this.referralSources = sorted.map((source, index) => {
            const barWidthPercent = this.maxReferrals > 0
                ? Math.round((source.totalReferrals / this.maxReferrals) * 100)
                : 0;

            return {
                ...source,
                key: `source-${index}`,
                barWidth: `width: ${barWidthPercent}%;`,
                conversionRateDisplay: `${source.conversionRate.toFixed(1)}%`,
                conversionBadgeClass: this.getConversionBadgeClass(source.conversionRate)
            };
        });
    }

    getConversionBadgeClass(rate) {
        if (rate >= 50) {
            return 'conversion-badge high';
        } else if (rate >= 25) {
            return 'conversion-badge medium';
        }
        return 'conversion-badge low';
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
        this.validateDates();
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
        this.validateDates();
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
        return this.referralSources && this.referralSources.length > 0;
    }

    get noDataMessage() {
        return 'No referral data available for the selected date range.';
    }

    get notLoading() {
        return !this.isLoading;
    }

    get notError() {
        return !this.error;
    }

    get showNoDataMessage() {
        return !this.hasData && !this.isLoading && !this.error;
    }
}