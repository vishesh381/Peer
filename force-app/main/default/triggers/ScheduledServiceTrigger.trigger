/**
 * @description Trigger for Scheduled_Service__c to handle validation and automation
 * @author Peerstar Development Team
 */
trigger ScheduledServiceTrigger on Scheduled_Service__c (before insert, before update, after update) {
    ScheduledServiceTriggerHandler handler = new ScheduledServiceTriggerHandler();

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isUpdate) {
            handler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}