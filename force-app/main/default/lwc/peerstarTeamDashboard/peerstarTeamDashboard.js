import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getTeamDashboardMetrics from '@salesforce/apex/SchedulingController.getTeamDashboardMetrics';
import getTeamVisits from '@salesforce/apex/SchedulingController.getTeamVisits';
import getPeerSpecialists from '@salesforce/apex/SchedulingController.getPeerSpecialists';

export default class PeerstarTeamDashboard extends NavigationMixin(LightningElement) {
    @track metrics = {};
    @track visits = [];
    @track specialists = [];
    @track selectedSpecialistId = '';
    @track selectedStatuses = [];
    @track isLoading = true;
    @track error;

    // Date range defaults to current week
    @track startDate;
    @track endDate;

    // View toggle
    @track currentView = 'overview'; // 'overview' or 'visits'

    statusOptions = [
        { label: 'Scheduled', value: 'Scheduled' },
        { label: 'Dispatched', value: 'Dispatched' },
        { label: 'In Progress', value: 'In Progress' },
        { label: 'Completed', value: 'Completed' },
        { label: 'Cannot Complete', value: 'Cannot Complete' },
        { label: 'Canceled', value: 'Canceled' }
    ];

    connectedCallback() {
        // Initialize date range to current week
        const today = new Date();
        const startOfWeek = new Date(today);
        startOfWeek.setDate(today.getDate() - today.getDay());
        const endOfWeek = new Date(startOfWeek);
        endOfWeek.setDate(startOfWeek.getDate() + 6);

        this.startDate = this.formatDate(startOfWeek);
        this.endDate = this.formatDate(endOfWeek);
    }

    formatDate(date) {
        return date.toISOString().split('T')[0];
    }

    @wire(getPeerSpecialists)
    wiredSpecialists({ error, data }) {
        if (data) {
            this.specialists = [
                { label: 'All Specialists', value: '' },
                ...data.map(s => ({ label: s.name, value: s.id }))
            ];
        } else if (error) {
            console.error('Error loading specialists:', error);
        }
    }

    @wire(getTeamDashboardMetrics, { startDate: '$startDate', endDate: '$endDate' })
    wiredMetrics({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.metrics = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.metrics = {};
        }
    }

    @wire(getTeamVisits, {
        startDate: '$startDate',
        endDate: '$endDate',
        specialistId: '$selectedSpecialistId',
        statuses: '$selectedStatuses'
    })
    wiredVisits({ error, data }) {
        if (data) {
            this.visits = data.map(v => ({
                ...v,
                formattedDate: v.scheduledStart ?
                    new Date(v.scheduledStart).toLocaleDateString('en-US', {
                        month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit'
                    }) : 'Not scheduled',
                statusClass: this.getStatusClass(v.status)
            }));
        } else if (error) {
            console.error('Error loading visits:', error);
            this.visits = [];
        }
    }

    getStatusClass(status) {
        const classes = {
            'Completed': 'slds-badge slds-theme_success',
            'In Progress': 'slds-badge slds-theme_warning',
            'Scheduled': 'slds-badge slds-theme_info',
            'Dispatched': 'slds-badge slds-theme_info',
            'Cannot Complete': 'slds-badge slds-theme_error',
            'Canceled': 'slds-badge slds-theme_error'
        };
        return classes[status] || 'slds-badge';
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

    handleStatusChange(event) {
        this.selectedStatuses = event.detail.value;
    }

    handleViewChange(event) {
        this.currentView = event.target.dataset.view;
    }

    handleVisitClick(event) {
        const visitId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: visitId,
                actionName: 'view'
            }
        });
    }

    handleSpecialistClick(event) {
        const userId = event.currentTarget.dataset.userid;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: userId,
                actionName: 'view'
            }
        });
    }

    setThisWeek() {
        const today = new Date();
        const startOfWeek = new Date(today);
        startOfWeek.setDate(today.getDate() - today.getDay());
        const endOfWeek = new Date(startOfWeek);
        endOfWeek.setDate(startOfWeek.getDate() + 6);

        this.startDate = this.formatDate(startOfWeek);
        this.endDate = this.formatDate(endOfWeek);
    }

    setThisMonth() {
        const today = new Date();
        const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);
        const endOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0);

        this.startDate = this.formatDate(startOfMonth);
        this.endDate = this.formatDate(endOfMonth);
    }

    // Computed properties
    get isOverview() {
        return this.currentView === 'overview';
    }

    get isVisitsView() {
        return this.currentView === 'visits';
    }

    get overviewButtonVariant() {
        return this.currentView === 'overview' ? 'brand' : 'neutral';
    }

    get visitsButtonVariant() {
        return this.currentView === 'visits' ? 'brand' : 'neutral';
    }

    get hasMetrics() {
        return this.metrics && this.metrics.totalVisits > 0;
    }

    get hasSpecialists() {
        return this.metrics?.specialists && this.metrics.specialists.length > 0;
    }

    get hasVisits() {
        return this.visits && this.visits.length > 0;
    }

    get visitCount() {
        return this.visits.length;
    }

    get completionRateDisplay() {
        return this.metrics?.completionRate != null ? this.metrics.completionRate + '%' : '0%';
    }

    get dateRangeDisplay() {
        if (!this.startDate || !this.endDate) return '';
        const start = new Date(this.startDate + 'T00:00:00');
        const end = new Date(this.endDate + 'T00:00:00');
        return start.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) +
               ' - ' +
               end.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }
}