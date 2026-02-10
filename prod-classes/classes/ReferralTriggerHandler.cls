public class ReferralTriggerHandler {
    
    public static Boolean isFirstRun = true; 
    public static void assignReferralOwners(List<ple__Referral__c> newReferrals) {
        List<User> intakeUsers = [SELECT Id, Name  FROM User WHERE UserRole.Name = 'PA Intake Admission' AND IsActive = TRUE];
        if (intakeUsers.isEmpty()){
            return;
        } 
		System.debug(intakeUsers);        
        Set<Id> intakeUserIds = new Set<Id>();
        Map<Id, Integer> userCaseload = new Map<Id, Integer>();
        
        for (User u : intakeUsers) {
            intakeUserIds.add(u.Id);
            userCaseload.put(u.Id, 0);
        }
        
        for (AggregateResult ar : [SELECT OwnerId, COUNT(Id) totalReferrals FROM ple__Referral__c WHERE OwnerId IN :intakeUserIds GROUP BY OwnerId]) {
            userCaseload.put((Id)ar.get('OwnerId'), (Integer)ar.get('totalReferrals'));
        }
        
        //  Build caseloadMap: caseload -> list of userIds
        Map<Integer, Set<Id>> caseloadMap = new Map<Integer, Set<Id>>();
        for (Id uId : userCaseload.keySet()) {
            Integer count = userCaseload.get(uId);
            if (!caseloadMap.containsKey(count)){
                caseloadMap.put(count, new Set<Id>());
            } 
            caseloadMap.get(count).add(uId);
        }
		System.debug('Before update : ' + caseloadMap);      
         List<ple__Referral__c> toUpdate = new List<ple__Referral__c>();

        for (ple__Referral__c ref : newReferrals) {
            List<Integer> counts = new List<Integer>(caseloadMap.keySet());
            counts.sort(); 
            Integer minCount = counts[0];
            List<Id> candidates = new List<Id>(caseloadMap.get(minCount));
            Id assignedUserId = candidates[0];
            
            ple__Referral__c r = new ple__Referral__c(Id = ref.Id, OwnerId = assignedUserId);
 			toUpdate.add(r);            
            // Update caseload
            Integer newCount = userCaseload.get(assignedUserId) + 1;
            userCaseload.put(assignedUserId, newCount);
            
            // Update caseloadMap
            candidates.remove(0);
            
            if (candidates.isEmpty()) {
                caseloadMap.remove(minCount);
            }else{
                caseloadMap.put(minCount,new Set<Id>(candidates));
            }
            
            if (!caseloadMap.containsKey(newCount)) {
                caseloadMap.put(newCount, new Set<Id>());
            }
            caseloadMap.get(newCount).add(assignedUserId);
            System.debug('After update' + caseloadMap);
        }
        
        if(!toUpdate.isEmpty()){
            update toUpdate; 
        }
        
        
    }
}