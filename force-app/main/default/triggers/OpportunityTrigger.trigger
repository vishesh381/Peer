/**
 * Trigger on Opportunity (Referral) to sync patient details to Patient_Admission
 */
trigger OpportunityTrigger on Opportunity (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        OpportunityTriggerHandler.syncToPatientAdmission(Trigger.new, Trigger.oldMap);
    }
}