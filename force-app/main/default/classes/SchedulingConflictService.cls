/**
 * @description Service class for detecting and managing scheduling conflicts
 *              for Scheduled_Service__c records. Provides conflict checking
 *              against existing appointments and staff availability.
 * @author Peerstar Development Team
 */
public with sharing class SchedulingConflictService {

    /**
     * @description Result wrapper for conflict check operations
     */
    public class ConflictResult {
        @AuraEnabled public Boolean hasConflict { get; set; }
        @AuraEnabled public String conflictType { get; set; }
        @AuraEnabled public String conflictMessage { get; set; }
        @AuraEnabled public DateTime conflictStart { get; set; }
        @AuraEnabled public DateTime conflictEnd { get; set; }
        @AuraEnabled public Id conflictingRecordId { get; set; }

        public ConflictResult(String message, DateTime startTime, DateTime endTime) {
            this.hasConflict = true;
            this.conflictMessage = message;
            this.conflictStart = startTime;
            this.conflictEnd = endTime;
        }

        public ConflictResult() {
            this.hasConflict = false;
        }
    }

    /**
     * @description Request wrapper for invocable conflict checking
     */
    public class ConflictCheckRequest {
        @InvocableVariable(required=true label='Staff User ID')
        public Id userId;

        @InvocableVariable(required=true label='Proposed Start Time')
        public DateTime proposedStart;

        @InvocableVariable(required=true label='Proposed End Time')
        public DateTime proposedEnd;

        @InvocableVariable(label='Exclude Record ID')
        public Id excludeRecordId;
    }

    /**
     * @description Response wrapper for invocable conflict checking
     */
    public class ConflictCheckResponse {
        @InvocableVariable(label='Has Conflicts')
        public Boolean hasConflicts;

        @InvocableVariable(label='Conflict Details')
        public String conflictDetails;

        @InvocableVariable(label='Number of Conflicts')
        public Integer conflictCount;
    }

    /**
     * @description Invocable method for Flow/Process Builder to check scheduling conflicts
     * @param requests List of conflict check requests
     * @return List of conflict check responses
     */
    @InvocableMethod(label='Check Scheduling Conflicts'
                     description='Checks for scheduling conflicts for a given staff member and time window')
    public static List<ConflictCheckResponse> checkConflictsInvocable(List<ConflictCheckRequest> requests) {
        List<ConflictCheckResponse> responses = new List<ConflictCheckResponse>();

        for (ConflictCheckRequest request : requests) {
            ConflictCheckResponse response = new ConflictCheckResponse();

            List<ConflictResult> conflicts = checkConflicts(
                request.userId,
                request.proposedStart,
                request.proposedEnd,
                request.excludeRecordId
            );

            response.hasConflicts = !conflicts.isEmpty();
            response.conflictCount = conflicts.size();

            if (!conflicts.isEmpty()) {
                List<String> messages = new List<String>();
                for (ConflictResult conflict : conflicts) {
                    messages.add(conflict.conflictMessage);
                }
                response.conflictDetails = String.join(messages, '; ');
            }

            responses.add(response);
        }

        return responses;
    }

    /**
     * @description Main method to check for scheduling conflicts
     * @param userId The staff member's User ID
     * @param proposedStart Proposed appointment start time
     * @param proposedEnd Proposed appointment end time
     * @param excludeRecordId Optional - exclude this record from conflict check (for updates)
     * @return List of ConflictResult objects describing any conflicts found
     */
    public static List<ConflictResult> checkConflicts(
            Id userId,
            DateTime proposedStart,
            DateTime proposedEnd,
            Id excludeRecordId) {

        List<ConflictResult> conflicts = new List<ConflictResult>();

        // Check for conflicts with existing scheduled services
        conflicts.addAll(checkScheduledServiceConflicts(userId, proposedStart, proposedEnd, excludeRecordId));

        // Check for conflicts with staff availability (PTO, blocked time)
        conflicts.addAll(checkAvailabilityConflicts(userId, proposedStart, proposedEnd));

        return conflicts;
    }

    /**
     * @description Overload without excludeRecordId for new appointments
     */
    public static List<ConflictResult> checkConflicts(
            Id userId,
            DateTime proposedStart,
            DateTime proposedEnd) {
        return checkConflicts(userId, proposedStart, proposedEnd, null);
    }

    /**
     * @description Check for conflicts with existing Scheduled_Service__c records
     */
    private static List<ConflictResult> checkScheduledServiceConflicts(
            Id userId,
            DateTime proposedStart,
            DateTime proposedEnd,
            Id excludeRecordId) {

        List<ConflictResult> conflicts = new List<ConflictResult>();

        // Build query to find overlapping appointments
        // Overlap condition: (StartA < EndB) AND (EndA > StartB)
        String query = 'SELECT Id, Name, Scheduled_Start__c, Scheduled_End__c, ' +
                       'Service_Type__c, Case__r.Contact.Name ' +
                       'FROM Scheduled_Service__c ' +
                       'WHERE Assigned_User__c = :userId ' +
                       'AND Status__c NOT IN (\'Canceled\', \'Completed\', \'No Show\') ' +
                       'AND Scheduled_Start__c < :proposedEnd ' +
                       'AND Scheduled_End__c > :proposedStart';

        if (excludeRecordId != null) {
            query += ' AND Id != :excludeRecordId';
        }

        List<Scheduled_Service__c> existingServices = Database.query(query);

        for (Scheduled_Service__c service : existingServices) {
            String peerName = service.Case__r?.Contact?.Name;
            String message = 'Conflict with existing ' + service.Service_Type__c;
            if (String.isNotBlank(peerName)) {
                message += ' for ' + peerName;
            }
            message += ' (' + formatDateTime(service.Scheduled_Start__c) + ' - ' +
                       formatTime(service.Scheduled_End__c) + ')';

            ConflictResult conflict = new ConflictResult(
                message,
                service.Scheduled_Start__c,
                service.Scheduled_End__c
            );
            conflict.conflictType = 'Existing Appointment';
            conflict.conflictingRecordId = service.Id;
            conflicts.add(conflict);
        }

        return conflicts;
    }

    /**
     * @description Check for conflicts with staff availability records (PTO, blocked time)
     */
    private static List<ConflictResult> checkAvailabilityConflicts(
            Id userId,
            DateTime proposedStart,
            DateTime proposedEnd) {

        List<ConflictResult> conflicts = new List<ConflictResult>();

        // Get the date range we need to check
        Date startDate = proposedStart.date();
        Date endDate = proposedEnd.date();

        // Query for PTO or Blocked availability on those dates
        List<Staff_Availability__c> unavailable = [
            SELECT Id, Date__c, Start_Time__c, End_Time__c, Availability_Type__c, Notes__c
            FROM Staff_Availability__c
            WHERE User__c = :userId
            AND Date__c >= :startDate
            AND Date__c <= :endDate
            AND Availability_Type__c IN ('PTO', 'Blocked')
        ];

        for (Staff_Availability__c avail : unavailable) {
            // Convert availability times to DateTime for comparison
            DateTime availStart = DateTime.newInstance(
                avail.Date__c,
                avail.Start_Time__c
            );
            DateTime availEnd = DateTime.newInstance(
                avail.Date__c,
                avail.End_Time__c
            );

            // Check for overlap
            if (proposedStart < availEnd && proposedEnd > availStart) {
                String message = 'Staff is marked as ' + avail.Availability_Type__c;
                if (String.isNotBlank(avail.Notes__c)) {
                    message += ' (' + avail.Notes__c + ')';
                }
                message += ' on ' + avail.Date__c.format() + ' from ' +
                           formatTime(availStart) + ' to ' + formatTime(availEnd);

                ConflictResult conflict = new ConflictResult(
                    message,
                    availStart,
                    availEnd
                );
                conflict.conflictType = avail.Availability_Type__c;
                conflict.conflictingRecordId = avail.Id;
                conflicts.add(conflict);
            }
        }

        return conflicts;
    }

    /**
     * @description Check if a staff member is available during a given time window
     *              (has Working availability and no conflicts)
     * @param userId Staff member's User ID
     * @param proposedStart Start of proposed time window
     * @param proposedEnd End of proposed time window
     * @return True if staff is available, false otherwise
     */
    public static Boolean isStaffAvailable(Id userId, DateTime proposedStart, DateTime proposedEnd) {
        // First check for conflicts
        List<ConflictResult> conflicts = checkConflicts(userId, proposedStart, proposedEnd);
        if (!conflicts.isEmpty()) {
            return false;
        }

        // Then verify they have Working availability for this time
        Date appointmentDate = proposedStart.date();
        Time startTime = proposedStart.time();
        Time endTime = proposedEnd.time();

        List<Staff_Availability__c> workingHours = [
            SELECT Id, Start_Time__c, End_Time__c
            FROM Staff_Availability__c
            WHERE User__c = :userId
            AND Date__c = :appointmentDate
            AND Availability_Type__c = 'Working'
            AND Start_Time__c <= :startTime
            AND End_Time__c >= :endTime
            LIMIT 1
        ];

        return !workingHours.isEmpty();
    }

    /**
     * @description Get available time slots for a staff member on a given date
     * @param userId Staff member's User ID
     * @param targetDate Date to check availability
     * @param durationMinutes Required duration for the appointment
     * @return List of available start times
     */
    public static List<DateTime> getAvailableSlots(Id userId, Date targetDate, Integer durationMinutes) {
        List<DateTime> availableSlots = new List<DateTime>();

        // Get working hours for the date
        List<Staff_Availability__c> workingHours = [
            SELECT Start_Time__c, End_Time__c
            FROM Staff_Availability__c
            WHERE User__c = :userId
            AND Date__c = :targetDate
            AND Availability_Type__c = 'Working'
            ORDER BY Start_Time__c
        ];

        if (workingHours.isEmpty()) {
            return availableSlots;
        }

        // For each working window, find available slots
        for (Staff_Availability__c working : workingHours) {
            DateTime windowStart = DateTime.newInstance(targetDate, working.Start_Time__c);
            DateTime windowEnd = DateTime.newInstance(targetDate, working.End_Time__c);

            // Generate potential slots in 30-minute increments
            DateTime slotStart = windowStart;
            while (slotStart.addMinutes(durationMinutes) <= windowEnd) {
                DateTime slotEnd = slotStart.addMinutes(durationMinutes);

                // Check if this slot has any conflicts
                List<ConflictResult> conflicts = checkConflicts(userId, slotStart, slotEnd);
                if (conflicts.isEmpty()) {
                    availableSlots.add(slotStart);
                }

                slotStart = slotStart.addMinutes(30); // 30-minute increments
            }
        }

        return availableSlots;
    }

    /**
     * @description Format DateTime for display
     */
    private static String formatDateTime(DateTime dt) {
        return dt.format('MMM d, yyyy h:mm a');
    }

    /**
     * @description Format time portion only
     */
    private static String formatTime(DateTime dt) {
        return dt.format('h:mm a');
    }
}