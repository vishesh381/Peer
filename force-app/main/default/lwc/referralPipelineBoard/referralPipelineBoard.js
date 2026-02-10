import { LightningElement, wire, track } from 'lwc';
import getReferralPipeline from '@salesforce/apex/ReferralController.getReferralPipeline';
import updateReferralStage from '@salesforce/apex/ReferralController.updateReferralStage';

export default class ReferralPipelineBoard extends LightningElement {
    @track stages = [];
    @track referralsByStage = {};
    @track stageCounts = {};
    @track isLoading = true;
    @track error;

    draggedReferralId;
    draggedFromStage;

    @wire(getReferralPipeline)
    wiredPipeline({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.stages = data.stages || [];
            this.referralsByStage = data.referralsByStage || {};
            this.stageCounts = data.stageCounts || {};
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'Error loading referral pipeline';
            this.stages = [];
            this.referralsByStage = {};
            this.stageCounts = {};
        }
    }

    get stageColumns() {
        return this.stages.map((stage) => {
            const referrals = this.referralsByStage[stage] || [];
            return {
                name: stage,
                count: this.stageCounts[stage] || 0,
                referrals: referrals,
                hasNoReferrals: referrals.length === 0
            };
        });
    }

    get hasError() {
        return !!this.error;
    }

    get notLoading() {
        return !this.isLoading;
    }

    handleDragStart(event) {
        const referralId = event.target.dataset.id;
        const stage = event.target.dataset.stage;
        this.draggedReferralId = referralId;
        this.draggedFromStage = stage;
        event.target.classList.add('dragging');
    }

    handleDragEnd(event) {
        event.target.classList.remove('dragging');
    }

    handleDragOver(event) {
        event.preventDefault();
        const column = event.currentTarget;
        column.classList.add('drag-over');
    }

    handleDragLeave(event) {
        const column = event.currentTarget;
        column.classList.remove('drag-over');
    }

    handleDrop(event) {
        event.preventDefault();
        const column = event.currentTarget;
        column.classList.remove('drag-over');

        const newStage = column.dataset.stage;

        if (this.draggedFromStage === newStage) {
            return;
        }

        this.moveReferralToStage(this.draggedReferralId, this.draggedFromStage, newStage);
    }

    async moveReferralToStage(referralId, fromStage, toStage) {
        // Optimistic UI update
        const referralIndex = this.referralsByStage[fromStage]?.findIndex(
            (ref) => ref.id === referralId
        );

        if (referralIndex === -1 || referralIndex === undefined) {
            return;
        }

        const referral = { ...this.referralsByStage[fromStage][referralIndex] };
        referral.stage = toStage;

        // Update local state
        const updatedFromStage = [...this.referralsByStage[fromStage]];
        updatedFromStage.splice(referralIndex, 1);

        const updatedToStage = [...(this.referralsByStage[toStage] || [])];
        updatedToStage.push(referral);

        this.referralsByStage = {
            ...this.referralsByStage,
            [fromStage]: updatedFromStage,
            [toStage]: updatedToStage
        };

        this.stageCounts = {
            ...this.stageCounts,
            [fromStage]: (this.stageCounts[fromStage] || 1) - 1,
            [toStage]: (this.stageCounts[toStage] || 0) + 1
        };

        try {
            await updateReferralStage({ referralId, newStage: toStage });
        } catch (error) {
            // Revert on error
            this.referralsByStage = {
                ...this.referralsByStage,
                [fromStage]: [...updatedFromStage, referral],
                [toStage]: updatedToStage.filter((ref) => ref.id !== referralId)
            };

            this.stageCounts = {
                ...this.stageCounts,
                [fromStage]: (this.stageCounts[fromStage] || 0) + 1,
                [toStage]: (this.stageCounts[toStage] || 1) - 1
            };

            this.error = error.body?.message || 'Error updating referral stage';
        }
    }

    getUrgencyClass(daysOpen) {
        if (daysOpen > 14) {
            return 'urgency-error';
        } else if (daysOpen > 7) {
            return 'urgency-warning';
        }
        return 'urgency-success';
    }
}