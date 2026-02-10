import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getFollowUpCases from '@salesforce/apex/SchedulingController.getFollowUpCases';

export default class PeerstarFollowUpList extends NavigationMixin(LightningElement) {
    cases = [];
    isLoading = true;
    error;
    wiredCasesResult;

    @wire(getFollowUpCases, { daysAhead: 14 })
    wiredCases(result) {
        this.wiredCasesResult = result;
        this.isLoading = false;
        if (result.data) {
            this.cases = result.data.map(c => ({
                ...c,
                dueText: this.formatDueDate(c.daysUntilDue, c.isOverdue),
                rowClass: c.isOverdue ? 'followup-row overdue' :
                          (c.daysUntilDue <= 7 ? 'followup-row warning' : 'followup-row')
            }));
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.cases = [];
        }
    }

    get hasCases() {
        return this.cases && this.cases.length > 0;
    }

    get caseCount() {
        return this.cases ? this.cases.length : 0;
    }

    formatDueDate(daysUntilDue, isOverdue) {
        if (isOverdue) {
            const daysOverdue = Math.abs(daysUntilDue);
            return daysOverdue === 1 ? '1 day overdue' : `${daysOverdue} days overdue`;
        } else if (daysUntilDue === 0) {
            return 'Due today';
        } else if (daysUntilDue === 1) {
            return 'Due tomorrow';
        } else {
            return `Due in ${daysUntilDue} days`;
        }
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredCasesResult).then(() => {
            this.isLoading = false;
        });
    }

    handleViewCase(event) {
        const caseId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: caseId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    handleScheduleFollowUp(event) {
        const caseId = event.currentTarget.dataset.id;
        // Navigate to new ServiceAppointment with pre-populated case
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'ServiceAppointment',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: `ParentRecordId=${caseId}`
            }
        });
    }
}