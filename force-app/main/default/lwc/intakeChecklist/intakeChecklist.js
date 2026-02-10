import { LightningElement, api, wire } from 'lwc';
import getIntakeChecklist from '@salesforce/apex/ReferralController.getIntakeChecklist';

const CATEGORIES = ['Demographics', 'Contact', 'Insurance', 'Clinical', 'Assignment'];

export default class IntakeChecklist extends LightningElement {
    @api recordId;

    checklist;
    error;

    @wire(getIntakeChecklist, { recordId: '$recordId' })
    wiredChecklist({ error, data }) {
        if (data) {
            this.checklist = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.checklist = undefined;
        }
    }

    get hasData() {
        return this.checklist && !this.error;
    }

    get referralName() {
        return this.checklist?.referralName || '';
    }

    get completionPercentage() {
        return this.checklist?.completionPercentage || 0;
    }

    get completedCount() {
        return this.checklist?.completedCount || 0;
    }

    get totalCount() {
        return this.checklist?.totalCount || 0;
    }

    get progressBarStyle() {
        return `width: ${this.completionPercentage}%`;
    }

    get completionText() {
        return `${this.completedCount} of ${this.totalCount} complete`;
    }

    get groupedItems() {
        if (!this.checklist?.items) {
            return [];
        }

        return CATEGORIES.map(category => {
            const items = this.checklist.items
                .filter(item => item.category === category)
                .map(item => ({
                    ...item,
                    statusIcon: item.isComplete ? 'utility:check' : 'utility:close',
                    statusClass: item.isComplete ? 'item-complete' : 'item-incomplete',
                    key: `${category}-${item.label}`
                }));

            return {
                category,
                items,
                hasItems: items.length > 0
            };
        }).filter(group => group.hasItems);
    }
}