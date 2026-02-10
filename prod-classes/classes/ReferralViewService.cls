public with sharing class ReferralViewService {

    @AuraEnabled
    public static Boolean markViewed(Id referralId) {
        if (referralId == null) return false;

        ple__Referral__c r = [
            SELECT Id, OwnerId, CreatedDate, ple__Stage__c
            FROM ple__Referral__c
            WHERE Id = :referralId
            LIMIT 1
        ];

        Date today = Date.today();

        // Conditions:
        // 1. User is owner
        // 2. Stage is exactly Assigned (means not viewed before)
        if (r.OwnerId == UserInfo.getUserId() &&
            r.ple__Stage__c == 'Assigned') {

            r.ple__Stage__c = 'Open Lead';

            update r;
            return true;
        }

        return false;
    }
}