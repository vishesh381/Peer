/**
 * @description Controller for the Executive Command Center dashboard
 *              Provides high-level KPIs and metrics for leadership visibility
 *              into the entire referral-to-admission pipeline.
 *
 * Security: Uses 'with sharing' to enforce sharing rules.
 */
public with sharing class ExecutiveDashboardController {

    /**
     * @description Get all executive dashboard metrics in a single call
     * @return Executive dashboard data object
     */
    @AuraEnabled(cacheable=true)
    public static ExecutiveDashboardData getDashboardData() {
        ExecutiveDashboardData dashboard = new ExecutiveDashboardData();
        Date today = Date.today();
        Date thirtyDaysAgo = today.addDays(-30);
        Date sevenDaysAgo = today.addDays(-7);

        // ===== PIPELINE METRICS =====
        // Active referrals by stage
        Map<String, Integer> pipelineByStage = new Map<String, Integer>();
        for (AggregateResult ar : [
            SELECT StageName, COUNT(Id) cnt
            FROM Opportunity
            WHERE IsClosed = false
            GROUP BY StageName
        ]) {
            pipelineByStage.put((String)ar.get('StageName'), (Integer)ar.get('cnt'));
        }
        dashboard.pipelineByStage = pipelineByStage;

        // Total active referrals
        dashboard.totalActiveReferrals = 0;
        for (Integer cnt : pipelineByStage.values()) {
            dashboard.totalActiveReferrals += cnt;
        }

        // ===== CONVERSION METRICS (30-day) =====
        dashboard.newReferralsThisMonth = [
            SELECT COUNT() FROM Opportunity
            WHERE pstar__Referral_Date__c >= :thirtyDaysAgo
        ];

        dashboard.admissionsThisMonth = [
            SELECT COUNT() FROM Opportunity
            WHERE StageName = 'Closed Won'
            AND pstar__Admission_Date__c >= :thirtyDaysAgo
        ];

        dashboard.conversionRate = dashboard.newReferralsThisMonth > 0
            ? (dashboard.admissionsThisMonth * 100.0 / dashboard.newReferralsThisMonth).setScale(1)
            : 0;

        // ===== TODAY'S ACTIVITY =====
        DateTime todayStart = DateTime.newInstance(today, Time.newInstance(0, 0, 0, 0));
        DateTime todayEnd = DateTime.newInstance(today.addDays(1), Time.newInstance(0, 0, 0, 0));

        dashboard.visitsScheduledToday = [
            SELECT COUNT() FROM ServiceAppointment
            WHERE SchedStartTime >= :todayStart
            AND SchedStartTime < :todayEnd
        ];

        dashboard.visitsCompletedToday = [
            SELECT COUNT() FROM ServiceAppointment
            WHERE SchedStartTime >= :todayStart
            AND SchedStartTime < :todayEnd
            AND Status = 'Completed'
        ];

        // ===== CRITICAL ALERTS =====
        // Expiring authorizations (next 14 days)
        Date fourteenDaysOut = today.addDays(14);
        dashboard.expiringAuthsCount = [
            SELECT COUNT() FROM Opportunity
            WHERE pstar__Authorization_End_Date__c <= :fourteenDaysOut
            AND pstar__Authorization_End_Date__c >= :today
            AND IsClosed = false
        ];

        // Overdue visits (scheduled in past, not completed)
        dashboard.overdueVisitsCount = [
            SELECT COUNT() FROM ServiceAppointment
            WHERE SchedStartTime < :todayStart
            AND Status NOT IN ('Completed', 'Canceled', 'Cannot Complete')
        ];

        // Referrals aging > 14 days
        Date fourteenDaysAgo = today.addDays(-14);
        dashboard.criticalAgingCount = [
            SELECT COUNT() FROM Opportunity
            WHERE IsClosed = false
            AND (pstar__Referral_Date__c <= :fourteenDaysAgo OR
                 (pstar__Referral_Date__c = null AND CreatedDate <= :fourteenDaysAgo))
        ];

        // IRP follow-ups due this week
        Date weekEnd = today.addDays(7);
        dashboard.irpFollowUpsDue = [
            SELECT COUNT() FROM Case
            WHERE pstar__Follow_Up_IRP_Due__c <= :weekEnd
            AND pstar__Follow_Up_IRP_Due__c >= :today
            AND pstar__Follow_Up_IRP_Completed__c = false
            AND Status != 'Closed'
        ];

        dashboard.totalAlerts = dashboard.expiringAuthsCount + dashboard.overdueVisitsCount +
                               dashboard.criticalAgingCount + dashboard.irpFollowUpsDue;

        // ===== TEAM CAPACITY =====
        List<ServiceResource> activeSpecialists = [
            SELECT Id, RelatedRecordId, Name
            FROM ServiceResource
            WHERE IsActive = true
            AND ResourceType = 'T'
        ];
        dashboard.activeSpecialistsCount = activeSpecialists.size();

        Set<Id> specialistUserIds = new Set<Id>();
        for (ServiceResource sr : activeSpecialists) {
            specialistUserIds.add(sr.RelatedRecordId);
        }

        // Get caseload per specialist
        Map<Id, Integer> caseloadMap = new Map<Id, Integer>();
        if (!specialistUserIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT pstar__Peer_Specialist__c specId, COUNT(Id) cnt
                FROM Case
                WHERE pstar__Peer_Specialist__c IN :specialistUserIds
                AND Status != 'Closed'
                GROUP BY pstar__Peer_Specialist__c
            ]) {
                caseloadMap.put((Id)ar.get('specId'), (Integer)ar.get('cnt'));
            }
        }

        Integer totalCaseload = 0;
        Integer atCapacityCount = 0;
        for (Id userId : specialistUserIds) {
            Integer caseload = caseloadMap.containsKey(userId) ? caseloadMap.get(userId) : 0;
            totalCaseload += caseload;
            if (caseload >= 20) {
                atCapacityCount++;
            }
        }

        dashboard.totalActiveCases = totalCaseload;
        dashboard.avgCaseloadPerSpecialist = dashboard.activeSpecialistsCount > 0
            ? (totalCaseload * 1.0 / dashboard.activeSpecialistsCount).setScale(1)
            : 0;
        dashboard.specialistsAtCapacity = atCapacityCount;

        // ===== TREND DATA (last 7 days) =====
        dashboard.dailyAdmissions = new List<DailyMetric>();
        for (Integer i = 6; i >= 0; i--) {
            Date targetDate = today.addDays(-i);
            dashboard.dailyAdmissions.add(new DailyMetric(targetDate, 0));
        }

        for (AggregateResult ar : [
            SELECT pstar__Admission_Date__c admDate, COUNT(Id) cnt
            FROM Opportunity
            WHERE pstar__Admission_Date__c >= :sevenDaysAgo
            AND pstar__Admission_Date__c <= :today
            GROUP BY pstar__Admission_Date__c
        ]) {
            Date admDate = (Date)ar.get('admDate');
            Integer cnt = (Integer)ar.get('cnt');
            for (DailyMetric dm : dashboard.dailyAdmissions) {
                if (dm.metricDate == admDate) {
                    dm.value = cnt;
                    break;
                }
            }
        }

        // ===== TOP PERFORMERS (this month) =====
        dashboard.topPerformers = new List<PerformerMetric>();
        for (AggregateResult ar : [
            SELECT Owner.Name ownerName, COUNT(Id) cnt
            FROM Opportunity
            WHERE StageName = 'Closed Won'
            AND pstar__Admission_Date__c >= :thirtyDaysAgo
            GROUP BY Owner.Name
            ORDER BY COUNT(Id) DESC
            LIMIT 5
        ]) {
            dashboard.topPerformers.add(new PerformerMetric(
                (String)ar.get('ownerName'),
                (Integer)ar.get('cnt')
            ));
        }

        // ===== SOURCE PERFORMANCE =====
        dashboard.referralsBySource = new List<SourceMetric>();
        for (AggregateResult ar : [
            SELECT pstar__Source_Type__c source, COUNT(Id) cnt
            FROM Opportunity
            WHERE pstar__Referral_Date__c >= :thirtyDaysAgo
            GROUP BY pstar__Source_Type__c
            ORDER BY COUNT(Id) DESC
            LIMIT 5
        ]) {
            String source = ar.get('source') != null ? (String)ar.get('source') : 'Unknown';
            dashboard.referralsBySource.add(new SourceMetric(source, (Integer)ar.get('cnt')));
        }

        return dashboard;
    }

    // ==================== WRAPPER CLASSES ====================

    public class ExecutiveDashboardData {
        // Pipeline
        @AuraEnabled public Integer totalActiveReferrals = 0;
        @AuraEnabled public Map<String, Integer> pipelineByStage;

        // Conversions
        @AuraEnabled public Integer newReferralsThisMonth = 0;
        @AuraEnabled public Integer admissionsThisMonth = 0;
        @AuraEnabled public Decimal conversionRate = 0;

        // Today's Activity
        @AuraEnabled public Integer visitsScheduledToday = 0;
        @AuraEnabled public Integer visitsCompletedToday = 0;

        // Alerts
        @AuraEnabled public Integer expiringAuthsCount = 0;
        @AuraEnabled public Integer overdueVisitsCount = 0;
        @AuraEnabled public Integer criticalAgingCount = 0;
        @AuraEnabled public Integer irpFollowUpsDue = 0;
        @AuraEnabled public Integer totalAlerts = 0;

        // Team Capacity
        @AuraEnabled public Integer activeSpecialistsCount = 0;
        @AuraEnabled public Integer totalActiveCases = 0;
        @AuraEnabled public Decimal avgCaseloadPerSpecialist = 0;
        @AuraEnabled public Integer specialistsAtCapacity = 0;

        // Trends
        @AuraEnabled public List<DailyMetric> dailyAdmissions;
        @AuraEnabled public List<PerformerMetric> topPerformers;
        @AuraEnabled public List<SourceMetric> referralsBySource;
    }

    public class DailyMetric {
        @AuraEnabled public Date metricDate;
        @AuraEnabled public String dayLabel;
        @AuraEnabled public Integer value;

        public DailyMetric(Date d, Integer v) {
            this.metricDate = d;
            this.dayLabel = DateTime.newInstance(d, Time.newInstance(0,0,0,0)).format('EEE');
            this.value = v;
        }
    }

    public class PerformerMetric {
        @AuraEnabled public String name;
        @AuraEnabled public Integer admissions;

        public PerformerMetric(String name, Integer admissions) {
            this.name = name;
            this.admissions = admissions;
        }
    }

    public class SourceMetric {
        @AuraEnabled public String source;
        @AuraEnabled public Integer count;

        public SourceMetric(String source, Integer count) {
            this.source = source;
            this.count = count;
        }
    }
}