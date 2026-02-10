import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPeerVisits from '@salesforce/apex/SchedulingController.getPeerVisits';
import getPeerSpecialists from '@salesforce/apex/SchedulingController.getPeerSpecialists';
import updateVisitStatus from '@salesforce/apex/SchedulingController.updateVisitStatus';

const DAYS_OF_WEEK = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
                'July', 'August', 'September', 'October', 'November', 'December'];

export default class SchedulingCalendar extends LightningElement {
    @track currentDate = new Date();
    @track viewMode = 'week'; // 'day', 'week', 'month'
    @track selectedUserId = null;
    @track scheduledServices = [];
    @track staffMembers = [];
    @track isLoading = true;
    @track selectedService = null;
    @track showServiceModal = false;

    // View mode options
    viewModeOptions = [
        { label: 'Day', value: 'day' },
        { label: 'Week', value: 'week' },
        { label: 'Month', value: 'month' }
    ];

    // Status options for updating (Peer Support terminology)
    statusOptions = [
        { label: 'Pending', value: 'None' },
        { label: 'Scheduled', value: 'Scheduled' },
        { label: 'Confirmed', value: 'Dispatched' },
        { label: 'In Session', value: 'In Progress' },
        { label: 'Visit Complete', value: 'Completed' },
        { label: 'Missed', value: 'Cannot Complete' },
        { label: 'Canceled', value: 'Canceled' }
    ];

    @wire(getPeerSpecialists)
    wiredStaff({ error, data }) {
        if (data) {
            this.staffMembers = [
                { label: 'All Peer Specialists', value: '' },
                ...data.map(s => ({ label: s.name, value: s.id }))
            ];
        } else if (error) {
            this.showToast('Error', 'Failed to load peer specialists', 'error');
        }
    }

    connectedCallback() {
        this.loadServices();
    }

    get dateRange() {
        const start = this.getStartDate();
        const end = this.getEndDate();
        return {
            start: start,
            end: end,
            display: this.formatDateRange(start, end)
        };
    }

    get headerTitle() {
        if (this.viewMode === 'day') {
            return this.formatDate(this.currentDate);
        } else if (this.viewMode === 'week') {
            return this.dateRange.display;
        } else {
            return `${MONTHS[this.currentDate.getMonth()]} ${this.currentDate.getFullYear()}`;
        }
    }

    get calendarDays() {
        const days = [];
        const start = this.getStartDate();
        const end = this.getEndDate();
        const current = new Date(start);

        while (current <= end) {
            const dayServices = this.getServicesForDate(current);
            const isToday = this.isToday(current);
            const isCurrentMonth = current.getMonth() === this.currentDate.getMonth();

            // Compute CSS classes
            let dayClass = 'calendar-day';
            if (isToday) {
                dayClass += ' today';
            }

            let monthDayClass = 'month-day';
            if (!isCurrentMonth) {
                monthDayClass += ' other-month';
            }
            if (isToday) {
                monthDayClass += ' today';
            }

            days.push({
                date: new Date(current),
                dayName: DAYS_OF_WEEK[current.getDay()],
                dayNumber: current.getDate(),
                isToday: isToday,
                isCurrentMonth: isCurrentMonth,
                services: dayServices,
                hasServices: dayServices.length > 0,
                dayClass: dayClass,
                monthDayClass: monthDayClass
            });
            current.setDate(current.getDate() + 1);
        }

        return days;
    }

    get isWeekView() {
        return this.viewMode === 'week';
    }

    get isDayView() {
        return this.viewMode === 'day';
    }

    get isMonthView() {
        return this.viewMode === 'month';
    }

    getStartDate() {
        const date = new Date(this.currentDate);
        if (this.viewMode === 'day') {
            return date;
        } else if (this.viewMode === 'week') {
            date.setDate(date.getDate() - date.getDay());
            return date;
        } else {
            date.setDate(1);
            date.setDate(date.getDate() - date.getDay());
            return date;
        }
    }

    getEndDate() {
        const date = new Date(this.currentDate);
        if (this.viewMode === 'day') {
            return date;
        } else if (this.viewMode === 'week') {
            date.setDate(date.getDate() + (6 - date.getDay()));
            return date;
        } else {
            date.setMonth(date.getMonth() + 1, 0);
            date.setDate(date.getDate() + (6 - date.getDay()));
            return date;
        }
    }

    getServicesForDate(date) {
        const dateStr = this.toDateString(date);
        return this.scheduledServices.filter(svc => {
            const svcDate = svc.scheduledStart
                ? this.toDateString(new Date(svc.scheduledStart))
                : svc.dueDate;
            return svcDate === dateStr;
        });
    }

    isToday(date) {
        const today = new Date();
        return date.toDateString() === today.toDateString();
    }

    toDateString(date) {
        return date.toISOString().split('T')[0];
    }

    formatDate(date) {
        return `${DAYS_OF_WEEK[date.getDay()]}, ${MONTHS[date.getMonth()]} ${date.getDate()}, ${date.getFullYear()}`;
    }

    formatDateRange(start, end) {
        if (start.getMonth() === end.getMonth()) {
            return `${MONTHS[start.getMonth()]} ${start.getDate()} - ${end.getDate()}, ${start.getFullYear()}`;
        }
        return `${MONTHS[start.getMonth()]} ${start.getDate()} - ${MONTHS[end.getMonth()]} ${end.getDate()}, ${end.getFullYear()}`;
    }

    async loadServices() {
        this.isLoading = true;
        try {
            const startDate = this.toDateString(this.getStartDate());
            const endDate = this.toDateString(this.getEndDate());
            const peerSpecialistId = this.selectedUserId || null;

            const data = await getPeerVisits({
                startDate: startDate,
                endDate: endDate,
                peerSpecialistId: peerSpecialistId
            });

            this.scheduledServices = data.map(svc => ({
                ...svc,
                displayTime: svc.scheduledStart
                    ? new Date(svc.scheduledStart).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
                    : 'TBD',
                statusClass: this.getStatusClass(svc.status)
            }));
        } catch (error) {
            this.showToast('Error', 'Failed to load peer visits', 'error');
            console.error('Error loading peer visits:', error);
        } finally {
            this.isLoading = false;
        }
    }

    getStatusClass(status) {
        // Field Service statuses
        const statusClasses = {
            'None': 'status-none',
            'Scheduled': 'status-scheduled',
            'Dispatched': 'status-dispatched',
            'In Progress': 'status-in-progress',
            'Completed': 'status-completed',
            'Cannot Complete': 'status-cannot-complete',
            'Canceled': 'status-canceled'
        };
        return statusClasses[status] || 'status-none';
    }

    handleViewModeChange(event) {
        this.viewMode = event.detail.value;
        this.loadServices();
    }

    handleStaffChange(event) {
        this.selectedUserId = event.detail.value || null;
        this.loadServices();
    }

    handlePrevious() {
        const date = new Date(this.currentDate);
        if (this.viewMode === 'day') {
            date.setDate(date.getDate() - 1);
        } else if (this.viewMode === 'week') {
            date.setDate(date.getDate() - 7);
        } else {
            date.setMonth(date.getMonth() - 1);
        }
        this.currentDate = date;
        this.loadServices();
    }

    handleNext() {
        const date = new Date(this.currentDate);
        if (this.viewMode === 'day') {
            date.setDate(date.getDate() + 1);
        } else if (this.viewMode === 'week') {
            date.setDate(date.getDate() + 7);
        } else {
            date.setMonth(date.getMonth() + 1);
        }
        this.currentDate = date;
        this.loadServices();
    }

    handleToday() {
        this.currentDate = new Date();
        this.loadServices();
    }

    handleRefresh() {
        this.loadServices();
    }

    handleServiceClick(event) {
        const serviceId = event.currentTarget.dataset.id;
        this.selectedService = this.scheduledServices.find(s => s.id === serviceId);
        this.showServiceModal = true;
    }

    handleCloseModal() {
        this.showServiceModal = false;
        this.selectedService = null;
    }

    async handleStatusChange(event) {
        const newStatus = event.detail.value;
        if (this.selectedService && newStatus !== this.selectedService.status) {
            try {
                await updateVisitStatus({
                    visitId: this.selectedService.id,
                    newStatus: newStatus
                });
                this.showToast('Success', 'Visit status updated', 'success');
                this.handleCloseModal();
                this.loadServices();
            } catch (error) {
                this.showToast('Error', 'Failed to update visit status', 'error');
            }
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}