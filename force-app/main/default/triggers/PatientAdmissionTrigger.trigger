/**
 * Trigger on Patient_Admission__c to sync Credible data back to related Opportunity (Referral)
 */
trigger PatientAdmissionTrigger on pstar__Patient_Admission__c (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        PatientAdmissionTriggerHandler.syncToOpportunity(Trigger.new, Trigger.oldMap);
    }
}
