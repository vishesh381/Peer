import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getParticipantPrepData from '@salesforce/apex/SchedulingController.getParticipantPrepData';

export default class PeerstarVisitPrepCard extends NavigationMixin(LightningElement) {
    @api recordId;
    @track prepData;
    @track error;
    @track isLoading = true;
    @track showNotesModal = false;
    @track selectedNote;

    @wire(getParticipantPrepData, { visitId: '$recordId' })
    wiredPrepData({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.prepData = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.prepData = undefined;
        }
    }

    get hasData() {
        return this.prepData != null;
    }

    get hasRecentNotes() {
        return this.prepData?.recentNotes?.length > 0;
    }

    get hasGoals() {
        return this.prepData?.currentGoals != null;
    }

    get hasContactPreferences() {
        return this.prepData?.contactPreferences != null;
    }

    get noPhone() {
        return !this.prepData?.phone;
    }

    get noEmail() {
        return !this.prepData?.email;
    }

    get hoursRemainingClass() {
        if (this.prepData?.hoursRemaining == null) return '';
        if (this.prepData.hoursRemaining <= 5) return 'slds-text-color_error';
        if (this.prepData.hoursRemaining <= 10) return 'slds-text-color_warning';
        return '';
    }

    get alertClass() {
        return this.prepData?.hasAlerts ? 'alert-box slds-theme_error' : '';
    }

    get formattedFollowUpDate() {
        if (!this.prepData?.followUpDueDate) return 'Not set';
        const date = new Date(this.prepData.followUpDueDate);
        return date.toLocaleDateString();
    }

    get followUpStatus() {
        if (this.prepData?.followUpCompleted) return 'Completed';
        if (!this.prepData?.followUpDueDate) return 'Not set';
        const dueDate = new Date(this.prepData.followUpDueDate);
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        if (dueDate < today) return 'Overdue';
        const daysUntil = Math.ceil((dueDate - today) / (1000 * 60 * 60 * 24));
        if (daysUntil <= 7) return `Due in ${daysUntil} days`;
        return 'On track';
    }

    get followUpStatusClass() {
        const status = this.followUpStatus;
        if (status === 'Overdue') return 'slds-badge slds-theme_error';
        if (status.includes('Due in')) return 'slds-badge slds-theme_warning';
        if (status === 'Completed') return 'slds-badge slds-theme_success';
        return 'slds-badge';
    }

    handleNavigateToCase() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.prepData.caseId,
                actionName: 'view'
            }
        });
    }

    handleNavigateToContact() {
        if (this.prepData?.contactId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.prepData.contactId,
                    actionName: 'view'
                }
            });
        }
    }

    handleCallPhone() {
        if (this.prepData?.phone) {
            window.location.href = `tel:${this.prepData.phone}`;
        }
    }

    handleSendEmail() {
        if (this.prepData?.email) {
            window.location.href = `mailto:${this.prepData.email}`;
        }
    }

    handleViewNote(event) {
        const noteId = event.currentTarget.dataset.id;
        this.selectedNote = this.prepData.recentNotes.find(n => n.visitId === noteId);
        this.showNotesModal = true;
    }

    handleCloseModal() {
        this.showNotesModal = false;
        this.selectedNote = null;
    }

    handleNavigateToVisit() {
        if (this.selectedNote?.visitId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.selectedNote.visitId,
                    actionName: 'view'
                }
            });
        }
    }
}