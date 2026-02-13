/**
 * @description Apex controller for Referral/Intake Management LWCs
 *              Provides methods for pipeline management, intake workflow,
 *              authorization tracking, specialist matching, and analytics.
 *
 * Peerstar Terminology:
 *   - Referrals = Opportunity (with pstar__ custom fields)
 *   - Leads = Lead (initial contact before conversion)
 *   - Participants = Contacts receiving peer support
 *   - Peer Specialists = Users/ServiceResources providing services
 */
public with sharing class ReferralController {

    // ==================== PIPELINE MANAGEMENT (#6) ====================

    /**
     * @description Get referrals grouped by stage for pipeline board
     * @return Pipeline data with referrals by stage
     */
    @AuraEnabled(cacheable=true)
    public static PipelineData getReferralPipeline() {
        PipelineData pipeline = new PipelineData();

        // Define stage order
        List<String> stageOrder = new List<String>{
            'New Referral', 'Eligibility Check', 'Authorization Pending',
            'IRP Scheduling', 'IRP Completed', 'Admission', 'Closed Won', 'Closed Lost'
        };
        pipeline.stages = stageOrder;
        pipeline.referralsByStage = new Map<String, List<ReferralCard>>();

        // Initialize empty lists for each stage
        for (String stage : stageOrder) {
            pipeline.referralsByStage.put(stage, new List<ReferralCard>());
        }

        // Query referrals
        List<Opportunity> referrals = [
            SELECT Id, Name, StageName, pstar__Referral_Date__c, pstar__DOB__c,
                   pstar__County__c, pstar__Service_Categories__c, pstar__MA_ID__c,
                   pstar__Authorization_Status__c, pstar__Eligibility_Verified__c,
                   pstar__IRP_Scheduled_Date__c, pstar__IRP_Completed__c,
                   pstar__Field_Representative__c, pstar__Field_Representative__r.Name,
                   pstar__Mobile_Phone__c, pstar__Days_to_Admission__c,
                   Owner.Name, CreatedDate
            FROM Opportunity
            WHERE IsClosed = false
            OR (IsClosed = true AND CloseDate >= LAST_N_DAYS:30)
            ORDER BY pstar__Referral_Date__c ASC NULLS LAST
            LIMIT 500
        ];

        for (Opportunity opp : referrals) {
            ReferralCard card = new ReferralCard(opp);
            String stage = opp.StageName != null ? opp.StageName : 'New Referral';
            if (pipeline.referralsByStage.containsKey(stage)) {
                pipeline.referralsByStage.get(stage).add(card);
            } else {
                // Put in first stage if unknown
                pipeline.referralsByStage.get(stageOrder[0]).add(card);
            }
        }

        // Calculate stage counts
        pipeline.stageCounts = new Map<String, Integer>();
        for (String stage : stageOrder) {
            pipeline.stageCounts.put(stage, pipeline.referralsByStage.get(stage).size());
        }

        return pipeline;
    }

    /**
     * @description Update referral stage (for drag-and-drop)
     * @param referralId Opportunity Id
     * @param newStage New stage name
     * @return Updated referral
     */
    @AuraEnabled
    public static ReferralCard updateReferralStage(Id referralId, String newStage) {
        Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :referralId LIMIT 1];
        opp.StageName = newStage;
        update opp;

        // Re-query with all fields
        opp = [
            SELECT Id, Name, StageName, pstar__Referral_Date__c, pstar__DOB__c,
                   pstar__County__c, pstar__Service_Categories__c, pstar__MA_ID__c,
                   pstar__Authorization_Status__c, pstar__Eligibility_Verified__c,
                   pstar__IRP_Scheduled_Date__c, pstar__IRP_Completed__c,
                   pstar__Field_Representative__c, pstar__Field_Representative__r.Name,
                   pstar__Mobile_Phone__c, pstar__Days_to_Admission__c,
                   Owner.Name, CreatedDate
            FROM Opportunity WHERE Id = :referralId LIMIT 1
        ];

        return new ReferralCard(opp);
    }

    // ==================== DOCTOR DETAILS ====================

    /**
     * @description Save doctor details for a referral
     * @param referralId Opportunity Id
     * @param doctorType Type of doctor (PCP, Psychiatrist, Therapist)
     * @param name Doctor name
     * @param phone Doctor phone
     * @param address Doctor address
     * @param email Doctor email
     * @return Success status
     */
    @AuraEnabled
    public static Boolean saveDoctorDetails(Id referralId, String doctorType, String name, String phone, String address, String email) {
        Opportunity opp = new Opportunity(Id = referralId);

        if (doctorType == 'PCP') {
            opp.pstar__Primary_Care_Physician__c = name;
            opp.pstar__PCP_Phone__c = phone;
            opp.pstar__PCP_Address__c = address;
            opp.pstar__PCP_Email__c = email;
        } else if (doctorType == 'Psychiatrist') {
            opp.pstar__Psychiatrist__c = name;
            opp.pstar__Psychiatrist_Phone__c = phone;
            opp.pstar__Psychiatrist_Address__c = address;
            opp.pstar__Psychiatrist_Email__c = email;
        } else if (doctorType == 'Therapist') {
            opp.pstar__Therapist_Name__c = name;
            opp.pstar__Therapist_Phone__c = phone;
            opp.pstar__Therapist_Address__c = address;
            opp.pstar__Therapist_Email__c = email;
        }

        update opp;
        return true;
    }

    // ==================== INTAKE CHECKLIST (#7) ====================

    /**
     * @description Get intake checklist status for a referral
     * @param referralId Opportunity Id
     * @return Checklist with completion status
     */
    @AuraEnabled(cacheable=true)
    public static IntakeChecklist getIntakeChecklist(Id referralId) {
        Opportunity opp = [
            SELECT Id, Name, pstar__DOB__c, pstar__MA_ID__c, pstar__County__c,
                   pstar__Mobile_Phone__c, pstar__Email__c, pstar__Street_Address__c,
                   pstar__Address_City__c, pstar__State__c, pstar__Zip_Code__c,
                   pstar__Gender__c, pstar__Race__c, pstar__Ethnicity__c,
                   pstar__Eligibility_Verified__c, pstar__Authorization_Status__c,
                   pstar__Authorization_Number__c, pstar__Script_Received__c,
                   pstar__IRP_Scheduled_Date__c, pstar__IRP_Completed__c,
                   pstar__Field_Representative__c, pstar__Admission_Date__c,
                   pstar__Diagnosis_Intake__c, pstar__Living_Situation__c,
                   pstar__Referral_Date__c, pstar__Service_Categories__c
            FROM Opportunity
            WHERE Id = :referralId
            LIMIT 1
        ];

        return new IntakeChecklist(opp);
    }

    // ==================== DOCUMENT TRACKER (#8) ====================

    /**
     * @description Get document checklist for a referral
     * @param referralId Opportunity Id
     * @return Document status list
     */
    @AuraEnabled(cacheable=true)
    public static List<DocumentStatus> getDocumentChecklist(Id referralId) {
        List<DocumentStatus> docs = new List<DocumentStatus>();

        Opportunity opp = [
            SELECT Id, pstar__Script_Received__c, pstar__Eligibility_Verified__c,
                   pstar__ROI_Analysis_Completed__c, pstar__IRP_Completed__c
            FROM Opportunity
            WHERE Id = :referralId
            LIMIT 1
        ];

        // Check for attached files
        Map<String, ContentDocumentLink> attachedDocs = new Map<String, ContentDocumentLink>();
        for (ContentDocumentLink cdl : [
            SELECT Id, ContentDocument.Title, ContentDocument.FileType,
                   ContentDocument.CreatedDate, ContentDocument.CreatedBy.Name
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :referralId
        ]) {
            attachedDocs.put(cdl.ContentDocument.Title.toLowerCase(), cdl);
        }

        // Define required documents
        docs.add(new DocumentStatus('Consent to Collect Medical Records', false, 'consent', attachedDocs));
        docs.add(new DocumentStatus('Script', opp.pstar__Script_Received__c, 'script', attachedDocs));
        docs.add(new DocumentStatus('ID', false, 'id', attachedDocs));
        docs.add(new DocumentStatus('Insurance Card', false, 'insurance', attachedDocs));

        return docs;
    }

    // ==================== FILE MANAGEMENT ====================

    @AuraEnabled
    public static List<Map<String, String>> getUploadedFiles(Id recordId) {
        List<Map<String, String>> files = new List<Map<String, String>>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileType,
                   ContentDocument.ContentSize, ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            Map<String, String> f = new Map<String, String>();
            f.put('documentId', cdl.ContentDocumentId);
            f.put('title', cdl.ContentDocument.Title);
            f.put('fileType', cdl.ContentDocument.FileType);
            f.put('createdDate', String.valueOf(cdl.ContentDocument.CreatedDate));
            files.add(f);
        }
        return files;
    }

    @AuraEnabled
    public static void deleteFile(Id documentId) {
        ContentDocument doc = [SELECT Id FROM ContentDocument WHERE Id = :documentId LIMIT 1];
        delete doc;
    }

    // ==================== REFERRAL AGING (#9) ====================

    /**
     * @description Get referrals with aging information
     * @return List of referrals with days since creation
     */
    @AuraEnabled(cacheable=true)
    public static List<ReferralAging> getReferralAging() {
        List<ReferralAging> results = new List<ReferralAging>();

        List<Opportunity> referrals = [
            SELECT Id, Name, StageName, pstar__Referral_Date__c, CreatedDate,
                   pstar__County__c, pstar__Service_Categories__c, Owner.Name,
                   pstar__Field_Representative__c, pstar__Field_Representative__r.Name
            FROM Opportunity
            WHERE IsClosed = false
            ORDER BY pstar__Referral_Date__c ASC NULLS LAST
            LIMIT 200
        ];

        for (Opportunity opp : referrals) {
            results.add(new ReferralAging(opp));
        }

        return results;
    }

    // ==================== AUTHORIZATION TIMELINE (#10) ====================

    /**
     * @description Get authorization timeline for a referral
     * @param referralId Opportunity Id
     * @return Authorization timeline data
     */
    @AuraEnabled(cacheable=true)
    public static AuthorizationTimeline getAuthorizationTimeline(Id referralId) {
        Opportunity opp = [
            SELECT Id, Name, pstar__MA_ID__c, pstar__Authorization_Status__c,
                   pstar__Authorization_Number__c, pstar__Authorization_End_Date__c,
                   pstar__Authorized_Hours__c, pstar__Eligibility_Verified__c,
                   pstar__Referral_Date__c, pstar__Admission_Date__c,
                   CreatedDate, LastModifiedDate
            FROM Opportunity
            WHERE Id = :referralId
            LIMIT 1
        ];

        return new AuthorizationTimeline(opp);
    }

    // ==================== ELIGIBILITY VERIFICATION (#11) ====================

    /**
     * @description Mark eligibility as verified
     * @param referralId Opportunity Id
     * @return Updated status
     */
    @AuraEnabled
    public static Boolean verifyEligibility(Id referralId) {
        Opportunity opp = new Opportunity(
            Id = referralId,
            pstar__Eligibility_Verified__c = true
        );
        update opp;
        return true;
    }

    // ==================== AUTH EXPIRATION ALERTS (#12) ====================

    /**
     * @description Get referrals with expiring authorizations
     * @return List of referrals with auth expiration info
     */
    @AuraEnabled(cacheable=true)
    public static List<AuthExpirationAlert> getExpiringAuthorizations() {
        List<AuthExpirationAlert> alerts = new List<AuthExpirationAlert>();

        Date today = Date.today();
        Date thirtyDaysOut = today.addDays(30);

        List<Opportunity> referrals = [
            SELECT Id, Name, pstar__MA_ID__c, pstar__Authorization_Number__c,
                   pstar__Authorization_End_Date__c, pstar__Authorized_Hours__c,
                   pstar__Field_Representative__c, pstar__Field_Representative__r.Name,
                   Owner.Name
            FROM Opportunity
            WHERE pstar__Authorization_End_Date__c != null
            AND pstar__Authorization_End_Date__c <= :thirtyDaysOut
            AND IsClosed = false
            ORDER BY pstar__Authorization_End_Date__c ASC
            LIMIT 100
        ];

        for (Opportunity opp : referrals) {
            alerts.add(new AuthExpirationAlert(opp, today));
        }

        return alerts;
    }

    // ==================== HOURS UTILIZATION (#13) ====================

    /**
     * @description Get hours utilization for a referral
     * @param referralId Opportunity Id
     * @return Hours utilization data
     */
    @AuraEnabled(cacheable=true)
    public static HoursUtilization getHoursUtilization(Id referralId) {
        Opportunity opp = [
            SELECT Id, Name, pstar__Authorized_Hours__c, pstar__Authorization_End_Date__c,
                   pstar__Admission_Date__c, AccountId
            FROM Opportunity
            WHERE Id = :referralId
            LIMIT 1
        ];

        // Get completed service appointments for this referral's account
        Decimal usedHours = 0;
        if (opp.AccountId != null) {
            AggregateResult[] results = [
                SELECT SUM(Duration) totalMinutes
                FROM ServiceAppointment
                WHERE AccountId = :opp.AccountId
                AND Status = 'Completed'
                AND SchedStartTime >= :opp.pstar__Admission_Date__c
            ];

            if (results.size() > 0 && results[0].get('totalMinutes') != null) {
                Decimal totalMinutes = (Decimal)results[0].get('totalMinutes');
                usedHours = totalMinutes / 60;
            }
        }

        return new HoursUtilization(opp, usedHours);
    }

    // ==================== SPECIALIST MATCHING (#14) ====================

    /**
     * @description Get specialist recommendations for a referral
     * @param referralId Opportunity Id
     * @return List of matched specialists with scores
     */
    @AuraEnabled(cacheable=true)
    public static List<SpecialistMatch> getSpecialistMatches(Id referralId) {
        List<SpecialistMatch> matches = new List<SpecialistMatch>();

        Opportunity opp = [
            SELECT Id, pstar__County__c, pstar__Service_Categories__c,
                   pstar__Preferred_Location__c, pstar__Gender__c,
                   pstar__Street_Address__c, pstar__Address_City__c
            FROM Opportunity
            WHERE Id = :referralId
            LIMIT 1
        ];

        // Get active peer specialists (ServiceResources)
        List<ServiceResource> specialists = [
            SELECT Id, Name, RelatedRecordId, RelatedRecord.Name,
                   ServiceCrewId, ServiceCrew.Name
            FROM ServiceResource
            WHERE IsActive = true
            AND ResourceType = 'T'
            LIMIT 50
        ];

        // Get caseload counts for each specialist
        Map<Id, Integer> caseloadMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT pstar__Field_Representative__c specId, COUNT(Id) cnt
            FROM Opportunity
            WHERE pstar__Field_Representative__c != null
            AND IsClosed = false
            GROUP BY pstar__Field_Representative__c
        ]) {
            caseloadMap.put((Id)ar.get('specId'), (Integer)ar.get('cnt'));
        }

        for (ServiceResource sr : specialists) {
            Integer caseload = caseloadMap.containsKey(sr.RelatedRecordId) ?
                              caseloadMap.get(sr.RelatedRecordId) : 0;
            matches.add(new SpecialistMatch(sr, opp, caseload));
        }

        // Sort by match score descending
        matches.sort();

        return matches;
    }

    /**
     * @description Assign specialist to referral
     * @param referralId Opportunity Id
     * @param specialistUserId User Id of specialist
     * @return Success status
     */
    @AuraEnabled
    public static Boolean assignSpecialist(Id referralId, Id specialistUserId) {
        Opportunity opp = new Opportunity(
            Id = referralId,
            pstar__Field_Representative__c = specialistUserId
        );
        update opp;
        return true;
    }

    // ==================== IRP SCHEDULING (#15) ====================

    /**
     * @description Get available IRP slots for a specialist
     * @param specialistUserId User Id
     * @param targetDate Date to check
     * @return List of available time slots
     */
    @AuraEnabled(cacheable=true)
    public static List<IRPTimeSlot> getIRPAvailability(Id specialistUserId, Date targetDate) {
        List<IRPTimeSlot> slots = new List<IRPTimeSlot>();

        // Get specialist's service resource
        List<ServiceResource> resources = [
            SELECT Id FROM ServiceResource
            WHERE RelatedRecordId = :specialistUserId
            LIMIT 1
        ];

        if (resources.isEmpty()) {
            return slots;
        }

        Id resourceId = resources[0].Id;
        DateTime dayStart = DateTime.newInstance(targetDate, Time.newInstance(8, 0, 0, 0));
        DateTime dayEnd = DateTime.newInstance(targetDate, Time.newInstance(17, 0, 0, 0));

        // Get existing appointments for this day
        Set<DateTime> busyTimes = new Set<DateTime>();
        for (ServiceAppointment sa : [
            SELECT SchedStartTime, SchedEndTime
            FROM ServiceAppointment
            WHERE Id IN (SELECT ServiceAppointmentId FROM AssignedResource WHERE ServiceResourceId = :resourceId)
            AND SchedStartTime >= :dayStart
            AND SchedStartTime < :dayEnd
        ]) {
            busyTimes.add(sa.SchedStartTime);
        }

        // Generate 1-hour slots from 8am to 5pm
        DateTime slotTime = dayStart;
        while (slotTime < dayEnd) {
            Boolean isAvailable = !busyTimes.contains(slotTime);
            slots.add(new IRPTimeSlot(slotTime, 60, isAvailable));
            slotTime = slotTime.addHours(1);
        }

        return slots;
    }

    /**
     * @description Schedule IRP for a referral
     * @param referralId Opportunity Id
     * @param specialistUserId Specialist User Id
     * @param scheduledDateTime Scheduled date/time
     * @return Success status
     */
    @AuraEnabled
    public static Boolean scheduleIRP(Id referralId, Id specialistUserId, DateTime scheduledDateTime) {
        Opportunity opp = new Opportunity(
            Id = referralId,
            pstar__IRP_Specialist__c = specialistUserId,
            pstar__IRP_Scheduled_Date__c = scheduledDateTime
        );
        update opp;
        return true;
    }

    // ==================== WORKLOAD BALANCING (#16) ====================

    /**
     * @description Get workload distribution across specialists
     * @return List of specialist workloads
     */
    @AuraEnabled(cacheable=true)
    public static List<SpecialistWorkload> getWorkloadDistribution() {
        List<SpecialistWorkload> workloads = new List<SpecialistWorkload>();

        // Get all active specialists
        Map<Id, User> specialistUsers = new Map<Id, User>([
            SELECT Id, Name
            FROM User
            WHERE Id IN (SELECT RelatedRecordId FROM ServiceResource WHERE IsActive = true AND ResourceType = 'T')
        ]);

        // Get caseload counts
        Map<Id, Integer> caseloadMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT pstar__Field_Representative__c specId, COUNT(Id) cnt
            FROM Opportunity
            WHERE pstar__Field_Representative__c != null
            AND IsClosed = false
            GROUP BY pstar__Field_Representative__c
        ]) {
            caseloadMap.put((Id)ar.get('specId'), (Integer)ar.get('cnt'));
        }

        // Get new referrals assigned this week
        Date weekStart = Date.today().toStartOfWeek();
        Date weekEnd = weekStart.addDays(7);
        Map<Id, Integer> newThisWeekMap = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT pstar__Field_Representative__c specId, COUNT(Id) cnt
            FROM Opportunity
            WHERE pstar__Field_Representative__c != null
            AND CreatedDate >= :weekStart
            AND CreatedDate < :weekEnd
            GROUP BY pstar__Field_Representative__c
        ]) {
            newThisWeekMap.put((Id)ar.get('specId'), (Integer)ar.get('cnt'));
        }

        for (Id userId : specialistUsers.keySet()) {
            User u = specialistUsers.get(userId);
            Integer caseload = caseloadMap.containsKey(userId) ? caseloadMap.get(userId) : 0;
            Integer newThisWeek = newThisWeekMap.containsKey(userId) ? newThisWeekMap.get(userId) : 0;
            workloads.add(new SpecialistWorkload(u, caseload, newThisWeek));
        }

        // Sort by caseload descending
        workloads.sort();

        return workloads;
    }

    // ==================== CONVERSION FUNNEL (#17) ====================

    /**
     * @description Get conversion funnel metrics
     * @param startDate Start of date range
     * @param endDate End of date range
     * @return Funnel data
     */
    @AuraEnabled(cacheable=true)
    public static ConversionFunnel getConversionFunnel(Date startDate, Date endDate) {
        ConversionFunnel funnel = new ConversionFunnel();

        // Lead count
        funnel.totalLeads = [
            SELECT COUNT() FROM Lead
            WHERE CreatedDate >= :startDate AND CreatedDate <= :endDate
        ];

        // Converted leads (to referrals)
        funnel.convertedLeads = [
            SELECT COUNT() FROM Lead
            WHERE CreatedDate >= :startDate AND CreatedDate <= :endDate
            AND IsConverted = true
        ];

        // Total referrals
        funnel.totalReferrals = [
            SELECT COUNT() FROM Opportunity
            WHERE pstar__Referral_Date__c >= :startDate AND pstar__Referral_Date__c <= :endDate
        ];

        // Admitted (Closed Won)
        funnel.admittedReferrals = [
            SELECT COUNT() FROM Opportunity
            WHERE pstar__Referral_Date__c >= :startDate AND pstar__Referral_Date__c <= :endDate
            AND StageName = 'Closed Won'
        ];

        // Calculate conversion rates
        funnel.leadToReferralRate = funnel.totalLeads > 0 ?
            (funnel.convertedLeads * 100.0 / funnel.totalLeads) : 0;
        funnel.referralToAdmissionRate = funnel.totalReferrals > 0 ?
            (funnel.admittedReferrals * 100.0 / funnel.totalReferrals) : 0;
        funnel.overallConversionRate = funnel.totalLeads > 0 ?
            (funnel.admittedReferrals * 100.0 / funnel.totalLeads) : 0;

        return funnel;
    }

    // ==================== TIME-TO-ADMISSION (#18) ====================

    /**
     * @description Get time-to-admission metrics
     * @param startDate Start of date range
     * @param endDate End of date range
     * @return Time metrics
     */
    @AuraEnabled(cacheable=true)
    public static TimeToAdmissionMetrics getTimeToAdmissionMetrics(Date startDate, Date endDate) {
        TimeToAdmissionMetrics metrics = new TimeToAdmissionMetrics();

        List<Opportunity> admittedReferrals = [
            SELECT Id, pstar__Referral_Date__c, pstar__Admission_Date__c,
                   pstar__Days_to_Admission__c, pstar__Source_Type__c, Owner.Name
            FROM Opportunity
            WHERE pstar__Admission_Date__c >= :startDate
            AND pstar__Admission_Date__c <= :endDate
            AND pstar__Admission_Date__c != null
            AND pstar__Referral_Date__c != null
        ];

        if (admittedReferrals.isEmpty()) {
            return metrics;
        }

        Decimal totalDays = 0;
        Integer count = 0;
        Map<String, List<Decimal>> daysBySource = new Map<String, List<Decimal>>();
        Map<String, List<Decimal>> daysBySpecialist = new Map<String, List<Decimal>>();

        for (Opportunity opp : admittedReferrals) {
            Decimal days = opp.pstar__Days_to_Admission__c;
            if (days != null) {
                totalDays += days;
                count++;

                // Group by source
                String source = opp.pstar__Source_Type__c != null ? opp.pstar__Source_Type__c : 'Unknown';
                if (!daysBySource.containsKey(source)) {
                    daysBySource.put(source, new List<Decimal>());
                }
                daysBySource.get(source).add(days);

                // Group by intake specialist (owner)
                String specialist = opp.Owner.Name != null ? opp.Owner.Name : 'Unassigned';
                if (!daysBySpecialist.containsKey(specialist)) {
                    daysBySpecialist.put(specialist, new List<Decimal>());
                }
                daysBySpecialist.get(specialist).add(days);
            }
        }

        metrics.averageDays = count > 0 ? (totalDays / count).setScale(1) : 0;
        metrics.totalAdmissions = count;

        // Calculate by source
        metrics.bySource = new List<BreakdownMetric>();
        for (String source : daysBySource.keySet()) {
            List<Decimal> days = daysBySource.get(source);
            Decimal avg = 0;
            for (Decimal d : days) { avg += d; }
            avg = days.size() > 0 ? (avg / days.size()).setScale(1) : 0;
            metrics.bySource.add(new BreakdownMetric(source, avg, days.size()));
        }

        // Calculate by specialist
        metrics.bySpecialist = new List<BreakdownMetric>();
        for (String specialist : daysBySpecialist.keySet()) {
            List<Decimal> days = daysBySpecialist.get(specialist);
            Decimal avg = 0;
            for (Decimal d : days) { avg += d; }
            avg = days.size() > 0 ? (avg / days.size()).setScale(1) : 0;
            metrics.bySpecialist.add(new BreakdownMetric(specialist, avg, days.size()));
        }

        return metrics;
    }

    // ==================== REFERRAL SOURCE ROI (#19) ====================

    /**
     * @description Get referral source performance
     * @param startDate Start of date range
     * @param endDate End of date range
     * @return Source performance data
     */
    @AuraEnabled(cacheable=true)
    public static List<ReferralSourceMetric> getReferralSourceMetrics(Date startDate, Date endDate) {
        List<ReferralSourceMetric> sources = new List<ReferralSourceMetric>();

        // Get referrals grouped by source
        Map<String, Integer> totalBySource = new Map<String, Integer>();
        Map<String, Integer> admittedBySource = new Map<String, Integer>();

        for (AggregateResult ar : [
            SELECT pstar__Source_Type__c source, COUNT(Id) cnt
            FROM Opportunity
            WHERE pstar__Referral_Date__c >= :startDate AND pstar__Referral_Date__c <= :endDate
            GROUP BY pstar__Source_Type__c
        ]) {
            String source = ar.get('source') != null ? (String)ar.get('source') : 'Unknown';
            totalBySource.put(source, (Integer)ar.get('cnt'));
        }

        for (AggregateResult ar : [
            SELECT pstar__Source_Type__c source, COUNT(Id) cnt
            FROM Opportunity
            WHERE pstar__Referral_Date__c >= :startDate AND pstar__Referral_Date__c <= :endDate
            AND StageName = 'Closed Won'
            GROUP BY pstar__Source_Type__c
        ]) {
            String source = ar.get('source') != null ? (String)ar.get('source') : 'Unknown';
            admittedBySource.put(source, (Integer)ar.get('cnt'));
        }

        for (String source : totalBySource.keySet()) {
            Integer total = totalBySource.get(source);
            Integer admitted = admittedBySource.containsKey(source) ? admittedBySource.get(source) : 0;
            sources.add(new ReferralSourceMetric(source, total, admitted));
        }

        // Sort by total descending
        sources.sort();

        return sources;
    }

    // ==================== INTAKE STAFF PERFORMANCE (#20) ====================

    /**
     * @description Get intake staff performance metrics
     * @param startDate Start of date range
     * @param endDate End of date range
     * @return Staff performance data
     */
    @AuraEnabled(cacheable=true)
    public static List<StaffPerformance> getIntakeStaffPerformance(Date startDate, Date endDate) {
        List<StaffPerformance> performance = new List<StaffPerformance>();

        // Get referrals by owner
        Map<Id, Integer> totalByOwner = new Map<Id, Integer>();
        Map<Id, Integer> admittedByOwner = new Map<Id, Integer>();
        Map<Id, String> ownerNames = new Map<Id, String>();

        for (AggregateResult ar : [
            SELECT OwnerId, Owner.Name, COUNT(Id) cnt
            FROM Opportunity
            WHERE pstar__Referral_Date__c >= :startDate AND pstar__Referral_Date__c <= :endDate
            GROUP BY OwnerId, Owner.Name
        ]) {
            Id ownerId = (Id)ar.get('OwnerId');
            totalByOwner.put(ownerId, (Integer)ar.get('cnt'));
            ownerNames.put(ownerId, (String)ar.get('Name'));
        }

        for (AggregateResult ar : [
            SELECT OwnerId, COUNT(Id) cnt
            FROM Opportunity
            WHERE pstar__Referral_Date__c >= :startDate AND pstar__Referral_Date__c <= :endDate
            AND StageName = 'Closed Won'
            GROUP BY OwnerId
        ]) {
            admittedByOwner.put((Id)ar.get('OwnerId'), (Integer)ar.get('cnt'));
        }

        // Get average time to admission by owner
        Map<Id, Decimal> avgDaysByOwner = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT OwnerId, AVG(pstar__Days_to_Admission__c) avgDays
            FROM Opportunity
            WHERE pstar__Admission_Date__c >= :startDate AND pstar__Admission_Date__c <= :endDate
            AND pstar__Days_to_Admission__c != null
            GROUP BY OwnerId
        ]) {
            avgDaysByOwner.put((Id)ar.get('OwnerId'), (Decimal)ar.get('avgDays'));
        }

        for (Id ownerId : totalByOwner.keySet()) {
            Integer total = totalByOwner.get(ownerId);
            Integer admitted = admittedByOwner.containsKey(ownerId) ? admittedByOwner.get(ownerId) : 0;
            Decimal avgDays = avgDaysByOwner.containsKey(ownerId) ? avgDaysByOwner.get(ownerId) : null;
            String name = ownerNames.get(ownerId);
            performance.add(new StaffPerformance(ownerId, name, total, admitted, avgDays));
        }

        // Sort by admitted descending
        performance.sort();

        return performance;
    }

    // ==================== WRAPPER CLASSES ====================

    public class PipelineData {
        @AuraEnabled public List<String> stages;
        @AuraEnabled public Map<String, List<ReferralCard>> referralsByStage;
        @AuraEnabled public Map<String, Integer> stageCounts;
    }

    public class ReferralCard {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String stage;
        @AuraEnabled public Date referralDate;
        @AuraEnabled public String county;
        @AuraEnabled public String serviceType;
        @AuraEnabled public String maId;
        @AuraEnabled public String authStatus;
        @AuraEnabled public Boolean eligibilityVerified;
        @AuraEnabled public DateTime irpScheduledDate;
        @AuraEnabled public Boolean irpCompleted;
        @AuraEnabled public String specialistName;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String phone;
        @AuraEnabled public Integer daysOpen;
        @AuraEnabled public String urgencyClass;

        public ReferralCard(Opportunity opp) {
            this.id = opp.Id;
            this.name = opp.Name;
            this.stage = opp.StageName;
            this.referralDate = opp.pstar__Referral_Date__c;
            this.county = opp.pstar__County__c;
            this.serviceType = opp.pstar__Service_Categories__c;
            this.maId = opp.pstar__MA_ID__c;
            this.authStatus = opp.pstar__Authorization_Status__c;
            this.eligibilityVerified = opp.pstar__Eligibility_Verified__c;
            this.irpScheduledDate = opp.pstar__IRP_Scheduled_Date__c;
            this.irpCompleted = opp.pstar__IRP_Completed__c;
            this.specialistName = opp.pstar__Field_Representative__r?.Name;
            this.ownerName = opp.Owner?.Name;
            this.phone = opp.pstar__Mobile_Phone__c;

            Date refDate = opp.pstar__Referral_Date__c != null ? opp.pstar__Referral_Date__c : opp.CreatedDate.date();
            this.daysOpen = refDate.daysBetween(Date.today());

            // Set urgency class based on days open
            if (this.daysOpen > 14) {
                this.urgencyClass = 'slds-theme_error';
            } else if (this.daysOpen > 7) {
                this.urgencyClass = 'slds-theme_warning';
            } else {
                this.urgencyClass = 'slds-theme_success';
            }
        }
    }

    public class IntakeChecklist {
        @AuraEnabled public Id referralId;
        @AuraEnabled public String referralName;
        @AuraEnabled public List<ChecklistItem> items;
        @AuraEnabled public Integer completedCount;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Decimal completionPercentage;

        public IntakeChecklist(Opportunity opp) {
            this.referralId = opp.Id;
            this.referralName = opp.Name;
            this.items = new List<ChecklistItem>();

            // Demographics
            items.add(new ChecklistItem('Date of Birth', opp.pstar__DOB__c != null, 'Demographics'));
            items.add(new ChecklistItem('Gender', opp.pstar__Gender__c != null, 'Demographics'));
            items.add(new ChecklistItem('Race', opp.pstar__Race__c != null, 'Demographics'));
            items.add(new ChecklistItem('Ethnicity', opp.pstar__Ethnicity__c != null, 'Demographics'));

            // Contact Info
            items.add(new ChecklistItem('Phone Number', opp.pstar__Mobile_Phone__c != null, 'Contact'));
            items.add(new ChecklistItem('Email', opp.pstar__Email__c != null, 'Contact'));
            items.add(new ChecklistItem('Address', opp.pstar__Street_Address__c != null, 'Contact'));
            items.add(new ChecklistItem('City', opp.pstar__Address_City__c != null, 'Contact'));
            items.add(new ChecklistItem('State', opp.pstar__State__c != null, 'Contact'));
            items.add(new ChecklistItem('Zip Code', opp.pstar__Zip_Code__c != null, 'Contact'));

            // Insurance
            items.add(new ChecklistItem('MA ID', opp.pstar__MA_ID__c != null, 'Insurance'));
            items.add(new ChecklistItem('Eligibility Verified', opp.pstar__Eligibility_Verified__c == true, 'Insurance'));
            items.add(new ChecklistItem('Authorization', opp.pstar__Authorization_Number__c != null, 'Insurance'));

            // Clinical
            items.add(new ChecklistItem('Diagnosis', opp.pstar__Diagnosis_Intake__c != null, 'Clinical'));
            items.add(new ChecklistItem('Living Situation', opp.pstar__Living_Situation__c != null, 'Clinical'));
            items.add(new ChecklistItem('Service Type', opp.pstar__Service_Categories__c != null, 'Clinical'));
            items.add(new ChecklistItem('Script Received', opp.pstar__Script_Received__c == true, 'Clinical'));

            // Assignment
            items.add(new ChecklistItem('Peer Specialist Assigned', opp.pstar__Field_Representative__c != null, 'Assignment'));
            items.add(new ChecklistItem('IRP Scheduled', opp.pstar__IRP_Scheduled_Date__c != null, 'Assignment'));
            items.add(new ChecklistItem('IRP Completed', opp.pstar__IRP_Completed__c == true, 'Assignment'));

            // Calculate completion
            this.completedCount = 0;
            for (ChecklistItem item : items) {
                if (item.isComplete) completedCount++;
            }
            this.totalCount = items.size();
            this.completionPercentage = (completedCount * 100.0 / totalCount).setScale(0);
        }
    }

    public class ChecklistItem {
        @AuraEnabled public String label;
        @AuraEnabled public Boolean isComplete;
        @AuraEnabled public String category;
        @AuraEnabled public String iconName;

        public ChecklistItem(String label, Boolean isComplete, String category) {
            this.label = label;
            this.isComplete = isComplete;
            this.category = category;
            this.iconName = isComplete ? 'utility:check' : 'utility:close';
        }
    }

    public class DocumentStatus {
        @AuraEnabled public String documentName;
        @AuraEnabled public Boolean isReceived;
        @AuraEnabled public Boolean hasFile;
        @AuraEnabled public String fileName;
        @AuraEnabled public DateTime uploadedDate;
        @AuraEnabled public String uploadedBy;
        @AuraEnabled public String statusClass;

        public DocumentStatus(String name, Boolean fieldValue, String searchKey, Map<String, ContentDocumentLink> docs) {
            this.documentName = name;

            // Check if file is attached
            this.hasFile = false;
            for (String title : docs.keySet()) {
                if (title.contains(searchKey)) {
                    this.hasFile = true;
                    ContentDocumentLink cdl = docs.get(title);
                    this.fileName = cdl.ContentDocument.Title;
                    this.uploadedDate = cdl.ContentDocument.CreatedDate;
                    this.uploadedBy = cdl.ContentDocument.CreatedBy.Name;
                    break;
                }
            }

            this.isReceived = fieldValue || this.hasFile;
            this.statusClass = this.isReceived ? 'slds-theme_success' : 'slds-theme_shade';
        }
    }

    public class ReferralAging {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String stage;
        @AuraEnabled public Date referralDate;
        @AuraEnabled public Integer daysOpen;
        @AuraEnabled public String county;
        @AuraEnabled public String serviceType;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String specialistName;
        @AuraEnabled public String urgencyLevel;
        @AuraEnabled public String urgencyClass;

        public ReferralAging(Opportunity opp) {
            this.id = opp.Id;
            this.name = opp.Name;
            this.stage = opp.StageName;
            this.referralDate = opp.pstar__Referral_Date__c;
            this.county = opp.pstar__County__c;
            this.serviceType = opp.pstar__Service_Categories__c;
            this.ownerName = opp.Owner?.Name;
            this.specialistName = opp.pstar__Field_Representative__r?.Name;

            Date refDate = opp.pstar__Referral_Date__c != null ? opp.pstar__Referral_Date__c : opp.CreatedDate.date();
            this.daysOpen = refDate.daysBetween(Date.today());

            if (this.daysOpen > 14) {
                this.urgencyLevel = 'Critical';
                this.urgencyClass = 'slds-badge slds-theme_error';
            } else if (this.daysOpen > 7) {
                this.urgencyLevel = 'Warning';
                this.urgencyClass = 'slds-badge slds-theme_warning';
            } else {
                this.urgencyLevel = 'On Track';
                this.urgencyClass = 'slds-badge slds-theme_success';
            }
        }
    }

    public class AuthorizationTimeline {
        @AuraEnabled public Id referralId;
        @AuraEnabled public String maId;
        @AuraEnabled public String authStatus;
        @AuraEnabled public String authNumber;
        @AuraEnabled public Date authEndDate;
        @AuraEnabled public Decimal authorizedHours;
        @AuraEnabled public Boolean eligibilityVerified;
        @AuraEnabled public Integer daysUntilExpiration;
        @AuraEnabled public String expirationUrgency;
        @AuraEnabled public List<TimelineEvent> events;

        public AuthorizationTimeline(Opportunity opp) {
            this.referralId = opp.Id;
            this.maId = opp.pstar__MA_ID__c;
            this.authStatus = opp.pstar__Authorization_Status__c;
            this.authNumber = opp.pstar__Authorization_Number__c;
            this.authEndDate = opp.pstar__Authorization_End_Date__c;
            this.authorizedHours = opp.pstar__Authorized_Hours__c;
            this.eligibilityVerified = opp.pstar__Eligibility_Verified__c;

            // Calculate expiration
            if (this.authEndDate != null) {
                this.daysUntilExpiration = Date.today().daysBetween(this.authEndDate);
                if (this.daysUntilExpiration < 0) {
                    this.expirationUrgency = 'Expired';
                } else if (this.daysUntilExpiration <= 7) {
                    this.expirationUrgency = 'Critical';
                } else if (this.daysUntilExpiration <= 14) {
                    this.expirationUrgency = 'Warning';
                } else if (this.daysUntilExpiration <= 30) {
                    this.expirationUrgency = 'Upcoming';
                } else {
                    this.expirationUrgency = 'Active';
                }
            }

            // Build timeline events
            this.events = new List<TimelineEvent>();
            if (opp.pstar__Referral_Date__c != null) {
                events.add(new TimelineEvent('Referral Received', opp.pstar__Referral_Date__c, 'standard:opportunity'));
            }
            if (opp.pstar__Eligibility_Verified__c) {
                events.add(new TimelineEvent('Eligibility Verified', opp.LastModifiedDate.date(), 'standard:task2'));
            }
            if (opp.pstar__Authorization_Number__c != null) {
                events.add(new TimelineEvent('Authorization Approved', opp.LastModifiedDate.date(), 'standard:approval'));
            }
            if (opp.pstar__Admission_Date__c != null) {
                events.add(new TimelineEvent('Admitted', opp.pstar__Admission_Date__c, 'standard:user'));
            }
        }
    }

    public class TimelineEvent {
        @AuraEnabled public String label;
        @AuraEnabled public Date eventDate;
        @AuraEnabled public String iconName;

        public TimelineEvent(String label, Date eventDate, String iconName) {
            this.label = label;
            this.eventDate = eventDate;
            this.iconName = iconName;
        }
    }

    public class AuthExpirationAlert {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String maId;
        @AuraEnabled public String authNumber;
        @AuraEnabled public Date expirationDate;
        @AuraEnabled public Integer daysUntilExpiration;
        @AuraEnabled public Decimal authorizedHours;
        @AuraEnabled public String specialistName;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String urgencyLevel;
        @AuraEnabled public String urgencyClass;

        public AuthExpirationAlert(Opportunity opp, Date today) {
            this.id = opp.Id;
            this.name = opp.Name;
            this.maId = opp.pstar__MA_ID__c;
            this.authNumber = opp.pstar__Authorization_Number__c;
            this.expirationDate = opp.pstar__Authorization_End_Date__c;
            this.authorizedHours = opp.pstar__Authorized_Hours__c;
            this.specialistName = opp.pstar__Field_Representative__r?.Name;
            this.ownerName = opp.Owner?.Name;

            this.daysUntilExpiration = today.daysBetween(this.expirationDate);

            if (this.daysUntilExpiration < 0) {
                this.urgencyLevel = 'Expired';
                this.urgencyClass = 'slds-badge slds-theme_error';
            } else if (this.daysUntilExpiration <= 7) {
                this.urgencyLevel = 'Critical';
                this.urgencyClass = 'slds-badge slds-theme_error';
            } else if (this.daysUntilExpiration <= 14) {
                this.urgencyLevel = 'Warning';
                this.urgencyClass = 'slds-badge slds-theme_warning';
            } else {
                this.urgencyLevel = 'Upcoming';
                this.urgencyClass = 'slds-badge slds-theme_info';
            }
        }
    }

    public class HoursUtilization {
        @AuraEnabled public Id referralId;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal authorizedHours;
        @AuraEnabled public Decimal usedHours;
        @AuraEnabled public Decimal remainingHours;
        @AuraEnabled public Decimal utilizationPercentage;
        @AuraEnabled public Date authEndDate;
        @AuraEnabled public Integer daysRemaining;
        @AuraEnabled public Decimal projectedWeeklyUsage;
        @AuraEnabled public String utilizationStatus;

        public HoursUtilization(Opportunity opp, Decimal used) {
            this.referralId = opp.Id;
            this.name = opp.Name;
            this.authorizedHours = opp.pstar__Authorized_Hours__c != null ? opp.pstar__Authorized_Hours__c : 0;
            this.usedHours = used.setScale(1);
            this.remainingHours = (this.authorizedHours - this.usedHours).setScale(1);
            this.utilizationPercentage = this.authorizedHours > 0 ?
                (this.usedHours * 100 / this.authorizedHours).setScale(0) : 0;
            this.authEndDate = opp.pstar__Authorization_End_Date__c;

            if (this.authEndDate != null) {
                this.daysRemaining = Date.today().daysBetween(this.authEndDate);
                Integer weeksRemaining = Math.max(this.daysRemaining / 7, 1);
                this.projectedWeeklyUsage = (this.remainingHours / weeksRemaining).setScale(1);
            }

            if (this.utilizationPercentage >= 90) {
                this.utilizationStatus = 'Near Limit';
            } else if (this.utilizationPercentage >= 75) {
                this.utilizationStatus = 'On Track';
            } else if (this.utilizationPercentage >= 50) {
                this.utilizationStatus = 'Moderate';
            } else {
                this.utilizationStatus = 'Low Usage';
            }
        }
    }

    public class SpecialistMatch implements Comparable {
        @AuraEnabled public Id resourceId;
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public String crewName;
        @AuraEnabled public Integer caseload;
        @AuraEnabled public Integer matchScore;
        @AuraEnabled public String capacityStatus;

        public SpecialistMatch(ServiceResource sr, Opportunity opp, Integer caseload) {
            this.resourceId = sr.Id;
            this.userId = sr.RelatedRecordId;
            this.name = sr.RelatedRecord?.Name != null ? sr.RelatedRecord.Name : sr.Name;
            this.crewName = sr.ServiceCrew?.Name;
            this.caseload = caseload;

            // Calculate match score (simplified - could be enhanced with more factors)
            this.matchScore = 100;

            // Reduce score based on caseload
            this.matchScore -= Math.min(caseload * 5, 50);

            // Capacity status
            if (caseload < 10) {
                this.capacityStatus = 'Available';
            } else if (caseload < 20) {
                this.capacityStatus = 'Moderate';
            } else {
                this.capacityStatus = 'High';
            }
        }

        public Integer compareTo(Object other) {
            SpecialistMatch otherMatch = (SpecialistMatch)other;
            return otherMatch.matchScore - this.matchScore; // Descending
        }
    }

    public class IRPTimeSlot {
        @AuraEnabled public DateTime startTime;
        @AuraEnabled public String startTimeFormatted;
        @AuraEnabled public Integer durationMinutes;
        @AuraEnabled public Boolean isAvailable;

        public IRPTimeSlot(DateTime startTime, Integer durationMinutes, Boolean isAvailable) {
            this.startTime = startTime;
            this.startTimeFormatted = startTime.format('h:mm a');
            this.durationMinutes = durationMinutes;
            this.isAvailable = isAvailable;
        }
    }

    public class SpecialistWorkload implements Comparable {
        @AuraEnabled public Id userId;
        @AuraEnabled public String name;
        @AuraEnabled public Integer caseload;
        @AuraEnabled public Integer newThisWeek;
        @AuraEnabled public String capacityStatus;
        @AuraEnabled public Integer capacityPercentage;

        public SpecialistWorkload(User u, Integer caseload, Integer newThisWeek) {
            this.userId = u.Id;
            this.name = u.Name;
            this.caseload = caseload;
            this.newThisWeek = newThisWeek;

            // Assume max capacity of 25 cases
            this.capacityPercentage = Math.min((caseload * 100 / 25), 100);

            if (this.capacityPercentage < 60) {
                this.capacityStatus = 'Available';
            } else if (this.capacityPercentage < 80) {
                this.capacityStatus = 'Moderate';
            } else if (this.capacityPercentage < 100) {
                this.capacityStatus = 'Near Capacity';
            } else {
                this.capacityStatus = 'At Capacity';
            }
        }

        public Integer compareTo(Object other) {
            SpecialistWorkload otherWorkload = (SpecialistWorkload)other;
            return otherWorkload.caseload - this.caseload; // Descending
        }
    }

    public class ConversionFunnel {
        @AuraEnabled public Integer totalLeads = 0;
        @AuraEnabled public Integer convertedLeads = 0;
        @AuraEnabled public Integer totalReferrals = 0;
        @AuraEnabled public Integer admittedReferrals = 0;
        @AuraEnabled public Decimal leadToReferralRate = 0;
        @AuraEnabled public Decimal referralToAdmissionRate = 0;
        @AuraEnabled public Decimal overallConversionRate = 0;
    }

    public class TimeToAdmissionMetrics {
        @AuraEnabled public Decimal averageDays = 0;
        @AuraEnabled public Integer totalAdmissions = 0;
        @AuraEnabled public List<BreakdownMetric> bySource = new List<BreakdownMetric>();
        @AuraEnabled public List<BreakdownMetric> bySpecialist = new List<BreakdownMetric>();
    }

    public class BreakdownMetric {
        @AuraEnabled public String name;
        @AuraEnabled public Decimal averageDays;
        @AuraEnabled public Integer count;

        public BreakdownMetric(String name, Decimal avgDays, Integer count) {
            this.name = name;
            this.averageDays = avgDays;
            this.count = count;
        }
    }

    public class ReferralSourceMetric implements Comparable {
        @AuraEnabled public String source;
        @AuraEnabled public Integer totalReferrals;
        @AuraEnabled public Integer admittedReferrals;
        @AuraEnabled public Decimal conversionRate;

        public ReferralSourceMetric(String source, Integer total, Integer admitted) {
            this.source = source;
            this.totalReferrals = total;
            this.admittedReferrals = admitted;
            this.conversionRate = total > 0 ? (admitted * 100.0 / total).setScale(1) : 0;
        }

        public Integer compareTo(Object other) {
            ReferralSourceMetric otherMetric = (ReferralSourceMetric)other;
            return otherMetric.totalReferrals - this.totalReferrals; // Descending
        }
    }

    public class StaffPerformance implements Comparable {
        @AuraEnabled public Id staffId;
        @AuraEnabled public String staffName;
        @AuraEnabled public Integer totalReferrals;
        @AuraEnabled public Integer admittedReferrals;
        @AuraEnabled public Decimal conversionRate;
        @AuraEnabled public Decimal avgDaysToAdmission;

        public StaffPerformance(Id staffId, String name, Integer total, Integer admitted, Decimal avgDays) {
            this.staffId = staffId;
            this.staffName = name;
            this.totalReferrals = total;
            this.admittedReferrals = admitted;
            this.conversionRate = total > 0 ? (admitted * 100.0 / total).setScale(1) : 0;
            this.avgDaysToAdmission = avgDays != null ? avgDays.setScale(1) : null;
        }

        public Integer compareTo(Object other) {
            StaffPerformance otherPerf = (StaffPerformance)other;
            return otherPerf.admittedReferrals - this.admittedReferrals; // Descending
        }
    }
}