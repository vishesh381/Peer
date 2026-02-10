/**
 * @description Handler class for ScheduledServiceTrigger
 *              Manages conflict validation, reschedule tracking, and status changes
 * @author Peerstar Development Team
 */
public with sharing class ScheduledServiceTriggerHandler {

    /**
     * @description Before insert handler - validates conflicts and sets defaults
     * @param newServices List of new Scheduled_Service__c records
     */
    public void beforeInsert(List<Scheduled_Service__c> newServices) {
        validateNoConflicts(newServices, null);
        setDefaults(newServices);
    }

    /**
     * @description Before update handler - validates conflicts and tracks reschedules
     * @param newServices List of updated Scheduled_Service__c records
     * @param oldMap Map of old record values
     */
    public void beforeUpdate(List<Scheduled_Service__c> newServices,
                            Map<Id, Scheduled_Service__c> oldMap) {
        validateNoConflicts(newServices, oldMap);
        trackReschedules(newServices, oldMap);
    }

    /**
     * @description After update handler - handles status change side effects
     * @param newServices List of updated Scheduled_Service__c records
     * @param oldMap Map of old record values
     */
    public void afterUpdate(List<Scheduled_Service__c> newServices,
                           Map<Id, Scheduled_Service__c> oldMap) {
        handleStatusChanges(newServices, oldMap);
    }

    /**
     * @description Validates that new/updated services don't conflict with existing ones
     * @param services List of services to validate
     * @param oldMap Map of old values (null for inserts)
     */
    private void validateNoConflicts(List<Scheduled_Service__c> services,
                                     Map<Id, Scheduled_Service__c> oldMap) {
        for (Scheduled_Service__c service : services) {
            // Skip validation for canceled or completed appointments
            if (service.Status__c == 'Canceled' || service.Status__c == 'Completed' ||
                service.Status__c == 'No Show') {
                continue;
            }

            // Skip if no scheduled times set yet
            if (service.Scheduled_Start__c == null || service.Scheduled_End__c == null) {
                continue;
            }

            // Skip if assigned user not set
            if (service.Assigned_User__c == null) {
                continue;
            }

            // For updates, check if the schedule actually changed
            if (oldMap != null) {
                Scheduled_Service__c oldService = oldMap.get(service.Id);
                if (oldService.Scheduled_Start__c == service.Scheduled_Start__c &&
                    oldService.Scheduled_End__c == service.Scheduled_End__c &&
                    oldService.Assigned_User__c == service.Assigned_User__c) {
                    continue; // No schedule change, skip validation
                }
            }

            // Check for conflicts
            Id excludeId = (oldMap != null) ? service.Id : null;
            List<SchedulingConflictService.ConflictResult> conflicts =
                SchedulingConflictService.checkConflicts(
                    service.Assigned_User__c,
                    service.Scheduled_Start__c,
                    service.Scheduled_End__c,
                    excludeId
                );

            if (!conflicts.isEmpty()) {
                String errorMsg = 'Scheduling conflict detected: ' + conflicts[0].conflictMessage;
                service.addError(errorMsg);
            }
        }
    }

    /**
     * @description Sets default values for new services
     * @param services List of new services
     */
    private void setDefaults(List<Scheduled_Service__c> services) {
        for (Scheduled_Service__c service : services) {
            // Set default status if not provided
            if (String.isBlank(service.Status__c)) {
                if (service.Scheduled_Start__c != null) {
                    service.Status__c = 'Scheduled';
                } else {
                    service.Status__c = 'Pending';
                }
            }

            // Calculate duration if start and end are set but duration is not
            if (service.Scheduled_Start__c != null && service.Scheduled_End__c != null &&
                service.Duration_Minutes__c == null) {
                Long milliseconds = service.Scheduled_End__c.getTime() -
                                   service.Scheduled_Start__c.getTime();
                service.Duration_Minutes__c = milliseconds / 60000;
            }

            // Set end time if start and duration are set but end is not
            if (service.Scheduled_Start__c != null && service.Duration_Minutes__c != null &&
                service.Scheduled_End__c == null) {
                service.Scheduled_End__c = service.Scheduled_Start__c.addMinutes(
                    Integer.valueOf(service.Duration_Minutes__c)
                );
            }

            // Initialize reschedule count
            if (service.Reschedule_Count__c == null) {
                service.Reschedule_Count__c = 0;
            }
        }
    }

    /**
     * @description Tracks when appointments are rescheduled
     * @param services List of updated services
     * @param oldMap Map of old values
     */
    private void trackReschedules(List<Scheduled_Service__c> services,
                                  Map<Id, Scheduled_Service__c> oldMap) {
        for (Scheduled_Service__c service : services) {
            Scheduled_Service__c oldService = oldMap.get(service.Id);

            // Check if the scheduled time changed
            Boolean startChanged = service.Scheduled_Start__c != oldService.Scheduled_Start__c;
            Boolean wasScheduled = oldService.Scheduled_Start__c != null;

            if (startChanged && wasScheduled &&
                service.Status__c != 'Canceled' && service.Status__c != 'Completed') {

                // Store original scheduled start if this is the first reschedule
                if (service.Original_Scheduled_Start__c == null && oldService.Scheduled_Start__c != null) {
                    service.Original_Scheduled_Start__c = oldService.Scheduled_Start__c;
                }

                // Increment reschedule count
                if (service.Reschedule_Count__c == null) {
                    service.Reschedule_Count__c = 1;
                } else {
                    service.Reschedule_Count__c = service.Reschedule_Count__c + 1;
                }
            }
        }
    }

    /**
     * @description Handles side effects of status changes (e.g., no-shows, cancellations)
     * @param services List of updated services
     * @param oldMap Map of old values
     */
    private void handleStatusChanges(List<Scheduled_Service__c> services,
                                     Map<Id, Scheduled_Service__c> oldMap) {
        Set<Id> caseIdsForNoShow = new Set<Id>();
        List<Task> tasksToCreate = new List<Task>();

        for (Scheduled_Service__c service : services) {
            Scheduled_Service__c oldService = oldMap.get(service.Id);

            // Check if status changed
            if (service.Status__c != oldService.Status__c) {

                // Handle No Show - create follow-up task and track on case
                if (service.Status__c == 'No Show') {
                    caseIdsForNoShow.add(service.Case__c);

                    Task followUp = new Task(
                        Subject = 'Follow up on missed appointment',
                        WhatId = service.Case__c,
                        OwnerId = service.Assigned_User__c,
                        Priority = 'High',
                        Status = 'Not Started',
                        ActivityDate = Date.today().addDays(1),
                        Description = 'Peer missed scheduled ' + service.Service_Type__c +
                                     ' on ' + service.Scheduled_Start__c.format('MMM d, yyyy h:mm a') +
                                     '. Please follow up to reschedule.'
                    );
                    tasksToCreate.add(followUp);
                }

                // Handle multiple reschedules - alert supervisor
                if (service.Reschedule_Count__c != null && service.Reschedule_Count__c >= 3 &&
                    oldService.Reschedule_Count__c < 3) {

                    Task supervisorAlert = new Task(
                        Subject = 'Multiple Reschedules Alert',
                        WhatId = service.Case__c,
                        Priority = 'High',
                        Status = 'Not Started',
                        ActivityDate = Date.today(),
                        Description = 'This appointment has been rescheduled ' +
                                     service.Reschedule_Count__c + ' times. Please review.'
                    );
                    tasksToCreate.add(supervisorAlert);
                }
            }
        }

        // Update no-show counts on cases
        if (!caseIdsForNoShow.isEmpty()) {
            List<Case> casesToUpdate = [
                SELECT Id, No_Show_Count__c
                FROM Case
                WHERE Id IN :caseIdsForNoShow
            ];

            for (Case c : casesToUpdate) {
                if (c.No_Show_Count__c == null) {
                    c.No_Show_Count__c = 1;
                } else {
                    c.No_Show_Count__c = c.No_Show_Count__c + 1;
                }
            }

            if (!casesToUpdate.isEmpty()) {
                update casesToUpdate;
            }
        }

        // Create follow-up tasks
        if (!tasksToCreate.isEmpty()) {
            insert tasksToCreate;
        }
    }
}