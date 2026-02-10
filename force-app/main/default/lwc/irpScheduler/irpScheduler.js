import { LightningElement, api, track } from 'lwc';
import getSpecialistMatches from '@salesforce/apex/ReferralController.getSpecialistMatches';
import getIRPAvailability from '@salesforce/apex/ReferralController.getIRPAvailability';
import scheduleIRP from '@salesforce/apex/ReferralController.scheduleIRP';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class IrpScheduler extends LightningElement {
    @api recordId;

    @track specialists = [];
    @track timeSlots = [];
    @track selectedSpecialistId = '';
    @track selectedDate = '';
    @track selectedTimeSlot = null;
    @track isLoading = false;
    @track error = null;

    get specialistOptions() {
        return this.specialists.map((specialist) => ({
            label: specialist.Name,
            value: specialist.Id
        }));
    }

    get hasSpecialists() {
        return this.specialists.length > 0;
    }

    get noSpecialists() {
        return !this.hasSpecialists;
    }

    get hasTimeSlots() {
        return this.timeSlots.length > 0;
    }

    get showTimeSlots() {
        return this.selectedSpecialistId && this.selectedDate && this.hasTimeSlots;
    }

    get showNoSlotsMessage() {
        return (
            this.selectedSpecialistId &&
            this.selectedDate &&
            !this.hasTimeSlots &&
            !this.isLoading
        );
    }

    get selectedTimeDisplay() {
        if (this.selectedTimeSlot) {
            return `Selected: ${this.selectedTimeSlot.startTimeFormatted} (${this.selectedTimeSlot.durationMinutes} minutes)`;
        }
        return '';
    }

    get isScheduleDisabled() {
        return !this.selectedSpecialistId || !this.selectedDate || !this.selectedTimeSlot;
    }

    get minDate() {
        const today = new Date();
        return today.toISOString().split('T')[0];
    }

    connectedCallback() {
        this.loadSpecialists();
    }

    async loadSpecialists() {
        this.isLoading = true;
        this.error = null;
        try {
            this.specialists = await getSpecialistMatches({ referralId: this.recordId });
        } catch (err) {
            this.error = this.reduceErrors(err);
            this.showToast('Error', 'Failed to load specialists', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleSpecialistChange(event) {
        this.selectedSpecialistId = event.detail.value;
        this.selectedTimeSlot = null;
        this.timeSlots = [];
        if (this.selectedDate) {
            this.loadAvailability();
        }
    }

    handleDateChange(event) {
        this.selectedDate = event.detail.value;
        this.selectedTimeSlot = null;
        this.timeSlots = [];
        if (this.selectedSpecialistId) {
            this.loadAvailability();
        }
    }

    async loadAvailability() {
        if (!this.selectedSpecialistId || !this.selectedDate) {
            return;
        }

        this.isLoading = true;
        this.error = null;
        try {
            const slots = await getIRPAvailability({
                specialistId: this.selectedSpecialistId,
                selectedDate: this.selectedDate
            });
            this.timeSlots = slots.map((slot, index) => ({
                ...slot,
                id: `slot-${index}`,
                buttonClass: slot.isAvailable
                    ? 'time-slot-button available'
                    : 'time-slot-button unavailable',
                isDisabled: !slot.isAvailable
            }));
        } catch (err) {
            this.error = this.reduceErrors(err);
            this.showToast('Error', 'Failed to load availability', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleTimeSlotClick(event) {
        const slotId = event.currentTarget.dataset.slotId;
        const slot = this.timeSlots.find((s) => s.id === slotId);

        if (!slot || !slot.isAvailable) {
            return;
        }

        this.selectedTimeSlot = slot;
        this.timeSlots = this.timeSlots.map((s) => ({
            ...s,
            buttonClass: this.getSlotButtonClass(s, slotId)
        }));
    }

    getSlotButtonClass(slot, selectedSlotId) {
        if (!slot.isAvailable) {
            return 'time-slot-button unavailable';
        }
        if (slot.id === selectedSlotId) {
            return 'time-slot-button available selected';
        }
        return 'time-slot-button available';
    }

    async handleScheduleClick() {
        if (this.isScheduleDisabled) {
            return;
        }

        this.isLoading = true;
        this.error = null;
        try {
            await scheduleIRP({
                referralId: this.recordId,
                specialistId: this.selectedSpecialistId,
                scheduledDateTime: this.selectedTimeSlot.startTime,
                durationMinutes: this.selectedTimeSlot.durationMinutes
            });
            this.showToast('Success', 'IRP appointment scheduled successfully', 'success');
            this.resetForm();
        } catch (err) {
            this.error = this.reduceErrors(err);
            this.showToast('Error', 'Failed to schedule appointment', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    resetForm() {
        this.selectedSpecialistId = '';
        this.selectedDate = '';
        this.selectedTimeSlot = null;
        this.timeSlots = [];
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    reduceErrors(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        if (typeof error.message === 'string') {
            return error.message;
        }
        return 'Unknown error';
    }
}