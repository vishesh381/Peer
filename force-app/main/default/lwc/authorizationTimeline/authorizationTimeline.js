import { LightningElement, api, wire } from 'lwc';
import getAuthorizationTimeline from '@salesforce/apex/ReferralController.getAuthorizationTimeline';

export default class AuthorizationTimeline extends LightningElement {
    @api recordId;

    timelineData;
    error;
    isLoading = true;

    @wire(getAuthorizationTimeline, { referralId: '$recordId' })
    wiredTimeline({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.timelineData = this.processTimelineData(data);
            this.error = undefined;
        } else if (error) {
            this.error = this.reduceErrors(error);
            this.timelineData = undefined;
        }
    }

    processTimelineData(data) {
        // Process events to add computed properties for display
        const processedEvents = data.events ? data.events.map((event, index) => ({
            ...event,
            key: `event-${index}`,
            formattedDate: this.formatDate(event.eventDate),
            isFirst: index === 0,
            isLast: index === data.events.length - 1,
            showConnector: index !== data.events.length - 1
        })) : [];

        return {
            ...data,
            events: processedEvents,
            formattedAuthEndDate: this.formatDate(data.authEndDate),
            expirationText: this.getExpirationText(data.daysUntilExpiration, data.expirationUrgency)
        };
    }

    formatDate(dateValue) {
        if (!dateValue) return 'N/A';
        const date = new Date(dateValue);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    getExpirationText(days, urgency) {
        if (days === null || days === undefined) return 'No expiration date';
        if (urgency === 'Expired') return `Expired ${Math.abs(days)} days ago`;
        if (days === 0) return 'Expires today';
        if (days === 1) return 'Expires tomorrow';
        return `${days} days remaining`;
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error.message) return error.message;
        if (error.body && error.body.message) return error.body.message;
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        return 'Unknown error';
    }

    // Computed properties for template
    get hasData() {
        return this.timelineData !== undefined && this.timelineData !== null;
    }

    get hasEvents() {
        return this.hasData && this.timelineData.events && this.timelineData.events.length > 0;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get showNoDataMessage() {
        return !this.hasData && !this.isLoading && !this.error;
    }

    get maId() {
        return this.timelineData?.maId || 'Not Available';
    }

    get authNumber() {
        return this.timelineData?.authNumber || 'Pending';
    }

    get authStatus() {
        return this.timelineData?.authStatus || 'Unknown';
    }

    get authEndDate() {
        return this.timelineData?.formattedAuthEndDate || 'N/A';
    }

    get authorizedHours() {
        return this.timelineData?.authorizedHours !== null && this.timelineData?.authorizedHours !== undefined
            ? this.timelineData.authorizedHours
            : 'N/A';
    }

    get daysUntilExpiration() {
        return this.timelineData?.daysUntilExpiration;
    }

    get expirationUrgency() {
        return this.timelineData?.expirationUrgency || 'Active';
    }

    get expirationText() {
        return this.timelineData?.expirationText || '';
    }

    get eligibilityVerified() {
        return this.timelineData?.eligibilityVerified === true;
    }

    get events() {
        return this.timelineData?.events || [];
    }

    // Status badge class
    get statusBadgeClass() {
        const status = this.authStatus?.toLowerCase() || '';
        let baseClass = 'slds-badge slds-m-left_x-small';

        if (status.includes('approved') || status.includes('active')) {
            return `${baseClass} slds-theme_success`;
        } else if (status.includes('pending')) {
            return `${baseClass} slds-theme_warning`;
        } else if (status.includes('denied') || status.includes('expired')) {
            return `${baseClass} slds-theme_error`;
        }
        return `${baseClass} slds-badge_lightest`;
    }

    // Expiration urgency styling
    get expirationBadgeClass() {
        const urgency = this.expirationUrgency;
        let baseClass = 'expiration-badge';

        switch (urgency) {
            case 'Expired':
                return `${baseClass} expiration-expired`;
            case 'Critical':
                return `${baseClass} expiration-critical`;
            case 'Warning':
                return `${baseClass} expiration-warning`;
            case 'Upcoming':
                return `${baseClass} expiration-upcoming`;
            case 'Active':
            default:
                return `${baseClass} expiration-active`;
        }
    }

    get expirationIconName() {
        const urgency = this.expirationUrgency;
        switch (urgency) {
            case 'Expired':
                return 'utility:error';
            case 'Critical':
                return 'utility:warning';
            case 'Warning':
                return 'utility:warning';
            case 'Upcoming':
                return 'utility:clock';
            case 'Active':
            default:
                return 'utility:check';
        }
    }

    get eligibilityIconName() {
        return this.eligibilityVerified ? 'utility:check' : 'utility:close';
    }

    get eligibilityVariant() {
        return this.eligibilityVerified ? 'success' : 'error';
    }

    get eligibilityText() {
        return this.eligibilityVerified ? 'Verified' : 'Not Verified';
    }

    // Card title with icon
    get cardTitle() {
        return 'Authorization Timeline';
    }
}