import { LightningElement, wire, track } from 'lwc';
import getConversionFunnel from '@salesforce/apex/ReferralController.getConversionFunnel';

export default class ConversionFunnel extends LightningElement {
    @track startDate;
    @track endDate;
    @track funnelData;
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

    @wire(getConversionFunnel, { startDate: '$startDate', endDate: '$endDate' })
    wiredFunnelData({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.funnelData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'An error occurred while fetching funnel data';
            this.funnelData = undefined;
        }
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
        return this.funnelData && !this.error;
    }

    get totalLeads() {
        return this.funnelData?.totalLeads || 0;
    }

    get convertedLeads() {
        return this.funnelData?.convertedLeads || 0;
    }

    get totalReferrals() {
        return this.funnelData?.totalReferrals || 0;
    }

    get admittedReferrals() {
        return this.funnelData?.admittedReferrals || 0;
    }

    get leadToReferralRate() {
        const rate = this.funnelData?.leadToReferralRate || 0;
        return this.formatPercentage(rate);
    }

    get referralToAdmissionRate() {
        const rate = this.funnelData?.referralToAdmissionRate || 0;
        return this.formatPercentage(rate);
    }

    get overallConversionRate() {
        const rate = this.funnelData?.overallConversionRate || 0;
        return this.formatPercentage(rate);
    }

    formatPercentage(value) {
        return Number(value).toFixed(1) + '%';
    }

    get stage1Width() {
        return '100%';
    }

    get stage2Width() {
        if (!this.funnelData || this.totalLeads === 0) return '70%';
        const percentage = Math.max((this.convertedLeads / this.totalLeads) * 100, 30);
        return percentage + '%';
    }

    get stage3Width() {
        if (!this.funnelData || this.totalLeads === 0) return '40%';
        const percentage = Math.max((this.admittedReferrals / this.totalLeads) * 100, 15);
        return percentage + '%';
    }

    get stage1Style() {
        return `width: ${this.stage1Width}`;
    }

    get stage2Style() {
        return `width: ${this.stage2Width}`;
    }

    get stage3Style() {
        return `width: ${this.stage3Width}`;
    }
}