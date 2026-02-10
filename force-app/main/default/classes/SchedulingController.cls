/**
 * @description Apex controller for Peer Visits Calendar LWC
 *              Exposes methods for calendar view, availability management,
 *              and conflict checking.
 *
 * Peerstar Terminology:
 *   - Peer Visits = ServiceAppointment (Field Service)
 *   - Meetings = WorkOrder (Field Service)
 *   - Peer Specialists = ServiceResource (Field Service)
 *   - Participants = Contacts/Cases receiving peer support
 */
public with sharing class SchedulingController {

    /**
     * @description Get peer visits for a date range (for calendar view)
     * @param startDate Start of date range
     * @param endDate End of date range
     * @param peerSpecialistId Optional - filter by specific Peer Specialist (User Id)
     * @return List of peer visits
     */
    @AuraEnabled(cacheable=true)
    public static List<PeerVisitWrapper> getPeerVisits(Date startDate, Date endDate, Id peerSpecialistId) {
        List<PeerVisitWrapper> results = new List<PeerVisitWrapper>();

        // Convert dates to datetime for query
        DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 0));

        // Build query for Peer Visits (ServiceAppointment)
        String query = 'SELECT Id, AppointmentNumber, Subject, Status, ' +
                      'SchedStartTime, SchedEndTime, EarliestStartTime, DueDate, ' +
                      'Duration, DurationType, Street, City, State, PostalCode, ' +
                      'Description, WorkTypeId, WorkType.Name, ParentRecordId, ' +
                      '(SELECT ServiceResourceId, ServiceResource.Name, ServiceResource.RelatedRecordId ' +
                      ' FROM ServiceResources LIMIT 1) ' +
                      'FROM ServiceAppointment ' +
                      'WHERE (DueDate >= :startDateTime AND EarliestStartTime <= :endDateTime) ';

        // If Peer Specialist provided, filter by assigned resource
        if (peerSpecialistId != null) {
            // Get the ServiceResource for this Peer Specialist
            List<ServiceResource> resources = [SELECT Id FROM ServiceResource WHERE RelatedRecordId = :peerSpecialistId LIMIT 1];
            if (!resources.isEmpty()) {
                Id resourceId = resources[0].Id;
                query += 'AND Id IN (SELECT ServiceAppointmentId FROM AssignedResource WHERE ServiceResourceId = :resourceId) ';
            }
        }

        query += 'ORDER BY SchedStartTime ASC NULLS LAST, EarliestStartTime ASC';

        for (ServiceAppointment sa : Database.query(query)) {
            results.add(new PeerVisitWrapper(sa));
        }

        return results;
    }

    // Backward compatibility alias
    @AuraEnabled(cacheable=true)
    public static List<PeerVisitWrapper> getScheduledServices(Date startDate, Date endDate, Id userId) {
        return getPeerVisits(startDate, endDate, userId);
    }

    /**
     * @description Get staff availability for a date range
     * @param userId Staff member's User ID
     * @param startDate Start of date range
     * @param endDate End of date range
     * @return List of availability records
     */
    @AuraEnabled(cacheable=true)
    public static List<Staff_Availability__c> getStaffAvailability(Id userId, Date startDate, Date endDate) {
        return [
            SELECT Id, Name, Date__c, Start_Time__c, End_Time__c,
                   Availability_Type__c, Recurrence_Pattern__c, Notes__c
            FROM Staff_Availability__c
            WHERE User__c = :userId
            AND Date__c >= :startDate
            AND Date__c <= :endDate
            ORDER BY Date__c, Start_Time__c
        ];
    }

    /**
     * @description Get available time slots for scheduling
     * @param userId Staff member's User ID
     * @param targetDate Date to check
     * @param durationMinutes Required duration
     * @return List of available slot times
     */
    @AuraEnabled
    public static List<TimeSlotWrapper> getAvailableTimeSlots(Id userId, Date targetDate, Integer durationMinutes) {
        List<TimeSlotWrapper> slots = new List<TimeSlotWrapper>();

        List<DateTime> availableTimes = SchedulingConflictService.getAvailableSlots(
            userId, targetDate, durationMinutes
        );

        for (DateTime dt : availableTimes) {
            slots.add(new TimeSlotWrapper(dt, durationMinutes));
        }

        return slots;
    }

    /**
     * @description Check for conflicts before scheduling
     * @param userId Staff member's User ID
     * @param proposedStart Proposed start time
     * @param proposedEnd Proposed end time
     * @param excludeRecordId Optional record to exclude (for updates)
     * @return List of conflicts found
     */
    @AuraEnabled
    public static List<SchedulingConflictService.ConflictResult> checkConflicts(
            Id userId, DateTime proposedStart, DateTime proposedEnd, Id excludeRecordId) {
        return SchedulingConflictService.checkConflicts(userId, proposedStart, proposedEnd, excludeRecordId);
    }

    /**
     * @description Save a new availability record
     * @param availability The availability record to save
     * @return The saved record Id
     */
    @AuraEnabled
    public static Id saveAvailability(Staff_Availability__c availability) {
        upsert availability;
        return availability.Id;
    }

    /**
     * @description Delete an availability record
     * @param availabilityId The record to delete
     */
    @AuraEnabled
    public static void deleteAvailability(Id availabilityId) {
        delete [SELECT Id FROM Staff_Availability__c WHERE Id = :availabilityId];
    }

    /**
     * @description Get list of Peer Specialists (active Service Resources)
     * @return List of Peer Specialists who can be assigned to visits
     */
    @AuraEnabled(cacheable=true)
    public static List<PeerSpecialistWrapper> getPeerSpecialists() {
        List<PeerSpecialistWrapper> specialists = new List<PeerSpecialistWrapper>();

        // Get active Peer Specialists (ServiceResource)
        for (ServiceResource sr : [
            SELECT Id, Name, RelatedRecordId, RelatedRecord.Name,
                   RelatedRecord.SmallPhotoUrl, RelatedRecord.Email
            FROM ServiceResource
            WHERE IsActive = true
            AND RelatedRecordId != null
            ORDER BY Name
            LIMIT 100
        ]) {
            specialists.add(new PeerSpecialistWrapper(sr));
        }

        return specialists;
    }

    // Backward compatibility alias
    @AuraEnabled(cacheable=true)
    public static List<PeerSpecialistWrapper> getStaffMembers() {
        return getPeerSpecialists();
    }

    /**
     * @description Update peer visit status
     * @param visitId The Peer Visit (ServiceAppointment) record Id
     * @param newStatus The new status value
     *
     * Status mapping (Peerstar -> Field Service):
     *   Pending -> None
     *   Scheduled -> Scheduled
     *   Confirmed -> Dispatched
     *   In Session -> In Progress
     *   Visit Complete -> Completed
     *   Missed -> Cannot Complete
     *   Canceled -> Canceled
     */
    @AuraEnabled
    public static void updateVisitStatus(Id visitId, String newStatus) {
        ServiceAppointment sa = new ServiceAppointment(
            Id = visitId,
            Status = newStatus
        );
        update sa;
    }

    // Backward compatibility alias
    @AuraEnabled
    public static void updateServiceStatus(Id serviceId, String newStatus) {
        updateVisitStatus(serviceId, newStatus);
    }

    // ==================== HOME SCREEN METHODS ====================

    /**
     * @description Get dashboard metrics for the logged-in Peer Specialist
     * @return DashboardMetrics wrapper with counts and breakdowns
     */
    @AuraEnabled(cacheable=true)
    public static DashboardMetrics getPeerSpecialistMetrics() {
        DashboardMetrics metrics = new DashboardMetrics();
        Id currentUserId = UserInfo.getUserId();

        // Get ServiceResource for current user
        List<ServiceResource> resources = [
            SELECT Id FROM ServiceResource
            WHERE RelatedRecordId = :currentUserId AND IsActive = true
            LIMIT 1
        ];

        if (resources.isEmpty()) {
            return metrics; // Return empty metrics if user is not a Service Resource
        }

        Id resourceId = resources[0].Id;
        Date today = Date.today();
        Date weekStart = today.toStartOfWeek();
        Date weekEnd = weekStart.addDays(6);

        // Query all relevant appointments for this Peer Specialist
        List<ServiceAppointment> appointments = [
            SELECT Id, Status, SchedStartTime, DueDate
            FROM ServiceAppointment
            WHERE Id IN (SELECT ServiceAppointmentId FROM AssignedResource WHERE ServiceResourceId = :resourceId)
        ];

        for (ServiceAppointment sa : appointments) {
            Date apptDate = sa.SchedStartTime != null ? sa.SchedStartTime.date() : (sa.DueDate != null ? sa.DueDate.date() : null);

            // Today's count
            if (apptDate == today) {
                metrics.todayCount++;
            }

            // This week's count
            if (apptDate != null && apptDate >= weekStart && apptDate <= weekEnd) {
                metrics.thisWeekCount++;
            }

            // Status breakdown
            if (sa.Status == 'None') metrics.pendingCount++;
            else if (sa.Status == 'Scheduled' || sa.Status == 'Dispatched') metrics.confirmedCount++;
            else if (sa.Status == 'In Progress') metrics.inSessionCount++;
            else if (sa.Status == 'Completed') metrics.completedCount++;
            else if (sa.Status == 'Cannot Complete') metrics.missedCount++;

            // Overdue (past due date and not completed/canceled)
            if (sa.DueDate != null && sa.DueDate.date() < today &&
                sa.Status != 'Completed' && sa.Status != 'Canceled' && sa.Status != 'Cannot Complete') {
                metrics.overdueCount++;
            }
        }

        // Get follow-ups needed count from Cases
        metrics.followUpsNeededCount = [
            SELECT COUNT()
            FROM Case
            WHERE pstar__Peer_Specialist__c = :currentUserId
            AND pstar__Follow_Up_IRP_Due__c != null
            AND pstar__Follow_Up_IRP_Due__c <= :today.addDays(14)
            AND pstar__Follow_Up_IRP_Completed__c = false
            AND IsClosed = false
        ];

        return metrics;
    }

    /**
     * @description Get Cases needing IRP follow-up for the logged-in Peer Specialist
     * @param daysAhead Number of days to look ahead (default 14)
     * @return List of CaseFollowUpWrapper records
     */
    @AuraEnabled(cacheable=true)
    public static List<CaseFollowUpWrapper> getFollowUpCases(Integer daysAhead) {
        List<CaseFollowUpWrapper> results = new List<CaseFollowUpWrapper>();
        Id currentUserId = UserInfo.getUserId();
        Date today = Date.today();
        Integer lookAhead = daysAhead != null ? daysAhead : 14;

        List<Case> cases = [
            SELECT Id, CaseNumber, Contact.Name, pstar__Follow_Up_IRP_Due__c,
                   pstar__No_Show_Count__c, pstar__Authorization_Hours_Remaining__c,
                   pstar__Service_Start_Date__c
            FROM Case
            WHERE pstar__Peer_Specialist__c = :currentUserId
            AND pstar__Follow_Up_IRP_Due__c != null
            AND pstar__Follow_Up_IRP_Due__c <= :today.addDays(lookAhead)
            AND pstar__Follow_Up_IRP_Completed__c = false
            AND IsClosed = false
            ORDER BY pstar__Follow_Up_IRP_Due__c ASC
            LIMIT 50
        ];

        for (Case c : cases) {
            results.add(new CaseFollowUpWrapper(c, today));
        }

        return results;
    }

    /**
     * @description Get overdue or missed peer visits for the logged-in Peer Specialist
     * @return List of overdue/missed PeerVisitWrapper records
     */
    @AuraEnabled(cacheable=true)
    public static List<PeerVisitWrapper> getOverdueVisits() {
        List<PeerVisitWrapper> results = new List<PeerVisitWrapper>();
        Id currentUserId = UserInfo.getUserId();
        Date today = Date.today();
        DateTime todayDateTime = DateTime.newInstance(today, Time.newInstance(0, 0, 0, 0));

        // Get ServiceResource for current user
        List<ServiceResource> resources = [
            SELECT Id FROM ServiceResource
            WHERE RelatedRecordId = :currentUserId AND IsActive = true
            LIMIT 1
        ];

        if (resources.isEmpty()) {
            return results;
        }

        Id resourceId = resources[0].Id;

        // Query overdue and missed appointments
        List<ServiceAppointment> appointments = [
            SELECT Id, AppointmentNumber, Subject, Status,
                   SchedStartTime, SchedEndTime, EarliestStartTime, DueDate,
                   Duration, DurationType, Street, City, State, PostalCode,
                   Description, WorkTypeId, WorkType.Name, ParentRecordId,
                   (SELECT ServiceResourceId, ServiceResource.Name, ServiceResource.RelatedRecordId
                    FROM ServiceResources LIMIT 1)
            FROM ServiceAppointment
            WHERE Id IN (SELECT ServiceAppointmentId FROM AssignedResource WHERE ServiceResourceId = :resourceId)
            AND (
                (DueDate < :todayDateTime AND Status NOT IN ('Completed', 'Canceled', 'Cannot Complete'))
                OR Status = 'Cannot Complete'
            )
            ORDER BY DueDate ASC
            LIMIT 25
        ];

        for (ServiceAppointment sa : appointments) {
            results.add(new PeerVisitWrapper(sa));
        }

        return results;
    }

    /**
     * @description Get peer visits for the logged-in Peer Specialist with filtering
     * @param startDate Start of date range
     * @param endDate End of date range
     * @param statuses List of status values to filter (optional)
     * @return List of PeerVisitWrapper for current user only
     */
    @AuraEnabled(cacheable=true)
    public static List<PeerVisitWrapper> getMyPeerVisits(Date startDate, Date endDate, List<String> statuses) {
        List<PeerVisitWrapper> results = new List<PeerVisitWrapper>();
        Id currentUserId = UserInfo.getUserId();

        // Get ServiceResource for current user
        List<ServiceResource> resources = [
            SELECT Id FROM ServiceResource
            WHERE RelatedRecordId = :currentUserId AND IsActive = true
            LIMIT 1
        ];

        if (resources.isEmpty()) {
            return results;
        }

        Id resourceId = resources[0].Id;

        // Build dynamic query
        DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 0));

        String query = 'SELECT Id, AppointmentNumber, Subject, Status, ' +
                      'SchedStartTime, SchedEndTime, EarliestStartTime, DueDate, ' +
                      'Duration, DurationType, Street, City, State, PostalCode, ' +
                      'Description, WorkTypeId, WorkType.Name, ParentRecordId, ' +
                      '(SELECT ServiceResourceId, ServiceResource.Name, ServiceResource.RelatedRecordId ' +
                      ' FROM ServiceResources LIMIT 1) ' +
                      'FROM ServiceAppointment ' +
                      'WHERE Id IN (SELECT ServiceAppointmentId FROM AssignedResource WHERE ServiceResourceId = :resourceId) ' +
                      'AND ((DueDate >= :startDateTime AND DueDate <= :endDateTime) ' +
                      'OR (SchedStartTime >= :startDateTime AND SchedStartTime <= :endDateTime)) ';

        if (statuses != null && !statuses.isEmpty()) {
            query += 'AND Status IN :statuses ';
        }

        query += 'ORDER BY SchedStartTime ASC NULLS LAST, DueDate ASC LIMIT 100';

        for (ServiceAppointment sa : Database.query(query)) {
            results.add(new PeerVisitWrapper(sa));
        }

        return results;
    }

    // ==================== PARTICIPANT TIMELINE METHODS ====================

    /**
     * @description Get timeline data for a participant (Case)
     * @param caseId The Case record Id
     * @return List of TimelineEvent records
     */
    @AuraEnabled(cacheable=true)
    public static List<TimelineEvent> getParticipantTimeline(Id caseId) {
        List<TimelineEvent> events = new List<TimelineEvent>();

        // Get Case details
        Case c = [
            SELECT Id, CaseNumber, pstar__Service_Start_Date__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        // Add service start date as milestone
        if (c.pstar__Service_Start_Date__c != null) {
            events.add(new TimelineEvent(
                'milestone',
                'Service Started',
                'Services began for this participant',
                DateTime.newInstance(c.pstar__Service_Start_Date__c, Time.newInstance(0, 0, 0, 0)),
                null,
                'standard:date_time',
                'slds-timeline__item_success'
            ));
        }

        // Get all visits for this participant
        List<WorkOrder> workOrders = [SELECT Id FROM WorkOrder WHERE CaseId = :caseId];
        Set<Id> woIds = new Set<Id>();
        for (WorkOrder wo : workOrders) {
            woIds.add(wo.Id);
        }

        if (!woIds.isEmpty()) {
            List<ServiceAppointment> visits = [
                SELECT Id, AppointmentNumber, Subject, Status, SchedStartTime,
                       DueDate, WorkType.Name, Actual_Duration__c
                FROM ServiceAppointment
                WHERE ParentRecordId IN :woIds
                ORDER BY SchedStartTime DESC NULLS LAST
                LIMIT 50
            ];

            for (ServiceAppointment sa : visits) {
                String iconName = 'standard:service_appointment';
                String itemClass = 'slds-timeline__item_basic';
                String description = sa.WorkType?.Name != null ? sa.WorkType.Name : 'Peer Visit';

                if (sa.Status == 'Completed') {
                    itemClass = 'slds-timeline__item_success';
                    if (sa.Actual_Duration__c != null) {
                        description += ' (' + Integer.valueOf(sa.Actual_Duration__c) + ' min)';
                    }
                } else if (sa.Status == 'Cannot Complete') {
                    itemClass = 'slds-timeline__item_error';
                    iconName = 'standard:service_appointment';
                    description += ' - Missed';
                } else if (sa.Status == 'Canceled') {
                    itemClass = 'slds-timeline__item_error';
                    description += ' - Canceled';
                }

                DateTime eventDate = sa.SchedStartTime != null ? sa.SchedStartTime :
                                    (sa.DueDate != null ? sa.DueDate : null);

                events.add(new TimelineEvent(
                    'visit',
                    sa.Subject != null ? sa.Subject : sa.AppointmentNumber,
                    description,
                    eventDate,
                    sa.Id,
                    iconName,
                    itemClass
                ));
            }
        }

        // Sort events by date descending
        events.sort();

        return events;
    }

    /**
     * @description Timeline event wrapper
     */
    public class TimelineEvent implements Comparable {
        @AuraEnabled public String eventType { get; set; }
        @AuraEnabled public String title { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public DateTime eventDate { get; set; }
        @AuraEnabled public String formattedDate { get; set; }
        @AuraEnabled public Id recordId { get; set; }
        @AuraEnabled public String iconName { get; set; }
        @AuraEnabled public String itemClass { get; set; }

        public TimelineEvent(String eventType, String title, String description,
                            DateTime eventDate, Id recordId, String iconName, String itemClass) {
            this.eventType = eventType;
            this.title = title;
            this.description = description;
            this.eventDate = eventDate;
            this.formattedDate = eventDate != null ? eventDate.format('MMM d, yyyy h:mm a') : '';
            this.recordId = recordId;
            this.iconName = iconName;
            this.itemClass = itemClass;
        }

        public Integer compareTo(Object compareTo) {
            TimelineEvent other = (TimelineEvent) compareTo;
            if (this.eventDate == null && other.eventDate == null) return 0;
            if (this.eventDate == null) return 1;
            if (other.eventDate == null) return -1;
            // Descending order (newest first)
            if (this.eventDate > other.eventDate) return -1;
            if (this.eventDate < other.eventDate) return 1;
            return 0;
        }
    }

    // ==================== PRE-VISIT PREP METHODS ====================

    /**
     * @description Get participant preparation data for a visit
     * @param visitId ServiceAppointment record Id
     * @return ParticipantPrepWrapper with all prep information
     */
    @AuraEnabled(cacheable=true)
    public static ParticipantPrepWrapper getParticipantPrepData(Id visitId) {
        // Get the visit with WorkOrder info
        ServiceAppointment visit = [
            SELECT Id, Subject, ParentRecordId
            FROM ServiceAppointment
            WHERE Id = :visitId
            LIMIT 1
        ];

        if (visit.ParentRecordId == null) {
            return null;
        }

        // Get the WorkOrder to find the Case
        WorkOrder wo = [
            SELECT Id, CaseId
            FROM WorkOrder
            WHERE Id = :visit.ParentRecordId
            LIMIT 1
        ];

        if (wo.CaseId == null) {
            return null;
        }

        // Get the Case (Participant) with all prep info
        Case c = [
            SELECT Id, CaseNumber, ContactId, Contact.Name, Contact.Phone, Contact.Email,
                   Contact.MailingStreet, Contact.MailingCity, Contact.MailingState,
                   Contact.MailingPostalCode, Contact.PhotoUrl,
                   pstar__Peer_Specialist__c, pstar__Service_Start_Date__c,
                   pstar__Follow_Up_IRP_Due__c, pstar__Follow_Up_IRP_Completed__c,
                   pstar__Authorization_Hours_Remaining__c, pstar__No_Show_Count__c,
                   Participant_Alerts__c, Contact_Preferences__c,
                   Current_Goals__c
            FROM Case
            WHERE Id = :wo.CaseId
            LIMIT 1
        ];

        // Get last 3 completed visits (then filter for notes in code)
        List<ServiceAppointment> allRecentVisits = [
            SELECT Id, AppointmentNumber, SchedStartTime, Visit_Notes__c
            FROM ServiceAppointment
            WHERE ParentRecordId IN (SELECT Id FROM WorkOrder WHERE CaseId = :wo.CaseId)
            AND Status = 'Completed'
            ORDER BY SchedStartTime DESC
            LIMIT 10
        ];
        // Filter to only those with notes
        List<ServiceAppointment> recentVisits = new List<ServiceAppointment>();
        for (ServiceAppointment sa : allRecentVisits) {
            if (String.isNotBlank(sa.Visit_Notes__c) && recentVisits.size() < 3) {
                recentVisits.add(sa);
            }
        }

        return new ParticipantPrepWrapper(c, recentVisits);
    }

    /**
     * @description Wrapper class for participant preparation data
     */
    public class ParticipantPrepWrapper {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public String participantName { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String address { get; set; }
        @AuraEnabled public String photoUrl { get; set; }
        @AuraEnabled public Date serviceStartDate { get; set; }
        @AuraEnabled public Date followUpDueDate { get; set; }
        @AuraEnabled public Boolean followUpCompleted { get; set; }
        @AuraEnabled public Decimal hoursRemaining { get; set; }
        @AuraEnabled public Integer noShowCount { get; set; }
        @AuraEnabled public String alerts { get; set; }
        @AuraEnabled public String contactPreferences { get; set; }
        @AuraEnabled public String currentGoals { get; set; }
        @AuraEnabled public List<RecentVisitNote> recentNotes { get; set; }
        @AuraEnabled public Boolean hasAlerts { get; set; }

        public ParticipantPrepWrapper(Case c, List<ServiceAppointment> recentVisits) {
            this.caseId = c.Id;
            this.caseNumber = c.CaseNumber;
            this.contactId = c.ContactId;
            this.participantName = c.Contact?.Name;
            this.phone = c.Contact?.Phone;
            this.email = c.Contact?.Email;
            this.photoUrl = c.Contact?.PhotoUrl;
            this.serviceStartDate = c.pstar__Service_Start_Date__c;
            this.followUpDueDate = c.pstar__Follow_Up_IRP_Due__c;
            this.followUpCompleted = c.pstar__Follow_Up_IRP_Completed__c;
            this.hoursRemaining = c.pstar__Authorization_Hours_Remaining__c;
            this.noShowCount = c.pstar__No_Show_Count__c != null ? Integer.valueOf(c.pstar__No_Show_Count__c) : 0;
            this.alerts = c.Participant_Alerts__c;
            this.contactPreferences = c.Contact_Preferences__c;
            this.currentGoals = c.Current_Goals__c;
            this.hasAlerts = String.isNotBlank(c.Participant_Alerts__c);

            // Build address
            List<String> addrParts = new List<String>();
            if (String.isNotBlank(c.Contact?.MailingStreet)) addrParts.add(c.Contact.MailingStreet);
            if (String.isNotBlank(c.Contact?.MailingCity)) addrParts.add(c.Contact.MailingCity);
            if (String.isNotBlank(c.Contact?.MailingState)) addrParts.add(c.Contact.MailingState);
            if (String.isNotBlank(c.Contact?.MailingPostalCode)) addrParts.add(c.Contact.MailingPostalCode);
            this.address = String.join(addrParts, ', ');

            // Recent visit notes
            this.recentNotes = new List<RecentVisitNote>();
            for (ServiceAppointment sa : recentVisits) {
                this.recentNotes.add(new RecentVisitNote(sa));
            }
        }
    }

    /**
     * @description Wrapper for recent visit notes
     */
    public class RecentVisitNote {
        @AuraEnabled public Id visitId { get; set; }
        @AuraEnabled public String visitNumber { get; set; }
        @AuraEnabled public DateTime visitDate { get; set; }
        @AuraEnabled public String notes { get; set; }
        @AuraEnabled public String notesSummary { get; set; }

        public RecentVisitNote(ServiceAppointment sa) {
            this.visitId = sa.Id;
            this.visitNumber = sa.AppointmentNumber;
            this.visitDate = sa.SchedStartTime;
            this.notes = sa.Visit_Notes__c;
            // Create summary (first 200 chars, strip HTML)
            if (String.isNotBlank(sa.Visit_Notes__c)) {
                String plainText = sa.Visit_Notes__c.replaceAll('<[^>]+>', ' ').replaceAll('\\s+', ' ').trim();
                this.notesSummary = plainText.length() > 200 ? plainText.substring(0, 200) + '...' : plainText;
            }
        }
    }

    // ==================== VISIT ACTIONS METHODS ====================

    /**
     * @description Check in to a peer visit - captures time and optional GPS location
     * @param visitId ServiceAppointment record Id
     * @param latitude GPS latitude (optional)
     * @param longitude GPS longitude (optional)
     * @return Updated ServiceAppointment data
     */
    @AuraEnabled
    public static Map<String, Object> checkInVisit(Id visitId, Decimal latitude, Decimal longitude) {
        ServiceAppointment sa = [
            SELECT Id, Status, Check_In_Time__c
            FROM ServiceAppointment
            WHERE Id = :visitId
            LIMIT 1
        ];

        // Update check-in fields
        sa.Check_In_Time__c = DateTime.now();
        sa.Status = 'In Progress';

        if (latitude != null) {
            sa.Check_In_Latitude__c = latitude;
        }
        if (longitude != null) {
            sa.Check_In_Longitude__c = longitude;
        }

        update sa;

        return new Map<String, Object>{
            'success' => true,
            'checkInTime' => sa.Check_In_Time__c,
            'status' => sa.Status
        };
    }

    /**
     * @description Check out from a peer visit - captures time, GPS, and calculates duration
     * @param visitId ServiceAppointment record Id
     * @param latitude GPS latitude (optional)
     * @param longitude GPS longitude (optional)
     * @return Updated ServiceAppointment data including actual duration
     */
    @AuraEnabled
    public static Map<String, Object> checkOutVisit(Id visitId, Decimal latitude, Decimal longitude) {
        ServiceAppointment sa = [
            SELECT Id, Status, Check_In_Time__c, Check_Out_Time__c,
                   Review_Status__c
            FROM ServiceAppointment
            WHERE Id = :visitId
            LIMIT 1
        ];

        // Update check-out fields
        sa.Check_Out_Time__c = DateTime.now();
        sa.Status = 'Completed';

        if (latitude != null) {
            sa.Check_Out_Latitude__c = latitude;
        }
        if (longitude != null) {
            sa.Check_Out_Longitude__c = longitude;
        }

        update sa;

        // Calculate actual duration
        Integer actualDuration = null;
        if (sa.Check_In_Time__c != null) {
            Long milliseconds = sa.Check_Out_Time__c.getTime() - sa.Check_In_Time__c.getTime();
            actualDuration = Integer.valueOf(milliseconds / 60000); // Convert to minutes
        }

        return new Map<String, Object>{
            'success' => true,
            'checkOutTime' => sa.Check_Out_Time__c,
            'status' => sa.Status,
            'actualDuration' => actualDuration
        };
    }

    /**
     * @description Save visit notes
     * @param visitId ServiceAppointment record Id
     * @param notes The visit notes HTML content
     * @return Success status
     */
    @AuraEnabled
    public static Map<String, Object> saveVisitNotes(Id visitId, String notes) {
        ServiceAppointment sa = new ServiceAppointment(
            Id = visitId,
            Visit_Notes__c = notes
        );
        update sa;

        return new Map<String, Object>{
            'success' => true
        };
    }

    /**
     * @description Submit visit documentation for supervisor review
     * @param visitId ServiceAppointment record Id
     * @return Success status
     */
    @AuraEnabled
    public static Map<String, Object> submitForReview(Id visitId) {
        ServiceAppointment sa = new ServiceAppointment(
            Id = visitId,
            Review_Status__c = 'Pending Review'
        );
        update sa;

        return new Map<String, Object>{
            'success' => true,
            'reviewStatus' => 'Pending Review'
        };
    }

    /**
     * @description Approve or request revision on visit documentation (for supervisors)
     * @param visitId ServiceAppointment record Id
     * @param approved Whether to approve or request revision
     * @param revisionNotes Notes explaining what needs revision (if not approved)
     * @return Success status
     */
    @AuraEnabled
    public static Map<String, Object> reviewVisit(Id visitId, Boolean approved, String revisionNotes) {
        ServiceAppointment sa = new ServiceAppointment(
            Id = visitId,
            Review_Status__c = approved ? 'Approved' : 'Needs Revision',
            Reviewed_By__c = UserInfo.getUserId(),
            Reviewed_Date__c = DateTime.now()
        );

        if (!approved && String.isNotBlank(revisionNotes)) {
            sa.Revision_Notes__c = revisionNotes;
        }

        update sa;

        return new Map<String, Object>{
            'success' => true,
            'reviewStatus' => sa.Review_Status__c
        };
    }

    /**
     * @description Get single visit details including all check-in/out data
     * @param visitId ServiceAppointment record Id
     * @return Visit details wrapper
     */
    @AuraEnabled(cacheable=true)
    public static VisitDetailsWrapper getVisitDetails(Id visitId) {
        ServiceAppointment sa = [
            SELECT Id, AppointmentNumber, Subject, Status, Description,
                   SchedStartTime, SchedEndTime, EarliestStartTime, DueDate,
                   Duration, WorkTypeId, WorkType.Name,
                   Street, City, State, PostalCode,
                   Check_In_Time__c, Check_Out_Time__c,
                   Check_In_Latitude__c, Check_In_Longitude__c,
                   Check_Out_Latitude__c, Check_Out_Longitude__c,
                   Visit_Notes__c, Actual_Duration__c,
                   Review_Status__c, Reviewed_By__c, Reviewed_By__r.Name,
                   Reviewed_Date__c, Revision_Notes__c,
                   ParentRecordId,
                   (SELECT ServiceResourceId, ServiceResource.Name, ServiceResource.RelatedRecordId
                    FROM ServiceResources LIMIT 1)
            FROM ServiceAppointment
            WHERE Id = :visitId
            LIMIT 1
        ];

        return new VisitDetailsWrapper(sa);
    }

    /**
     * @description Wrapper class for detailed visit information
     */
    public class VisitDetailsWrapper extends PeerVisitWrapper {
        @AuraEnabled public DateTime checkInTime { get; set; }
        @AuraEnabled public DateTime checkOutTime { get; set; }
        @AuraEnabled public Decimal checkInLatitude { get; set; }
        @AuraEnabled public Decimal checkInLongitude { get; set; }
        @AuraEnabled public Decimal checkOutLatitude { get; set; }
        @AuraEnabled public Decimal checkOutLongitude { get; set; }
        @AuraEnabled public String visitNotes { get; set; }
        @AuraEnabled public Decimal actualDuration { get; set; }
        @AuraEnabled public String reviewStatus { get; set; }
        @AuraEnabled public Id reviewedById { get; set; }
        @AuraEnabled public String reviewedByName { get; set; }
        @AuraEnabled public DateTime reviewedDate { get; set; }
        @AuraEnabled public String revisionNotes { get; set; }
        @AuraEnabled public Boolean canCheckIn { get; set; }
        @AuraEnabled public Boolean canCheckOut { get; set; }
        @AuraEnabled public Boolean canSubmitForReview { get; set; }

        public VisitDetailsWrapper(ServiceAppointment sa) {
            super(sa);
            this.checkInTime = sa.Check_In_Time__c;
            this.checkOutTime = sa.Check_Out_Time__c;
            this.checkInLatitude = sa.Check_In_Latitude__c;
            this.checkInLongitude = sa.Check_In_Longitude__c;
            this.checkOutLatitude = sa.Check_Out_Latitude__c;
            this.checkOutLongitude = sa.Check_Out_Longitude__c;
            this.visitNotes = sa.Visit_Notes__c;
            this.actualDuration = sa.Actual_Duration__c;
            this.reviewStatus = sa.Review_Status__c;
            this.reviewedById = sa.Reviewed_By__c;
            this.reviewedByName = sa.Reviewed_By__r?.Name;
            this.reviewedDate = sa.Reviewed_Date__c;
            this.revisionNotes = sa.Revision_Notes__c;

            // Determine available actions
            this.canCheckIn = sa.Check_In_Time__c == null &&
                             sa.Status != 'Completed' && sa.Status != 'Canceled' && sa.Status != 'Cannot Complete';
            this.canCheckOut = sa.Check_In_Time__c != null && sa.Check_Out_Time__c == null;
            this.canSubmitForReview = sa.Status == 'Completed' &&
                                      (sa.Review_Status__c == 'Not Submitted' || sa.Review_Status__c == 'Needs Revision');
        }
    }

    // ==================== TEAM DASHBOARD METHODS (For Managers) ====================

    /**
     * @description Get team dashboard metrics for all Peer Specialists
     * @param startDate Start of date range
     * @param endDate End of date range
     * @return TeamDashboardMetrics wrapper with team-wide statistics
     */
    @AuraEnabled(cacheable=true)
    public static TeamDashboardMetrics getTeamDashboardMetrics(Date startDate, Date endDate) {
        TeamDashboardMetrics metrics = new TeamDashboardMetrics();

        DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 0));

        // Get all active Service Resources with their assigned visits
        Map<Id, ServiceResource> resourceMap = new Map<Id, ServiceResource>([
            SELECT Id, Name, RelatedRecordId, RelatedRecord.Name, RelatedRecord.SmallPhotoUrl
            FROM ServiceResource
            WHERE IsActive = true
            AND RelatedRecordId != null
        ]);

        // Get all visits in the date range
        List<ServiceAppointment> appointments = [
            SELECT Id, Status, SchedStartTime, DueDate,
                   (SELECT ServiceResourceId FROM ServiceResources LIMIT 1)
            FROM ServiceAppointment
            WHERE (SchedStartTime >= :startDateTime AND SchedStartTime <= :endDateTime)
               OR (DueDate >= :startDateTime AND DueDate <= :endDateTime)
        ];

        // Build specialist workload map
        Map<Id, SpecialistWorkload> workloadMap = new Map<Id, SpecialistWorkload>();

        for (ServiceResource sr : resourceMap.values()) {
            workloadMap.put(sr.Id, new SpecialistWorkload(sr));
        }

        // Process appointments
        for (ServiceAppointment sa : appointments) {
            // Update total counts
            metrics.totalVisits++;

            if (sa.Status == 'Completed') {
                metrics.completedVisits++;
            } else if (sa.Status == 'Cannot Complete') {
                metrics.missedVisits++;
            } else if (sa.Status == 'Canceled') {
                metrics.canceledVisits++;
            } else if (sa.Status == 'In Progress') {
                metrics.inProgressVisits++;
            } else {
                metrics.scheduledVisits++;
            }

            // Update specialist workload
            if (sa.ServiceResources != null && !sa.ServiceResources.isEmpty()) {
                Id resourceId = sa.ServiceResources[0].ServiceResourceId;
                if (workloadMap.containsKey(resourceId)) {
                    SpecialistWorkload workload = workloadMap.get(resourceId);
                    workload.totalVisits++;
                    if (sa.Status == 'Completed') workload.completedVisits++;
                    else if (sa.Status == 'Cannot Complete') workload.missedVisits++;
                }
            }
        }

        // Build specialist list sorted by total visits
        metrics.specialists = workloadMap.values();
        metrics.specialists.sort();

        // Calculate completion rate
        if (metrics.totalVisits > 0) {
            metrics.completionRate = (metrics.completedVisits * 100.0 / metrics.totalVisits).setScale(1);
        }

        // Get pending reviews count
        metrics.pendingReviews = [
            SELECT COUNT()
            FROM ServiceAppointment
            WHERE Review_Status__c = 'Pending Review'
            AND Status = 'Completed'
        ];

        return metrics;
    }

    /**
     * @description Get all team visits with specialist info for filtering
     * @param startDate Start of date range
     * @param endDate End of date range
     * @param specialistId Optional - filter by specific specialist (User Id)
     * @param statuses Optional - filter by statuses
     * @return List of PeerVisitWrapper with specialist info
     */
    @AuraEnabled(cacheable=true)
    public static List<PeerVisitWrapper> getTeamVisits(Date startDate, Date endDate, Id specialistId, List<String> statuses) {
        List<PeerVisitWrapper> results = new List<PeerVisitWrapper>();

        DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 0));

        String query = 'SELECT Id, AppointmentNumber, Subject, Status, ' +
                      'SchedStartTime, SchedEndTime, EarliestStartTime, DueDate, ' +
                      'Duration, DurationType, Street, City, State, PostalCode, ' +
                      'Description, WorkTypeId, WorkType.Name, ParentRecordId, ' +
                      'Review_Status__c, ' +
                      '(SELECT ServiceResourceId, ServiceResource.Name, ServiceResource.RelatedRecordId ' +
                      ' FROM ServiceResources LIMIT 1) ' +
                      'FROM ServiceAppointment ' +
                      'WHERE ((SchedStartTime >= :startDateTime AND SchedStartTime <= :endDateTime) ' +
                      'OR (DueDate >= :startDateTime AND DueDate <= :endDateTime)) ';

        // Filter by specialist if provided
        if (specialistId != null) {
            List<ServiceResource> resources = [SELECT Id FROM ServiceResource WHERE RelatedRecordId = :specialistId LIMIT 1];
            if (!resources.isEmpty()) {
                Id resourceId = resources[0].Id;
                query += 'AND Id IN (SELECT ServiceAppointmentId FROM AssignedResource WHERE ServiceResourceId = :resourceId) ';
            }
        }

        // Filter by statuses if provided
        if (statuses != null && !statuses.isEmpty()) {
            query += 'AND Status IN :statuses ';
        }

        query += 'ORDER BY SchedStartTime ASC NULLS LAST, DueDate ASC LIMIT 200';

        for (ServiceAppointment sa : Database.query(query)) {
            results.add(new PeerVisitWrapper(sa));
        }

        return results;
    }

    /**
     * @description Get visits pending review (for supervisor review queue)
     * @return List of visits needing review
     */
    @AuraEnabled(cacheable=true)
    public static List<VisitDetailsWrapper> getPendingReviewVisits() {
        List<VisitDetailsWrapper> results = new List<VisitDetailsWrapper>();

        List<ServiceAppointment> visits = [
            SELECT Id, AppointmentNumber, Subject, Status, Description,
                   SchedStartTime, SchedEndTime, EarliestStartTime, DueDate,
                   Duration, WorkTypeId, WorkType.Name,
                   Street, City, State, PostalCode,
                   Check_In_Time__c, Check_Out_Time__c,
                   Check_In_Latitude__c, Check_In_Longitude__c,
                   Check_Out_Latitude__c, Check_Out_Longitude__c,
                   Visit_Notes__c, Actual_Duration__c,
                   Review_Status__c, Reviewed_By__c, Reviewed_By__r.Name,
                   Reviewed_Date__c, Revision_Notes__c,
                   ParentRecordId,
                   (SELECT ServiceResourceId, ServiceResource.Name, ServiceResource.RelatedRecordId
                    FROM ServiceResources LIMIT 1)
            FROM ServiceAppointment
            WHERE Review_Status__c = 'Pending Review'
            AND Status = 'Completed'
            ORDER BY Check_Out_Time__c ASC
            LIMIT 50
        ];

        for (ServiceAppointment sa : visits) {
            results.add(new VisitDetailsWrapper(sa));
        }

        return results;
    }

    // ==================== ROUTE PLANNING METHODS ====================

    /**
     * @description Get visits for a specific day with address info for route planning
     * @param targetDate Date to get visits for
     * @param specialistId Optional - specific specialist (defaults to current user)
     * @return List of RouteVisit wrappers with address and order info
     */
    @AuraEnabled(cacheable=true)
    public static List<RouteVisit> getDayRouteVisits(Date targetDate, Id specialistId) {
        List<RouteVisit> visits = new List<RouteVisit>();

        // Use current user if no specialist specified
        Id userId = specialistId != null ? specialistId : UserInfo.getUserId();

        // Get ServiceResource for the user
        List<ServiceResource> resources = [
            SELECT Id FROM ServiceResource
            WHERE RelatedRecordId = :userId AND IsActive = true
            LIMIT 1
        ];

        if (resources.isEmpty()) {
            return visits;
        }

        Id resourceId = resources[0].Id;
        DateTime startOfDay = DateTime.newInstance(targetDate, Time.newInstance(0, 0, 0, 0));
        DateTime endOfDay = DateTime.newInstance(targetDate, Time.newInstance(23, 59, 59, 0));

        // Query visits for the day
        Integer order = 1;
        for (ServiceAppointment sa : [
            SELECT Id, AppointmentNumber, Subject, Status,
                   SchedStartTime, SchedEndTime, Duration,
                   Street, City, State, PostalCode,
                   WorkType.Name, ParentRecordId
            FROM ServiceAppointment
            WHERE Id IN (SELECT ServiceAppointmentId FROM AssignedResource WHERE ServiceResourceId = :resourceId)
            AND SchedStartTime >= :startOfDay
            AND SchedStartTime <= :endOfDay
            AND Status NOT IN ('Canceled', 'Cannot Complete')
            ORDER BY SchedStartTime ASC
        ]) {
            visits.add(new RouteVisit(sa, order++));
        }

        return visits;
    }

    /**
     * @description Update the scheduled time for a visit (for route reordering)
     * @param visitId ServiceAppointment Id
     * @param newStartTime New scheduled start time
     * @return Success status
     */
    @AuraEnabled
    public static Map<String, Object> updateVisitTime(Id visitId, DateTime newStartTime) {
        ServiceAppointment sa = [
            SELECT Id, Duration, SchedStartTime, SchedEndTime
            FROM ServiceAppointment
            WHERE Id = :visitId
            LIMIT 1
        ];

        Integer durationMinutes = sa.Duration != null ? Integer.valueOf(sa.Duration) : 60;
        DateTime newEndTime = newStartTime.addMinutes(durationMinutes);

        sa.SchedStartTime = newStartTime;
        sa.SchedEndTime = newEndTime;
        update sa;

        return new Map<String, Object>{
            'success' => true,
            'newStartTime' => newStartTime,
            'newEndTime' => newEndTime
        };
    }

    // ==================== CASELOAD MANAGEMENT METHODS ====================

    /**
     * @description Get caseload summary for all specialists
     * @return List of SpecialistCaseload wrappers
     */
    @AuraEnabled(cacheable=true)
    public static List<SpecialistCaseload> getCaseloadSummary() {
        List<SpecialistCaseload> caseloads = new List<SpecialistCaseload>();

        // Get all active specialists
        Map<Id, ServiceResource> resourceMap = new Map<Id, ServiceResource>([
            SELECT Id, Name, RelatedRecordId, RelatedRecord.Name, RelatedRecord.SmallPhotoUrl
            FROM ServiceResource
            WHERE IsActive = true
            AND RelatedRecordId != null
        ]);

        // Get case counts per specialist
        Map<Id, Integer> activeCounts = new Map<Id, Integer>();
        Map<Id, Integer> totalCounts = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT pstar__Peer_Specialist__c specialistId, COUNT(Id) cnt
            FROM Case
            WHERE pstar__Peer_Specialist__c != null
            GROUP BY pstar__Peer_Specialist__c
        ]) {
            Id specialistId = (Id) ar.get('specialistId');
            totalCounts.put(specialistId, (Integer) ar.get('cnt'));
        }

        for (AggregateResult ar : [
            SELECT pstar__Peer_Specialist__c specialistId, COUNT(Id) cnt
            FROM Case
            WHERE pstar__Peer_Specialist__c != null
            AND IsClosed = false
            GROUP BY pstar__Peer_Specialist__c
        ]) {
            Id specialistId = (Id) ar.get('specialistId');
            activeCounts.put(specialistId, (Integer) ar.get('cnt'));
        }

        // Build caseload list
        for (ServiceResource sr : resourceMap.values()) {
            Id userId = sr.RelatedRecordId;
            Integer active = activeCounts.containsKey(userId) ? activeCounts.get(userId) : 0;
            Integer total = totalCounts.containsKey(userId) ? totalCounts.get(userId) : 0;

            caseloads.add(new SpecialistCaseload(sr, active, total));
        }

        // Sort by active cases descending
        caseloads.sort();

        return caseloads;
    }

    /**
     * @description Get cases for a specific specialist
     * @param specialistId User Id of the specialist
     * @param includeInactive Include closed cases
     * @return List of CaseWrapper records
     */
    @AuraEnabled(cacheable=true)
    public static List<CaseWrapper> getSpecialistCases(Id specialistId, Boolean includeInactive) {
        List<CaseWrapper> cases = new List<CaseWrapper>();

        String query = 'SELECT Id, CaseNumber, Contact.Name, Status, pstar__Service_Start_Date__c, ' +
                      'pstar__Follow_Up_IRP_Due__c, pstar__Authorization_Hours_Remaining__c, ' +
                      'pstar__No_Show_Count__c, IsClosed ' +
                      'FROM Case ' +
                      'WHERE pstar__Peer_Specialist__c = :specialistId ';

        if (!includeInactive) {
            query += 'AND IsClosed = false ';
        }

        query += 'ORDER BY pstar__Service_Start_Date__c DESC LIMIT 100';

        for (Case c : Database.query(query)) {
            cases.add(new CaseWrapper(c));
        }

        return cases;
    }

    /**
     * @description Get all unassigned cases (no Peer Specialist)
     * @return List of CaseWrapper records
     */
    @AuraEnabled(cacheable=true)
    public static List<CaseWrapper> getUnassignedCases() {
        List<CaseWrapper> cases = new List<CaseWrapper>();

        for (Case c : [
            SELECT Id, CaseNumber, Contact.Name, Status, pstar__Service_Start_Date__c,
                   pstar__Follow_Up_IRP_Due__c, pstar__Authorization_Hours_Remaining__c,
                   pstar__No_Show_Count__c, IsClosed
            FROM Case
            WHERE pstar__Peer_Specialist__c = null
            AND IsClosed = false
            ORDER BY CreatedDate DESC
            LIMIT 50
        ]) {
            cases.add(new CaseWrapper(c));
        }

        return cases;
    }

    /**
     * @description Reassign a case to a different specialist
     * @param caseId The Case record Id
     * @param newSpecialistId The new specialist's User Id
     * @return Success status
     */
    @AuraEnabled
    public static Map<String, Object> reassignCase(Id caseId, Id newSpecialistId) {
        Case c = new Case(
            Id = caseId,
            pstar__Peer_Specialist__c = newSpecialistId
        );
        update c;

        return new Map<String, Object>{
            'success' => true
        };
    }

    // ==================== PERFORMANCE METRICS METHODS ====================

    /**
     * @description Get performance metrics for a specialist or team
     * @param specialistId Optional - specific specialist User Id (null for team metrics)
     * @param startDate Start of date range
     * @param endDate End of date range
     * @return PerformanceMetrics wrapper
     */
    @AuraEnabled(cacheable=true)
    public static PerformanceMetrics getPerformanceMetrics(Id specialistId, Date startDate, Date endDate) {
        PerformanceMetrics metrics = new PerformanceMetrics();

        DateTime startDateTime = DateTime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        DateTime endDateTime = DateTime.newInstance(endDate, Time.newInstance(23, 59, 59, 0));

        // Build query based on whether we're filtering by specialist
        String query = 'SELECT Id, Status, SchedStartTime, DueDate, ' +
                      'Check_In_Time__c, Check_Out_Time__c, Actual_Duration__c, Duration ' +
                      'FROM ServiceAppointment ' +
                      'WHERE ((SchedStartTime >= :startDateTime AND SchedStartTime <= :endDateTime) ' +
                      'OR (DueDate >= :startDateTime AND DueDate <= :endDateTime)) ';

        if (specialistId != null) {
            List<ServiceResource> resources = [SELECT Id FROM ServiceResource WHERE RelatedRecordId = :specialistId LIMIT 1];
            if (!resources.isEmpty()) {
                Id resourceId = resources[0].Id;
                query += 'AND Id IN (SELECT ServiceAppointmentId FROM AssignedResource WHERE ServiceResourceId = :resourceId) ';
            }
        }

        List<ServiceAppointment> appointments = Database.query(query);

        Integer totalDurationMinutes = 0;
        Integer actualDurationMinutes = 0;
        Integer visitsWithDuration = 0;

        for (ServiceAppointment sa : appointments) {
            metrics.totalVisits++;

            if (sa.Status == 'Completed') {
                metrics.completedVisits++;

                // Track durations
                if (sa.Actual_Duration__c != null) {
                    actualDurationMinutes += Integer.valueOf(sa.Actual_Duration__c);
                    visitsWithDuration++;
                }
                if (sa.Duration != null) {
                    totalDurationMinutes += Integer.valueOf(sa.Duration);
                }
            } else if (sa.Status == 'Cannot Complete') {
                metrics.missedVisits++;
            } else if (sa.Status == 'Canceled') {
                metrics.canceledVisits++;
            }
        }

        // Calculate rates
        if (metrics.totalVisits > 0) {
            metrics.completionRate = (metrics.completedVisits * 100.0 / metrics.totalVisits).setScale(1);
            metrics.missedRate = (metrics.missedVisits * 100.0 / metrics.totalVisits).setScale(1);
            metrics.cancelRate = (metrics.canceledVisits * 100.0 / metrics.totalVisits).setScale(1);
        }

        // Calculate average duration
        if (visitsWithDuration > 0) {
            metrics.avgActualDuration = (actualDurationMinutes * 1.0 / visitsWithDuration).setScale(0);
        }

        // Get IRP follow-up compliance
        Integer followUpsDue = 0;
        Integer followUpsCompleted = 0;

        String caseQuery = 'SELECT Id, pstar__Follow_Up_IRP_Due__c, pstar__Follow_Up_IRP_Completed__c ' +
                          'FROM Case ' +
                          'WHERE pstar__Follow_Up_IRP_Due__c >= :startDate ' +
                          'AND pstar__Follow_Up_IRP_Due__c <= :endDate ' +
                          'AND pstar__Follow_Up_IRP_Due__c != null ';

        if (specialistId != null) {
            caseQuery += 'AND pstar__Peer_Specialist__c = :specialistId ';
        }

        for (Case c : Database.query(caseQuery)) {
            followUpsDue++;
            if (c.pstar__Follow_Up_IRP_Completed__c == true) {
                followUpsCompleted++;
            }
        }

        metrics.followUpsDue = followUpsDue;
        metrics.followUpsCompleted = followUpsCompleted;
        if (followUpsDue > 0) {
            metrics.followUpComplianceRate = (followUpsCompleted * 100.0 / followUpsDue).setScale(1);
        }

        // Get weekly trends (last 4 weeks)
        metrics.weeklyTrends = getWeeklyTrends(specialistId, endDate);

        return metrics;
    }

    /**
     * @description Helper method to get weekly trend data
     */
    private static List<WeeklyTrend> getWeeklyTrends(Id specialistId, Date endDate) {
        List<WeeklyTrend> trends = new List<WeeklyTrend>();

        // Go back 4 weeks from end date
        for (Integer i = 3; i >= 0; i--) {
            Date weekEnd = endDate.addDays(-7 * i);
            Date weekStart = weekEnd.addDays(-6);

            DateTime startDateTime = DateTime.newInstance(weekStart, Time.newInstance(0, 0, 0, 0));
            DateTime endDateTime = DateTime.newInstance(weekEnd, Time.newInstance(23, 59, 59, 0));

            String query = 'SELECT Id, Status FROM ServiceAppointment ' +
                          'WHERE SchedStartTime >= :startDateTime AND SchedStartTime <= :endDateTime ';

            if (specialistId != null) {
                List<ServiceResource> resources = [SELECT Id FROM ServiceResource WHERE RelatedRecordId = :specialistId LIMIT 1];
                if (!resources.isEmpty()) {
                    Id resourceId = resources[0].Id;
                    query += 'AND Id IN (SELECT ServiceAppointmentId FROM AssignedResource WHERE ServiceResourceId = :resourceId) ';
                }
            }

            Integer total = 0;
            Integer completed = 0;

            for (ServiceAppointment sa : Database.query(query)) {
                total++;
                if (sa.Status == 'Completed') {
                    completed++;
                }
            }

            trends.add(new WeeklyTrend(weekStart, weekEnd, total, completed));
        }

        return trends;
    }

    // ==================== WRAPPER CLASSES ====================

    /**
     * @description Performance metrics wrapper
     */
    public class PerformanceMetrics {
        @AuraEnabled public Integer totalVisits { get; set; }
        @AuraEnabled public Integer completedVisits { get; set; }
        @AuraEnabled public Integer missedVisits { get; set; }
        @AuraEnabled public Integer canceledVisits { get; set; }
        @AuraEnabled public Decimal completionRate { get; set; }
        @AuraEnabled public Decimal missedRate { get; set; }
        @AuraEnabled public Decimal cancelRate { get; set; }
        @AuraEnabled public Decimal avgActualDuration { get; set; }
        @AuraEnabled public Integer followUpsDue { get; set; }
        @AuraEnabled public Integer followUpsCompleted { get; set; }
        @AuraEnabled public Decimal followUpComplianceRate { get; set; }
        @AuraEnabled public List<WeeklyTrend> weeklyTrends { get; set; }

        public PerformanceMetrics() {
            this.totalVisits = 0;
            this.completedVisits = 0;
            this.missedVisits = 0;
            this.canceledVisits = 0;
            this.completionRate = 0;
            this.missedRate = 0;
            this.cancelRate = 0;
            this.avgActualDuration = 0;
            this.followUpsDue = 0;
            this.followUpsCompleted = 0;
            this.followUpComplianceRate = 0;
            this.weeklyTrends = new List<WeeklyTrend>();
        }
    }

    /**
     * @description Weekly trend data point
     */
    public class WeeklyTrend {
        @AuraEnabled public Date weekStart { get; set; }
        @AuraEnabled public Date weekEnd { get; set; }
        @AuraEnabled public String weekLabel { get; set; }
        @AuraEnabled public Integer totalVisits { get; set; }
        @AuraEnabled public Integer completedVisits { get; set; }
        @AuraEnabled public Decimal completionRate { get; set; }

        public WeeklyTrend(Date weekStart, Date weekEnd, Integer total, Integer completed) {
            this.weekStart = weekStart;
            this.weekEnd = weekEnd;
            this.weekLabel = weekStart.format() + ' - ' + weekEnd.format();
            this.totalVisits = total;
            this.completedVisits = completed;
            this.completionRate = total > 0 ? (completed * 100.0 / total).setScale(1) : 0;
        }
    }

    /**
     * @description Team dashboard metrics wrapper for manager view
     */
    public class TeamDashboardMetrics {
        @AuraEnabled public Integer totalVisits { get; set; }
        @AuraEnabled public Integer completedVisits { get; set; }
        @AuraEnabled public Integer scheduledVisits { get; set; }
        @AuraEnabled public Integer inProgressVisits { get; set; }
        @AuraEnabled public Integer missedVisits { get; set; }
        @AuraEnabled public Integer canceledVisits { get; set; }
        @AuraEnabled public Decimal completionRate { get; set; }
        @AuraEnabled public Integer pendingReviews { get; set; }
        @AuraEnabled public List<SpecialistWorkload> specialists { get; set; }

        public TeamDashboardMetrics() {
            this.totalVisits = 0;
            this.completedVisits = 0;
            this.scheduledVisits = 0;
            this.inProgressVisits = 0;
            this.missedVisits = 0;
            this.canceledVisits = 0;
            this.completionRate = 0;
            this.pendingReviews = 0;
            this.specialists = new List<SpecialistWorkload>();
        }
    }

    /**
     * @description Specialist workload wrapper for team dashboard
     */
    public class SpecialistWorkload implements Comparable {
        @AuraEnabled public Id resourceId { get; set; }
        @AuraEnabled public Id userId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String photoUrl { get; set; }
        @AuraEnabled public Integer totalVisits { get; set; }
        @AuraEnabled public Integer completedVisits { get; set; }
        @AuraEnabled public Integer missedVisits { get; set; }
        @AuraEnabled public Decimal completionRate { get; set; }

        public SpecialistWorkload(ServiceResource sr) {
            this.resourceId = sr.Id;
            this.userId = sr.RelatedRecordId;
            this.name = sr.Name;
            this.photoUrl = sr.RelatedRecord?.SmallPhotoUrl;
            this.totalVisits = 0;
            this.completedVisits = 0;
            this.missedVisits = 0;
            this.completionRate = 0;
        }

        public Integer compareTo(Object compareTo) {
            SpecialistWorkload other = (SpecialistWorkload) compareTo;
            // Sort by total visits descending
            if (this.totalVisits > other.totalVisits) return -1;
            if (this.totalVisits < other.totalVisits) return 1;
            return 0;
        }
    }

    /**
     * @description Route visit wrapper for route planning
     */
    public class RouteVisit {
        @AuraEnabled public Id visitId { get; set; }
        @AuraEnabled public String visitNumber { get; set; }
        @AuraEnabled public String subject { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public DateTime scheduledStart { get; set; }
        @AuraEnabled public DateTime scheduledEnd { get; set; }
        @AuraEnabled public Integer durationMinutes { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String postalCode { get; set; }
        @AuraEnabled public String fullAddress { get; set; }
        @AuraEnabled public String mapsUrl { get; set; }
        @AuraEnabled public String visitType { get; set; }
        @AuraEnabled public Integer routeOrder { get; set; }
        @AuraEnabled public String formattedTime { get; set; }

        public RouteVisit(ServiceAppointment sa, Integer order) {
            this.visitId = sa.Id;
            this.visitNumber = sa.AppointmentNumber;
            this.subject = sa.Subject;
            this.status = sa.Status;
            this.scheduledStart = sa.SchedStartTime;
            this.scheduledEnd = sa.SchedEndTime;
            this.durationMinutes = sa.Duration != null ? Integer.valueOf(sa.Duration) : 60;
            this.street = sa.Street;
            this.city = sa.City;
            this.state = sa.State;
            this.postalCode = sa.PostalCode;
            this.visitType = sa.WorkType?.Name;
            this.routeOrder = order;
            this.formattedTime = sa.SchedStartTime != null ? sa.SchedStartTime.format('h:mm a') : '';

            // Build full address
            List<String> addrParts = new List<String>();
            if (String.isNotBlank(sa.Street)) addrParts.add(sa.Street);
            if (String.isNotBlank(sa.City)) addrParts.add(sa.City);
            if (String.isNotBlank(sa.State)) addrParts.add(sa.State);
            if (String.isNotBlank(sa.PostalCode)) addrParts.add(sa.PostalCode);
            this.fullAddress = String.join(addrParts, ', ');

            // Build Google Maps URL
            if (String.isNotBlank(this.fullAddress)) {
                this.mapsUrl = 'https://www.google.com/maps/search/?api=1&query=' +
                              EncodingUtil.urlEncode(this.fullAddress, 'UTF-8');
            }
        }
    }

    /**
     * @description Specialist caseload wrapper
     */
    public class SpecialistCaseload implements Comparable {
        @AuraEnabled public Id resourceId { get; set; }
        @AuraEnabled public Id userId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String photoUrl { get; set; }
        @AuraEnabled public Integer activeCases { get; set; }
        @AuraEnabled public Integer totalCases { get; set; }
        @AuraEnabled public String workloadClass { get; set; }

        public SpecialistCaseload(ServiceResource sr, Integer active, Integer total) {
            this.resourceId = sr.Id;
            this.userId = sr.RelatedRecordId;
            this.name = sr.Name;
            this.photoUrl = sr.RelatedRecord?.SmallPhotoUrl;
            this.activeCases = active;
            this.totalCases = total;

            // Workload indicator: high (>15), medium (8-15), low (<8)
            if (active > 15) {
                this.workloadClass = 'workload-high';
            } else if (active >= 8) {
                this.workloadClass = 'workload-medium';
            } else {
                this.workloadClass = 'workload-low';
            }
        }

        public Integer compareTo(Object compareTo) {
            SpecialistCaseload other = (SpecialistCaseload) compareTo;
            // Sort by active cases descending
            if (this.activeCases > other.activeCases) return -1;
            if (this.activeCases < other.activeCases) return 1;
            return 0;
        }
    }

    /**
     * @description Case wrapper for caseload view
     */
    public class CaseWrapper {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String participantName { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Date serviceStartDate { get; set; }
        @AuraEnabled public Date followUpDueDate { get; set; }
        @AuraEnabled public Decimal hoursRemaining { get; set; }
        @AuraEnabled public Integer noShowCount { get; set; }
        @AuraEnabled public Boolean isClosed { get; set; }
        @AuraEnabled public String statusClass { get; set; }

        public CaseWrapper(Case c) {
            this.caseId = c.Id;
            this.caseNumber = c.CaseNumber;
            this.participantName = c.Contact?.Name;
            this.status = c.Status;
            this.serviceStartDate = c.pstar__Service_Start_Date__c;
            this.followUpDueDate = c.pstar__Follow_Up_IRP_Due__c;
            this.hoursRemaining = c.pstar__Authorization_Hours_Remaining__c;
            this.noShowCount = c.pstar__No_Show_Count__c != null ? Integer.valueOf(c.pstar__No_Show_Count__c) : 0;
            this.isClosed = c.IsClosed;

            // Status styling
            if (c.IsClosed) {
                this.statusClass = 'slds-badge';
            } else if (this.hoursRemaining != null && this.hoursRemaining < 5) {
                this.statusClass = 'slds-badge slds-theme_error';
            } else {
                this.statusClass = 'slds-badge slds-theme_success';
            }
        }
    }

    /**
     * @description Dashboard metrics wrapper for home screen
     */
    public class DashboardMetrics {
        @AuraEnabled public Integer todayCount { get; set; }
        @AuraEnabled public Integer thisWeekCount { get; set; }
        @AuraEnabled public Integer pendingCount { get; set; }
        @AuraEnabled public Integer confirmedCount { get; set; }
        @AuraEnabled public Integer inSessionCount { get; set; }
        @AuraEnabled public Integer completedCount { get; set; }
        @AuraEnabled public Integer missedCount { get; set; }
        @AuraEnabled public Integer overdueCount { get; set; }
        @AuraEnabled public Integer followUpsNeededCount { get; set; }

        public DashboardMetrics() {
            this.todayCount = 0;
            this.thisWeekCount = 0;
            this.pendingCount = 0;
            this.confirmedCount = 0;
            this.inSessionCount = 0;
            this.completedCount = 0;
            this.missedCount = 0;
            this.overdueCount = 0;
            this.followUpsNeededCount = 0;
        }
    }

    /**
     * @description Case follow-up wrapper for IRP tracking
     */
    public class CaseFollowUpWrapper {
        @AuraEnabled public Id caseId { get; set; }
        @AuraEnabled public String caseNumber { get; set; }
        @AuraEnabled public String participantName { get; set; }
        @AuraEnabled public Date followUpDueDate { get; set; }
        @AuraEnabled public Integer daysUntilDue { get; set; }
        @AuraEnabled public Boolean isOverdue { get; set; }
        @AuraEnabled public Integer noShowCount { get; set; }
        @AuraEnabled public Decimal hoursRemaining { get; set; }
        @AuraEnabled public String urgencyClass { get; set; }

        public CaseFollowUpWrapper(Case c, Date today) {
            this.caseId = c.Id;
            this.caseNumber = c.CaseNumber;
            this.participantName = c.Contact?.Name;
            this.followUpDueDate = c.pstar__Follow_Up_IRP_Due__c;
            this.daysUntilDue = c.pstar__Follow_Up_IRP_Due__c != null ?
                               today.daysBetween(c.pstar__Follow_Up_IRP_Due__c) : null;
            this.isOverdue = this.daysUntilDue != null && this.daysUntilDue < 0;
            this.noShowCount = c.pstar__No_Show_Count__c != null ? Integer.valueOf(c.pstar__No_Show_Count__c) : 0;
            this.hoursRemaining = c.pstar__Authorization_Hours_Remaining__c;

            // Set urgency class for styling
            if (this.isOverdue) {
                this.urgencyClass = 'slds-theme_error';
            } else if (this.daysUntilDue != null && this.daysUntilDue <= 7) {
                this.urgencyClass = 'slds-theme_warning';
            } else {
                this.urgencyClass = 'slds-theme_default';
            }
        }
    }

    /**
     * @description Wrapper class for Peer Visits (ServiceAppointment in Field Service)
     */
    public virtual class PeerVisitWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String serviceType { get; set; }  // Visit type (Initial Recovery Plan, Recovery Check-in, etc.)
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public DateTime scheduledStart { get; set; }
        @AuraEnabled public DateTime scheduledEnd { get; set; }
        @AuraEnabled public Date dueDate { get; set; }
        @AuraEnabled public Integer durationMinutes { get; set; }
        @AuraEnabled public String locationType { get; set; }
        @AuraEnabled public String locationAddress { get; set; }
        @AuraEnabled public Id assignedUserId { get; set; }      // Peer Specialist's User Id
        @AuraEnabled public String assignedUserName { get; set; } // Peer Specialist name
        @AuraEnabled public Id caseId { get; set; }              // Meeting (Work Order) Id
        @AuraEnabled public String caseNumber { get; set; }      // Meeting reference
        @AuraEnabled public String peerName { get; set; }        // Participant name
        @AuraEnabled public Boolean peerConfirmed { get; set; }  // Is visit confirmed?
        @AuraEnabled public String notes { get; set; }
        @AuraEnabled public String cssClass { get; set; }

        public PeerVisitWrapper(ServiceAppointment sa) {
            this.id = sa.Id;
            this.name = sa.AppointmentNumber;
            this.serviceType = sa.WorkType?.Name;
            this.status = sa.Status;
            this.scheduledStart = sa.SchedStartTime;
            this.scheduledEnd = sa.SchedEndTime;
            this.dueDate = sa.DueDate != null ? sa.DueDate.date() : null;
            this.durationMinutes = sa.Duration != null ? Integer.valueOf(sa.Duration) : 60;
            this.locationType = 'On-site';
            this.locationAddress = buildAddress(sa);
            // Get assigned Peer Specialist info from subquery
            if (sa.ServiceResources != null && !sa.ServiceResources.isEmpty()) {
                AssignedResource ar = sa.ServiceResources[0];
                this.assignedUserId = ar.ServiceResource?.RelatedRecordId;
                this.assignedUserName = ar.ServiceResource?.Name;
            }
            // Confirmed = Scheduled or Dispatched (Confirmed in Peerstar terms)
            this.peerConfirmed = (sa.Status == 'Scheduled' || sa.Status == 'Dispatched');
            this.notes = sa.Description;
            this.cssClass = getStatusCssClass(sa.Status);
        }

        private String buildAddress(ServiceAppointment sa) {
            List<String> parts = new List<String>();
            if (String.isNotBlank(sa.Street)) parts.add(sa.Street);
            if (String.isNotBlank(sa.City)) parts.add(sa.City);
            if (String.isNotBlank(sa.State)) parts.add(sa.State);
            if (String.isNotBlank(sa.PostalCode)) parts.add(sa.PostalCode);
            return String.join(parts, ', ');
        }

        private String getStatusCssClass(String status) {
            // Peerstar statuses: Pending, Scheduled, Confirmed, In Session, Visit Complete, Missed, Canceled
            // Maps to Field Service: None, Scheduled, Dispatched, In Progress, Completed, Cannot Complete, Canceled
            if (status == 'Completed') return 'slds-theme_success';           // Visit Complete
            if (status == 'Canceled' || status == 'Cannot Complete') return 'slds-theme_error';  // Canceled or Missed
            if (status == 'Scheduled' || status == 'Dispatched') return 'slds-theme_info';       // Scheduled or Confirmed
            if (status == 'In Progress') return 'slds-theme_warning';         // In Session
            return 'slds-theme_alt-inverse';                                   // Pending (None)
        }
    }

    // Backward compatibility alias
    public class ScheduledServiceWrapper extends PeerVisitWrapper {
        public ScheduledServiceWrapper(ServiceAppointment sa) {
            super(sa);
        }
    }

    /**
     * @description Wrapper class for time slots
     */
    public class TimeSlotWrapper {
        @AuraEnabled public DateTime startTime { get; set; }
        @AuraEnabled public DateTime endTime { get; set; }
        @AuraEnabled public String displayTime { get; set; }

        public TimeSlotWrapper(DateTime start, Integer durationMinutes) {
            this.startTime = start;
            this.endTime = start.addMinutes(durationMinutes);
            this.displayTime = start.format('h:mm a') + ' - ' + this.endTime.format('h:mm a');
        }
    }

    /**
     * @description Wrapper class for Peer Specialists (ServiceResource in Field Service)
     */
    public virtual class PeerSpecialistWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String photoUrl { get; set; }
        @AuraEnabled public String email { get; set; }

        public PeerSpecialistWrapper(ServiceResource sr) {
            this.id = sr.RelatedRecordId; // User Id for filtering
            this.name = sr.Name;
            this.photoUrl = sr.RelatedRecord?.SmallPhotoUrl;
            this.email = sr.RelatedRecord?.Email;
        }
    }

    // Backward compatibility alias
    public class UserWrapper extends PeerSpecialistWrapper {
        public UserWrapper(ServiceResource sr) {
            super(sr);
        }
    }

    // ==================== IRP SCHEDULING METHODS ====================

    /**
     * @description Get referral details for IRP scheduling
     * @param referralId The Opportunity record Id
     * @return ReferralSchedulingWrapper with referral and contact info
     */
    @AuraEnabled(cacheable=true)
    public static ReferralSchedulingWrapper getReferralForScheduling(Id referralId) {
        Opportunity opp = [
            SELECT Id, Name, pstar__MA_ID__c, pstar__Mobile_Phone__c, pstar__DOB__c,
                   pstar__County__c, pstar__Service_Categories__c,
                   pstar__IRP_Scheduled_Date__c, pstar__IRP_Specialist__c,
                   pstar__IRP_Specialist__r.Name, pstar__IRP_Completed__c,
                   pstar__Preferred_Location__c, pstar__Preferred_Schedule_Window__c,
                   Account.Name, Account.BillingStreet, Account.BillingCity,
                   Account.BillingState, Account.BillingPostalCode,
                   Account.Phone
            FROM Opportunity
            WHERE Id = :referralId
            LIMIT 1
        ];

        return new ReferralSchedulingWrapper(opp);
    }

    /**
     * @description Get available time slots for IRP scheduling (90 minute duration)
     * @param specialistUserId The User Id of the specialist
     * @param targetDate The date to check availability
     * @return List of available time slots
     */
    @AuraEnabled
    public static List<TimeSlotWrapper> getIRPTimeSlots(Id specialistUserId, Date targetDate) {
        // IRP appointments are 90 minutes
        return getAvailableTimeSlots(specialistUserId, targetDate, 90);
    }

    /**
     * @description Schedule an IRP appointment for a referral
     * @param referralId The Opportunity record Id
     * @param specialistUserId The User Id of the IRP Specialist
     * @param scheduledDateTime The scheduled date/time for the IRP
     * @param notes Optional notes for the appointment
     * @return Map with success status and created appointment Id
     */
    @AuraEnabled
    public static Map<String, Object> scheduleIRP(Id referralId, Id specialistUserId, DateTime scheduledDateTime, String notes) {
        // Get referral details
        Opportunity opp = [
            SELECT Id, Name, AccountId, pstar__MA_ID__c, pstar__County__c,
                   Account.BillingStreet, Account.BillingCity,
                   Account.BillingState, Account.BillingPostalCode
            FROM Opportunity
            WHERE Id = :referralId
            LIMIT 1
        ];

        // Get the ServiceResource for the specialist
        List<ServiceResource> resources = [
            SELECT Id FROM ServiceResource
            WHERE RelatedRecordId = :specialistUserId AND IsActive = true
            LIMIT 1
        ];

        if (resources.isEmpty()) {
            throw new AuraHandledException('Selected specialist is not configured as a Service Resource');
        }

        // Get Initial IRP Work Type
        List<WorkType> workTypes = [
            SELECT Id FROM WorkType
            WHERE Name LIKE '%Initial%IRP%' OR Name LIKE '%IRP%'
            LIMIT 1
        ];

        Id workTypeId = workTypes.isEmpty() ? null : workTypes[0].Id;

        // Create WorkOrder first
        WorkOrder wo = new WorkOrder(
            AccountId = opp.AccountId,
            Subject = 'Initial IRP - ' + opp.Name,
            Status = 'New',
            WorkTypeId = workTypeId,
            Referral__c = referralId
        );
        insert wo;

        // Create ServiceAppointment
        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = wo.Id,
            Subject = 'Initial IRP - ' + opp.Name,
            Status = 'Scheduled',
            SchedStartTime = scheduledDateTime,
            SchedEndTime = scheduledDateTime.addMinutes(90),
            Duration = 90,
            DurationType = 'Minutes',
            EarliestStartTime = scheduledDateTime.addHours(-1),
            DueDate = scheduledDateTime.addHours(1),
            Street = opp.Account.BillingStreet,
            City = opp.Account.BillingCity,
            State = opp.Account.BillingState,
            PostalCode = opp.Account.BillingPostalCode,
            Description = notes
        );
        insert sa;

        // Assign the specialist
        AssignedResource ar = new AssignedResource(
            ServiceAppointmentId = sa.Id,
            ServiceResourceId = resources[0].Id
        );
        insert ar;

        // Update the Opportunity with IRP info
        opp.pstar__IRP_Specialist__c = specialistUserId;
        opp.pstar__IRP_Scheduled_Date__c = scheduledDateTime.date();
        opp.StageName = 'IRP Scheduling';
        update opp;

        return new Map<String, Object>{
            'success' => true,
            'appointmentId' => sa.Id,
            'workOrderId' => wo.Id,
            'scheduledDate' => scheduledDateTime
        };
    }

    /**
     * @description Reschedule an existing IRP appointment
     * @param appointmentId The ServiceAppointment record Id
     * @param newDateTime The new scheduled date/time
     * @param newSpecialistUserId Optional - new specialist (null to keep current)
     * @return Map with success status
     */
    @AuraEnabled
    public static Map<String, Object> rescheduleIRP(Id appointmentId, DateTime newDateTime, Id newSpecialistUserId) {
        ServiceAppointment sa = [
            SELECT Id, ParentRecordId, SchedStartTime
            FROM ServiceAppointment
            WHERE Id = :appointmentId
            LIMIT 1
        ];

        // Update appointment time
        sa.SchedStartTime = newDateTime;
        sa.SchedEndTime = newDateTime.addMinutes(90);
        sa.EarliestStartTime = newDateTime.addHours(-1);
        sa.DueDate = newDateTime.addHours(1);
        update sa;

        // If new specialist provided, update assignment
        if (newSpecialistUserId != null) {
            List<ServiceResource> resources = [
                SELECT Id FROM ServiceResource
                WHERE RelatedRecordId = :newSpecialistUserId AND IsActive = true
                LIMIT 1
            ];

            if (!resources.isEmpty()) {
                // Remove existing assignment
                delete [SELECT Id FROM AssignedResource WHERE ServiceAppointmentId = :appointmentId];

                // Create new assignment
                AssignedResource ar = new AssignedResource(
                    ServiceAppointmentId = appointmentId,
                    ServiceResourceId = resources[0].Id
                );
                insert ar;

                // Update Opportunity IRP Specialist
                List<WorkOrder> wos = [SELECT Id, Referral__c FROM WorkOrder WHERE Id = :sa.ParentRecordId LIMIT 1];
                if (!wos.isEmpty() && wos[0].Referral__c != null) {
                    update new Opportunity(
                        Id = wos[0].Referral__c,
                        pstar__IRP_Specialist__c = newSpecialistUserId,
                        pstar__IRP_Scheduled_Date__c = newDateTime.date()
                    );
                }
            }
        }

        return new Map<String, Object>{
            'success' => true,
            'newDateTime' => newDateTime
        };
    }

    /**
     * @description Wrapper for referral scheduling info
     */
    public class ReferralSchedulingWrapper {
        @AuraEnabled public Id referralId { get; set; }
        @AuraEnabled public String referralName { get; set; }
        @AuraEnabled public String participantName { get; set; }
        @AuraEnabled public String maId { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public Date dob { get; set; }
        @AuraEnabled public String county { get; set; }
        @AuraEnabled public String serviceType { get; set; }
        @AuraEnabled public String address { get; set; }
        @AuraEnabled public String preferredLocation { get; set; }
        @AuraEnabled public String preferredWindow { get; set; }
        @AuraEnabled public Date irpScheduledDate { get; set; }
        @AuraEnabled public Id irpSpecialistId { get; set; }
        @AuraEnabled public String irpSpecialistName { get; set; }
        @AuraEnabled public Boolean irpCompleted { get; set; }
        @AuraEnabled public Boolean hasExistingIRP { get; set; }

        public ReferralSchedulingWrapper(Opportunity opp) {
            this.referralId = opp.Id;
            this.referralName = opp.Name;
            this.participantName = opp.Account?.Name;
            this.maId = opp.pstar__MA_ID__c;
            this.phone = opp.pstar__Mobile_Phone__c != null ? opp.pstar__Mobile_Phone__c : opp.Account?.Phone;
            this.dob = opp.pstar__DOB__c;
            this.county = opp.pstar__County__c;
            this.serviceType = opp.pstar__Service_Categories__c;
            this.preferredLocation = opp.pstar__Preferred_Location__c;
            this.preferredWindow = opp.pstar__Preferred_Schedule_Window__c;
            this.irpScheduledDate = opp.pstar__IRP_Scheduled_Date__c != null ? opp.pstar__IRP_Scheduled_Date__c.date() : null;
            this.irpSpecialistId = opp.pstar__IRP_Specialist__c;
            this.irpSpecialistName = opp.pstar__IRP_Specialist__r?.Name;
            this.irpCompleted = opp.pstar__IRP_Completed__c;
            this.hasExistingIRP = opp.pstar__IRP_Scheduled_Date__c != null;

            // Build address
            List<String> addrParts = new List<String>();
            if (String.isNotBlank(opp.Account?.BillingStreet)) addrParts.add(opp.Account.BillingStreet);
            if (String.isNotBlank(opp.Account?.BillingCity)) addrParts.add(opp.Account.BillingCity);
            if (String.isNotBlank(opp.Account?.BillingState)) addrParts.add(opp.Account.BillingState);
            if (String.isNotBlank(opp.Account?.BillingPostalCode)) addrParts.add(opp.Account.BillingPostalCode);
            this.address = String.join(addrParts, ', ');
        }
    }
}