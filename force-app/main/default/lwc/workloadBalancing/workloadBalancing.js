import { LightningElement, wire, track } from 'lwc';
import getWorkloadDistribution from '@salesforce/apex/ReferralController.getWorkloadDistribution';

export default class WorkloadBalancing extends LightningElement {
    @track workloadData = [];
    @track sortedBy = 'caseload';
    @track sortDirection = 'desc';
    @track error;
    @track isLoading = true;

    @wire(getWorkloadDistribution)
    wiredWorkload({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.workloadData = this.processAndSortData(data);
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'An error occurred while loading workload data';
            this.workloadData = [];
        }
    }

    get hasData() {
        return this.workloadData && this.workloadData.length > 0;
    }

    get noData() {
        return !this.hasData;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get noError() {
        return !this.error;
    }

    get averageCaseload() {
        if (!this.workloadData || this.workloadData.length === 0) {
            return 0;
        }
        const total = this.workloadData.reduce((sum, specialist) => sum + specialist.caseload, 0);
        return (total / this.workloadData.length).toFixed(1);
    }

    get sortOptions() {
        return [
            { label: 'Caseload', value: 'caseload' },
            { label: 'Capacity', value: 'capacity' }
        ];
    }

    get sortDirectionIcon() {
        return this.sortDirection === 'asc' ? 'utility:arrowup' : 'utility:arrowdown';
    }

    get sortDirectionLabel() {
        return this.sortDirection === 'asc' ? 'Ascending' : 'Descending';
    }

    processAndSortData(data) {
        const processed = data.map(specialist => ({
            ...specialist,
            capacityBarStyle: this.getCapacityBarStyle(specialist.capacityPercentage),
            statusBadgeClass: this.getStatusBadgeClass(specialist.capacityStatus),
            capacityDisplayPercentage: Math.min(specialist.capacityPercentage, 100)
        }));
        return this.sortData(processed);
    }

    sortData(data) {
        const sorted = [...data];
        const direction = this.sortDirection === 'asc' ? 1 : -1;

        sorted.sort((a, b) => {
            let valueA, valueB;
            if (this.sortedBy === 'caseload') {
                valueA = a.caseload;
                valueB = b.caseload;
            } else {
                valueA = a.capacityPercentage;
                valueB = b.capacityPercentage;
            }
            return (valueA - valueB) * direction;
        });

        return sorted;
    }

    getCapacityBarStyle(percentage) {
        const cappedPercentage = Math.min(percentage, 100);
        let color;

        if (percentage <= 50) {
            color = '#4bca81'; // Green
        } else if (percentage <= 75) {
            color = '#ffb75d'; // Yellow/Orange
        } else if (percentage <= 90) {
            color = '#ff9a3c'; // Orange
        } else {
            color = '#ff5d5d'; // Red
        }

        return `width: ${cappedPercentage}%; background: linear-gradient(90deg, ${color} 0%, ${this.darkenColor(color)} 100%);`;
    }

    darkenColor(hex) {
        const num = parseInt(hex.slice(1), 16);
        const amt = -30;
        const R = Math.max(0, (num >> 16) + amt);
        const G = Math.max(0, ((num >> 8) & 0x00ff) + amt);
        const B = Math.max(0, (num & 0x0000ff) + amt);
        return `#${(0x1000000 + R * 0x10000 + G * 0x100 + B).toString(16).slice(1)}`;
    }

    getStatusBadgeClass(status) {
        const baseClass = 'status-badge';
        switch (status?.toLowerCase()) {
            case 'available':
                return `${baseClass} status-available`;
            case 'moderate':
                return `${baseClass} status-moderate`;
            case 'high':
                return `${baseClass} status-high`;
            case 'overloaded':
                return `${baseClass} status-overloaded`;
            default:
                return baseClass;
        }
    }

    handleSortChange(event) {
        this.sortedBy = event.detail.value;
        this.workloadData = this.sortData(this.workloadData);
    }

    handleToggleSortDirection() {
        this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.workloadData = this.sortData(this.workloadData);
    }
}