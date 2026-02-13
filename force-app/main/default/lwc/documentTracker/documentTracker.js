import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDocumentChecklist from '@salesforce/apex/ReferralController.getDocumentChecklist';

export default class DocumentTracker extends LightningElement {
    @api recordId;

    documents = [];
    error;
    isLoading = true;
    wiredDocumentsResult;

    @wire(getDocumentChecklist, { referralId: '$recordId' })
    wiredDocuments(result) {
        this.wiredDocumentsResult = result;
        const { error, data } = result;
        this.isLoading = false;
        if (data) {
            this.documents = data.map((doc, index) => ({
                ...doc,
                id: doc.documentName + index,
                statusLabel: doc.isReceived ? 'Received' : 'Pending',
                statusVariant: doc.isReceived ? 'success' : 'warning',
                iconName: doc.isReceived ? 'utility:check' : 'utility:clock',
                iconVariant: doc.isReceived ? 'success' : 'warning',
                formattedDate: doc.uploadedDate ? this.formatDate(doc.uploadedDate) : null,
                rowClass: index % 2 === 0 ? 'document-row even-row' : 'document-row odd-row',
                noFile: !doc.hasFile
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error.body?.message || 'An error occurred while loading documents';
            this.documents = [];
        }
    }

    get hasDocuments() {
        return this.documents && this.documents.length > 0;
    }

    get completionPercentage() {
        if (!this.documents || this.documents.length === 0) {
            return 0;
        }
        const receivedCount = this.documents.filter(doc => doc.isReceived).length;
        return Math.round((receivedCount / this.documents.length) * 100);
    }

    get receivedCount() {
        if (!this.documents) return 0;
        return this.documents.filter(doc => doc.isReceived).length;
    }

    get totalCount() {
        return this.documents ? this.documents.length : 0;
    }

    get progressVariant() {
        const percentage = this.completionPercentage;
        if (percentage === 100) return 'success';
        if (percentage >= 75) return 'active-step';
        if (percentage >= 50) return 'warning';
        return 'expired';
    }

    get cardTitle() {
        return `Document Checklist (${this.receivedCount}/${this.totalCount})`;
    }

    get isComplete() {
        return this.completionPercentage === 100;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get noDocuments() {
        return !this.hasDocuments;
    }

    get noError() {
        return !this.error;
    }

    formatDate(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
    }

    handleRefresh() {
        this.isLoading = true;
        return refreshApex(this.wiredDocumentsResult);
    }
}