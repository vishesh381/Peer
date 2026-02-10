import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getPeerSpecialistMetrics from '@salesforce/apex/SchedulingController.getPeerSpecialistMetrics';
import getDayRouteVisits from '@salesforce/apex/SchedulingController.getDayRouteVisits';
import checkInVisit from '@salesforce/apex/SchedulingController.checkInVisit';
import checkOutVisit from '@salesforce/apex/SchedulingController.checkOutVisit';

export default class PeerstarMobileQuickActions extends NavigationMixin(LightningElement) {
    @track metrics = {};
    @track nextVisit = null;
    @track isLoading = true;
    @track error;
    @track isProcessing = false;

    wiredMetricsResult;
    wiredVisitsResult;

    @wire(getPeerSpecialistMetrics)
    wiredMetrics(result) {
        this.wiredMetricsResult = result;
        if (result.data) {
            this.metrics = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
        }
    }

    @wire(getDayRouteVisits, { targetDate: '$todayDate', specialistId: null })
    wiredVisits(result) {
        this.wiredVisitsResult = result;
        this.isLoading = false;
        if (result.data && result.data.length > 0) {
            // Find next visit (first non-completed)
            const upcoming = result.data.find(v =>
                v.status !== 'Completed' && v.status !== 'Cannot Complete'
            );
            if (upcoming) {
                this.nextVisit = {
                    ...upcoming,
                    canCheckIn: upcoming.status !== 'In Progress',
                    canCheckOut: upcoming.status === 'In Progress'
                };
            } else {
                this.nextVisit = null;
            }
        }
    }

    get todayDate() {
        return new Date().toISOString().split('T')[0];
    }

    get hasNextVisit() {
        return this.nextVisit !== null;
    }

    get greeting() {
        const hour = new Date().getHours();
        if (hour < 12) return 'Good Morning';
        if (hour < 17) return 'Good Afternoon';
        return 'Good Evening';
    }

    get todayVisitsText() {
        const count = this.metrics?.todayCount || 0;
        return count === 1 ? '1 visit today' : `${count} visits today`;
    }

    get pendingFollowUpsText() {
        const count = this.metrics?.followUpsNeededCount || 0;
        return count === 1 ? '1 follow-up needed' : `${count} follow-ups needed`;
    }

    handleViewCalendar() {
        // Navigate to calendar tab/page
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Peerstar_Calendar'
            }
        });
    }

    handleViewVisit() {
        if (this.nextVisit) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.nextVisit.visitId,
                    actionName: 'view'
                }
            });
        }
    }

    handleGetDirections() {
        if (this.nextVisit?.mapsUrl) {
            window.open(this.nextVisit.mapsUrl, '_blank');
        }
    }

    async handleCheckIn() {
        if (!this.nextVisit) return;

        this.isProcessing = true;

        try {
            // Try to get location
            let latitude = null;
            let longitude = null;

            if (navigator.geolocation) {
                try {
                    const position = await new Promise((resolve, reject) => {
                        navigator.geolocation.getCurrentPosition(resolve, reject, {
                            enableHighAccuracy: true,
                            timeout: 10000
                        });
                    });
                    latitude = position.coords.latitude;
                    longitude = position.coords.longitude;
                } catch (geoError) {
                    console.log('Location not available:', geoError);
                }
            }

            await checkInVisit({
                visitId: this.nextVisit.visitId,
                latitude: latitude,
                longitude: longitude
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Checked In',
                    message: 'You are now checked in to your visit.',
                    variant: 'success'
                })
            );

            await this.refreshData();

        } catch (error) {
            console.error('Check-in error:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to check in.',
                    variant: 'error'
                })
            );
        } finally {
            this.isProcessing = false;
        }
    }

    async handleCheckOut() {
        if (!this.nextVisit) return;

        this.isProcessing = true;

        try {
            // Try to get location
            let latitude = null;
            let longitude = null;

            if (navigator.geolocation) {
                try {
                    const position = await new Promise((resolve, reject) => {
                        navigator.geolocation.getCurrentPosition(resolve, reject, {
                            enableHighAccuracy: true,
                            timeout: 10000
                        });
                    });
                    latitude = position.coords.latitude;
                    longitude = position.coords.longitude;
                } catch (geoError) {
                    console.log('Location not available:', geoError);
                }
            }

            const result = await checkOutVisit({
                visitId: this.nextVisit.visitId,
                latitude: latitude,
                longitude: longitude
            });

            const duration = result.actualDuration ? ` (${result.actualDuration} min)` : '';

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Checked Out',
                    message: `Visit completed${duration}.`,
                    variant: 'success'
                })
            );

            await this.refreshData();

        } catch (error) {
            console.error('Check-out error:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || 'Failed to check out.',
                    variant: 'error'
                })
            );
        } finally {
            this.isProcessing = false;
        }
    }

    async refreshData() {
        await Promise.all([
            refreshApex(this.wiredMetricsResult),
            refreshApex(this.wiredVisitsResult)
        ]);
    }

    handleNewVisit() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'ServiceAppointment',
                actionName: 'new'
            }
        });
    }
}