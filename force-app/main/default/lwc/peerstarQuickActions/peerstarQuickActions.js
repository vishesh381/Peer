import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class PeerstarQuickActions extends NavigationMixin(LightningElement) {

    handleNewVisit() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'ServiceAppointment',
                actionName: 'new'
            }
        });
    }

    handleViewCalendar() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Scheduling_Calendar'
            }
        });
    }

    handleViewParticipants() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            },
            state: {
                filterName: 'My_Cases'
            }
        });
    }

    handleNewMeeting() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'WorkOrder',
                actionName: 'new'
            }
        });
    }
}