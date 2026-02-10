import { LightningElement, wire, track } from 'lwc';
import getReferralAging from '@salesforce/apex/ReferralController.getReferralAging';
import { NavigationMixin } from 'lightning/navigation';

const COLUMNS = [
    {
        label: 'Name',
        fieldName: 'referralUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'name' },
            target: '_blank'
        },
        sortable: true
    },
    { label: 'Stage', fieldName: 'stage', sortable: true },
    { label: 'Days Open', fieldName: 'daysOpen', type: 'number', sortable: true },
    {
        label: 'Urgency',
        fieldName: 'urgencyLevel',
        cellAttributes: {
            class: { fieldName: 'urgencyClass' }
        },
        sortable: true
    },
    { label: 'County', fieldName: 'county', sortable: true },
    { label: 'Owner', fieldName: 'ownerName', sortable: true },
    { label: 'Specialist', fieldName: 'specialistName', sortable: true }
];

const URGENCY_OPTIONS = [
    { label: 'All', value: 'All' },
    { label: 'Critical', value: 'Critical' },
    { label: 'Warning', value: 'Warning' },
    { label: 'On Track', value: 'On Track' }
];

export default class ReferralAgingDashboard extends NavigationMixin(LightningElement) {
    @track referrals = [];
    @track filteredReferrals = [];
    @track error;
    @track isLoading = true;

    columns = COLUMNS;
    urgencyOptions = URGENCY_OPTIONS;
    selectedUrgency = 'All';

    // Summary counts
    criticalCount = 0;
    warningCount = 0;
    onTrackCount = 0;
    totalCount = 0;

    // Sorting
    sortedBy;
    sortedDirection = 'asc';

    @wire(getReferralAging)
    wiredReferralAging({ error, data }) {
        this.isLoading = true;
        if (data) {
            this.referrals = data.map((referral) => ({
                ...referral,
                referralUrl: '/' + referral.id,
                urgencyClass: this.getUrgencyClass(referral.urgencyLevel)
            }));
            this.calculateSummaryCounts();
            this.applyFilter();
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.referrals = [];
            this.filteredReferrals = [];
            this.resetCounts();
        }
        this.isLoading = false;
    }

    getUrgencyClass(urgencyLevel) {
        switch (urgencyLevel) {
            case 'Critical':
                return 'slds-text-color_error urgency-critical';
            case 'Warning':
                return 'slds-text-color_warning urgency-warning';
            case 'On Track':
                return 'slds-text-color_success urgency-on-track';
            default:
                return '';
        }
    }

    calculateSummaryCounts() {
        this.criticalCount = this.referrals.filter((r) => r.urgencyLevel === 'Critical').length;
        this.warningCount = this.referrals.filter((r) => r.urgencyLevel === 'Warning').length;
        this.onTrackCount = this.referrals.filter((r) => r.urgencyLevel === 'On Track').length;
        this.totalCount = this.referrals.length;
    }

    resetCounts() {
        this.criticalCount = 0;
        this.warningCount = 0;
        this.onTrackCount = 0;
        this.totalCount = 0;
    }

    handleUrgencyChange(event) {
        this.selectedUrgency = event.detail.value;
        this.applyFilter();
    }

    handleCardClick(event) {
        const urgency = event.currentTarget.dataset.urgency;
        this.selectedUrgency = urgency;
        this.applyFilter();
    }

    applyFilter() {
        if (this.selectedUrgency === 'All') {
            this.filteredReferrals = [...this.referrals];
        } else {
            this.filteredReferrals = this.referrals.filter(
                (referral) => referral.urgencyLevel === this.selectedUrgency
            );
        }

        // Re-apply sorting if active
        if (this.sortedBy) {
            this.sortData(this.sortedBy, this.sortedDirection);
        }
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortedDirection);
    }

    sortData(fieldName, direction) {
        const parseData = [...this.filteredReferrals];
        const keyValue = (a) => a[fieldName];
        const isReverse = direction === 'asc' ? 1 : -1;

        parseData.sort((x, y) => {
            let a = keyValue(x) ? keyValue(x) : '';
            let b = keyValue(y) ? keyValue(y) : '';

            if (typeof a === 'string') {
                a = a.toLowerCase();
                b = b.toLowerCase();
            }

            return isReverse * ((a > b) - (b > a));
        });

        this.filteredReferrals = parseData;
    }

    handleRefresh() {
        this.isLoading = true;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.isLoading = false;
        }, 500);
    }

    get hasReferrals() {
        return this.filteredReferrals && this.filteredReferrals.length > 0;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get filteredCount() {
        return this.filteredReferrals ? this.filteredReferrals.length : 0;
    }

    get criticalCardClass() {
        return this.selectedUrgency === 'Critical'
            ? 'summary-card critical selected'
            : 'summary-card critical';
    }

    get warningCardClass() {
        return this.selectedUrgency === 'Warning'
            ? 'summary-card warning selected'
            : 'summary-card warning';
    }

    get onTrackCardClass() {
        return this.selectedUrgency === 'On Track'
            ? 'summary-card on-track selected'
            : 'summary-card on-track';
    }

    get allCardClass() {
        return this.selectedUrgency === 'All' ? 'summary-card all selected' : 'summary-card all';
    }
}