import { LightningElement, track, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getStaffAvailability from '@salesforce/apex/SchedulingController.getStaffAvailability';
import saveAvailability from '@salesforce/apex/SchedulingController.saveAvailability';
import deleteAvailability from '@salesforce/apex/SchedulingController.deleteAvailability';
import Id from '@salesforce/user/Id';

const DAYS_OF_WEEK = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

export default class StaffAvailabilityPicker extends LightningElement {
    @api userId;
    @track currentWeekStart;
    @track availabilityRecords = [];
    @track isLoading = true;
    @track showModal = false;
    @track selectedDate = null;
    @track editingRecord = null;

    // Form fields
    @track formStartTime = '09:00';
    @track formEndTime = '17:00';
    @track formAvailabilityType = 'Working';
    @track formNotes = '';

    wiredAvailabilityResult;

    availabilityTypes = [
        { label: 'Working Hours', value: 'Working' },
        { label: 'PTO / Day Off', value: 'PTO' },
        { label: 'Blocked Time', value: 'Blocked' }
    ];

    connectedCallback() {
        if (!this.userId) {
            this.userId = Id;
        }
        this.currentWeekStart = this.getWeekStart(new Date());
        this.loadAvailability();
    }

    getWeekStart(date) {
        const d = new Date(date);
        d.setDate(d.getDate() - d.getDay());
        d.setHours(0, 0, 0, 0);
        return d;
    }

    get weekDates() {
        const dates = [];
        const start = new Date(this.currentWeekStart);

        for (let i = 0; i < 7; i++) {
            const date = new Date(start);
            date.setDate(date.getDate() + i);
            const dateStr = this.toDateString(date);
            const isToday = this.isToday(date);

            // Compute CSS class
            let dayClass = 'availability-day';
            if (isToday) {
                dayClass += ' today';
            }

            dates.push({
                date: date,
                dateStr: dateStr,
                dayName: DAYS_OF_WEEK[date.getDay()],
                dayNumber: date.getDate(),
                month: date.toLocaleString('default', { month: 'short' }),
                isToday: isToday,
                availability: this.getAvailabilityForDate(dateStr),
                dayClass: dayClass
            });
        }

        return dates;
    }

    get weekHeaderTitle() {
        const start = new Date(this.currentWeekStart);
        const end = new Date(start);
        end.setDate(end.getDate() + 6);

        const startMonth = start.toLocaleString('default', { month: 'short' });
        const endMonth = end.toLocaleString('default', { month: 'short' });

        if (startMonth === endMonth) {
            return `${startMonth} ${start.getDate()} - ${end.getDate()}, ${start.getFullYear()}`;
        }
        return `${startMonth} ${start.getDate()} - ${endMonth} ${end.getDate()}, ${end.getFullYear()}`;
    }

    get modalTitle() {
        if (this.editingRecord) {
            return 'Edit Availability';
        }
        return this.selectedDate
            ? `Add Availability for ${this.selectedDate.toLocaleDateString()}`
            : 'Add Availability';
    }

    getAvailabilityForDate(dateStr) {
        return this.availabilityRecords.filter(a => a.dateStr === dateStr);
    }

    isToday(date) {
        const today = new Date();
        return date.toDateString() === today.toDateString();
    }

    toDateString(date) {
        return date.toISOString().split('T')[0];
    }

    async loadAvailability() {
        this.isLoading = true;
        try {
            const startDate = this.toDateString(this.currentWeekStart);
            const endDate = this.toDateString(
                new Date(this.currentWeekStart.getTime() + 6 * 24 * 60 * 60 * 1000)
            );

            const data = await getStaffAvailability({
                userId: this.userId,
                startDate: startDate,
                endDate: endDate
            });

            this.availabilityRecords = data.map(record => ({
                ...record,
                dateStr: record.Date__c,
                displayTime: this.formatTimeRange(record.Start_Time__c, record.End_Time__c),
                typeClass: this.getTypeClass(record.Availability_Type__c),
                typeIcon: this.getTypeIcon(record.Availability_Type__c)
            }));
        } catch (error) {
            this.showToast('Error', 'Failed to load availability', 'error');
            console.error('Error loading availability:', error);
        } finally {
            this.isLoading = false;
        }
    }

    formatTimeRange(startTime, endTime) {
        const formatTime = (timeVal) => {
            if (!timeVal) return '';
            // timeVal is in milliseconds from midnight
            const hours = Math.floor(timeVal / 3600000);
            const minutes = Math.floor((timeVal % 3600000) / 60000);
            const ampm = hours >= 12 ? 'PM' : 'AM';
            const displayHours = hours > 12 ? hours - 12 : hours === 0 ? 12 : hours;
            return `${displayHours}:${minutes.toString().padStart(2, '0')} ${ampm}`;
        };

        return `${formatTime(startTime)} - ${formatTime(endTime)}`;
    }

    getTypeClass(type) {
        const classes = {
            'Working': 'availability-working',
            'PTO': 'availability-pto',
            'Blocked': 'availability-blocked'
        };
        return classes[type] || 'availability-working';
    }

    getTypeIcon(type) {
        const icons = {
            'Working': 'utility:clock',
            'PTO': 'utility:holiday',
            'Blocked': 'utility:ban'
        };
        return icons[type] || 'utility:clock';
    }

    handlePreviousWeek() {
        const newStart = new Date(this.currentWeekStart);
        newStart.setDate(newStart.getDate() - 7);
        this.currentWeekStart = newStart;
        this.loadAvailability();
    }

    handleNextWeek() {
        const newStart = new Date(this.currentWeekStart);
        newStart.setDate(newStart.getDate() + 7);
        this.currentWeekStart = newStart;
        this.loadAvailability();
    }

    handleThisWeek() {
        this.currentWeekStart = this.getWeekStart(new Date());
        this.loadAvailability();
    }

    handleDayClick(event) {
        const dateStr = event.currentTarget.dataset.date;
        this.selectedDate = new Date(dateStr + 'T00:00:00');
        this.editingRecord = null;
        this.resetForm();
        this.showModal = true;
    }

    handleEditAvailability(event) {
        event.stopPropagation();
        const recordId = event.currentTarget.dataset.id;
        const record = this.availabilityRecords.find(r => r.Id === recordId);

        if (record) {
            this.editingRecord = record;
            this.selectedDate = new Date(record.Date__c + 'T00:00:00');
            this.formStartTime = this.msToTimeString(record.Start_Time__c);
            this.formEndTime = this.msToTimeString(record.End_Time__c);
            this.formAvailabilityType = record.Availability_Type__c;
            this.formNotes = record.Notes__c || '';
            this.showModal = true;
        }
    }

    async handleDeleteAvailability(event) {
        event.stopPropagation();
        const recordId = event.currentTarget.dataset.id;

        try {
            await deleteAvailability({ availabilityId: recordId });
            this.showToast('Success', 'Availability deleted', 'success');
            this.loadAvailability();
        } catch (error) {
            this.showToast('Error', 'Failed to delete availability', 'error');
        }
    }

    msToTimeString(ms) {
        if (!ms) return '09:00';
        const hours = Math.floor(ms / 3600000);
        const minutes = Math.floor((ms % 3600000) / 60000);
        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
    }

    timeStringToMs(timeStr) {
        const [hours, minutes] = timeStr.split(':').map(Number);
        return (hours * 3600000) + (minutes * 60000);
    }

    resetForm() {
        this.formStartTime = '09:00';
        this.formEndTime = '17:00';
        this.formAvailabilityType = 'Working';
        this.formNotes = '';
    }

    handleCloseModal() {
        this.showModal = false;
        this.editingRecord = null;
        this.selectedDate = null;
    }

    handleStartTimeChange(event) {
        this.formStartTime = event.target.value;
    }

    handleEndTimeChange(event) {
        this.formEndTime = event.target.value;
    }

    handleTypeChange(event) {
        this.formAvailabilityType = event.detail.value;
    }

    handleNotesChange(event) {
        this.formNotes = event.target.value;
    }

    async handleSaveAvailability() {
        // Validate times
        if (this.formStartTime >= this.formEndTime) {
            this.showToast('Error', 'End time must be after start time', 'error');
            return;
        }

        try {
            const availability = {
                User__c: this.userId,
                Date__c: this.toDateString(this.selectedDate),
                Start_Time__c: this.timeStringToMs(this.formStartTime),
                End_Time__c: this.timeStringToMs(this.formEndTime),
                Availability_Type__c: this.formAvailabilityType,
                Notes__c: this.formNotes
            };

            if (this.editingRecord) {
                availability.Id = this.editingRecord.Id;
            }

            await saveAvailability({ availability: availability });

            this.showToast('Success', 'Availability saved', 'success');
            this.handleCloseModal();
            this.loadAvailability();
        } catch (error) {
            this.showToast('Error', 'Failed to save availability: ' + error.body?.message, 'error');
            console.error('Error saving availability:', error);
        }
    }

    handleCopyToWeek() {
        // Future enhancement: copy current day's availability to entire week
        this.showToast('Info', 'Copy to week feature coming soon', 'info');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}