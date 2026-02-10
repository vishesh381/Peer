import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getExpiringAuthorizations from '@salesforce/apex/ReferralController.getExpiringAuthorizations';

export default class AuthExpirationAlerts extends NavigationMixin(LightningElement) {
    alerts = [];
    error;
    isLoading = true;

    @wire(getExpiringAuthorizations)
    wiredAlerts({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.alerts = this.sortByUrgency(data);
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.alerts = [];
        }
    }

    get hasAlerts() {
        return this.alerts && this.alerts.length > 0;
    }

    get expiredAlerts() {
        return this.alerts.filter(alert => alert.urgencyLevel === 'Expired');
    }

    get criticalAlerts() {
        return this.alerts.filter(alert => alert.urgencyLevel === 'Critical');
    }

    get warningAlerts() {
        return this.alerts.filter(alert => alert.urgencyLevel === 'Warning');
    }

    get upcomingAlerts() {
        return this.alerts.filter(alert => alert.urgencyLevel === 'Upcoming');
    }

    get hasExpired() {
        return this.expiredAlerts.length > 0;
    }

    get hasCritical() {
        return this.criticalAlerts.length > 0;
    }

    get hasWarning() {
        return this.warningAlerts.length > 0;
    }

    get hasUpcoming() {
        return this.upcomingAlerts.length > 0;
    }

    sortByUrgency(data) {
        const urgencyOrder = {
            'Expired': 0,
            'Critical': 1,
            'Warning': 2,
            'Upcoming': 3
        };

        return [...data].sort((a, b) => {
            const orderDiff = urgencyOrder[a.urgencyLevel] - urgencyOrder[b.urgencyLevel];
            if (orderDiff !== 0) {
                return orderDiff;
            }
            return a.daysUntilExpiration - b.daysUntilExpiration;
        });
    }

    handleNavigateToRecord(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Referral__c',
                actionName: 'view'
            }
        });
    }

    getBadgeClass(urgencyLevel) {
        const baseClass = 'slds-badge urgency-badge';
        switch (urgencyLevel) {
            case 'Expired':
                return `${baseClass} urgency-expired`;
            case 'Critical':
                return `${baseClass} urgency-critical`;
            case 'Warning':
                return `${baseClass} urgency-warning`;
            case 'Upcoming':
                return `${baseClass} urgency-upcoming`;
            default:
                return baseClass;
        }
    }

    formatDate(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    getDaysText(days) {
        if (days < 0) {
            const absDays = Math.abs(days);
            return `${absDays} day${absDays !== 1 ? 's' : ''} overdue`;
        } else if (days === 0) {
            return 'Expires today';
        } else {
            return `${days} day${days !== 1 ? 's' : ''} remaining`;
        }
    }
}