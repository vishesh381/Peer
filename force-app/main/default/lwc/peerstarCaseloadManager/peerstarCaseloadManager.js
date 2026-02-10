import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getCaseloadSummary from '@salesforce/apex/SchedulingController.getCaseloadSummary';
import getSpecialistCases from '@salesforce/apex/SchedulingController.getSpecialistCases';
import getUnassignedCases from '@salesforce/apex/SchedulingController.getUnassignedCases';
import reassignCase from '@salesforce/apex/SchedulingController.reassignCase';
import getPeerSpecialists from '@salesforce/apex/SchedulingController.getPeerSpecialists';

export default class PeerstarCaseloadManager extends NavigationMixin(LightningElement) {
    @track caseloads = [];
    @track selectedSpecialist = null;
    @track specialistCases = [];
    @track unassignedCases = [];
    @track specialists = [];
    @track isLoading = true;
    @track error;

    // View state
    @track currentView = 'overview'; // 'overview', 'specialist', 'unassigned'
    @track includeInactive = false;

    // Reassign modal
    @track showReassignModal = false;
    @track caseToReassign = null;
    @track newSpecialistId = '';
    @track isReassigning = false;

    wiredCaseloadResult;
    wiredUnassignedResult;

    @wire(getPeerSpecialists)
    wiredSpecialists({ error, data }) {
        if (data) {
            this.specialists = data.map(s => ({ label: s.name, value: s.id }));
        } else if (error) {
            console.error('Error loading specialists:', error);
        }
    }

    @wire(getCaseloadSummary)
    wiredCaseloads(result) {
        this.wiredCaseloadResult = result;
        this.isLoading = false;
        if (result.data) {
            this.caseloads = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.caseloads = [];
        }
    }

    @wire(getUnassignedCases)
    wiredUnassigned(result) {
        this.wiredUnassignedResult = result;
        if (result.data) {
            this.unassignedCases = result.data;
        } else if (result.error) {
            console.error('Error loading unassigned cases:', error);
            this.unassignedCases = [];
        }
    }

    get isOverview() {
        return this.currentView === 'overview';
    }

    get isSpecialistView() {
        return this.currentView === 'specialist';
    }

    get isUnassignedView() {
        return this.currentView === 'unassigned';
    }

    get overviewButtonVariant() {
        return this.isOverview ? 'brand' : 'neutral';
    }

    get unassignedButtonVariant() {
        return this.isUnassignedView ? 'brand' : 'neutral';
    }

    get unassignedButtonLabel() {
        return `Unassigned (${this.unassignedCount})`;
    }

    get hasCaseloads() {
        return this.caseloads && this.caseloads.length > 0;
    }

    get hasSpecialistCases() {
        return this.specialistCases && this.specialistCases.length > 0;
    }

    get hasUnassignedCases() {
        return this.unassignedCases && this.unassignedCases.length > 0;
    }

    get unassignedCount() {
        return this.unassignedCases.length;
    }

    get totalActiveCases() {
        return this.caseloads.reduce((sum, c) => sum + c.activeCases, 0);
    }

    get avgCaseload() {
        if (this.caseloads.length === 0) return 0;
        return Math.round(this.totalActiveCases / this.caseloads.length);
    }

    get reassignSpecialistOptions() {
        // Filter out current specialist if we have one
        const currentId = this.caseToReassign?.specialistId;
        return this.specialists.filter(s => s.value !== currentId);
    }

    handleViewOverview() {
        this.currentView = 'overview';
        this.selectedSpecialist = null;
    }

    handleViewUnassigned() {
        this.currentView = 'unassigned';
        this.selectedSpecialist = null;
    }

    async handleSpecialistClick(event) {
        const userId = event.currentTarget.dataset.userid;
        const specialist = this.caseloads.find(c => c.userId === userId);

        this.selectedSpecialist = specialist;
        this.currentView = 'specialist';
        this.isLoading = true;

        try {
            const cases = await getSpecialistCases({
                specialistId: userId,
                includeInactive: this.includeInactive
            });
            this.specialistCases = cases;
        } catch (error) {
            console.error('Error loading specialist cases:', error);
            this.specialistCases = [];
        } finally {
            this.isLoading = false;
        }
    }

    async handleIncludeInactiveChange(event) {
        this.includeInactive = event.target.checked;
        if (this.selectedSpecialist) {
            this.isLoading = true;
            try {
                const cases = await getSpecialistCases({
                    specialistId: this.selectedSpecialist.userId,
                    includeInactive: this.includeInactive
                });
                this.specialistCases = cases;
            } catch (error) {
                console.error('Error loading specialist cases:', error);
            } finally {
                this.isLoading = false;
            }
        }
    }

    handleCaseClick(event) {
        const caseId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: caseId,
                actionName: 'view'
            }
        });
    }

    handleReassignClick(event) {
        event.stopPropagation();
        const caseId = event.currentTarget.dataset.id;
        const cases = this.currentView === 'unassigned' ? this.unassignedCases : this.specialistCases;
        this.caseToReassign = cases.find(c => c.caseId === caseId);
        this.caseToReassign.specialistId = this.selectedSpecialist?.userId;
        this.newSpecialistId = '';
        this.showReassignModal = true;
    }

    handleNewSpecialistChange(event) {
        this.newSpecialistId = event.detail.value;
    }

    handleCloseReassignModal() {
        this.showReassignModal = false;
        this.caseToReassign = null;
        this.newSpecialistId = '';
    }

    async handleConfirmReassign() {
        if (!this.newSpecialistId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please select a specialist to reassign to.',
                    variant: 'error'
                })
            );
            return;
        }

        this.isReassigning = true;

        try {
            await reassignCase({
                caseId: this.caseToReassign.caseId,
                newSpecialistId: this.newSpecialistId
            });

            const newSpecialist = this.specialists.find(s => s.value === this.newSpecialistId);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: `Case reassigned to ${newSpecialist?.label || 'specialist'}.`,
                    variant: 'success'
                })
            );

            this.handleCloseReassignModal();

            // Refresh data
            await refreshApex(this.wiredCaseloadResult);
            await refreshApex(this.wiredUnassignedResult);

            // If viewing specialist, refresh their cases
            if (this.selectedSpecialist) {
                const cases = await getSpecialistCases({
                    specialistId: this.selectedSpecialist.userId,
                    includeInactive: this.includeInactive
                });
                this.specialistCases = cases;
            }

        } catch (error) {
            console.error('Error reassigning case:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to reassign case.',
                    variant: 'error'
                })
            );
        } finally {
            this.isReassigning = false;
        }
    }

    async handleRefresh() {
        this.isLoading = true;
        await refreshApex(this.wiredCaseloadResult);
        await refreshApex(this.wiredUnassignedResult);
        this.isLoading = false;
    }
}