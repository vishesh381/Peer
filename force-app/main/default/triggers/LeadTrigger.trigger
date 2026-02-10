/**
 * Trigger on Lead to handle conversion to Opportunity
 * Creates Contact records for Peer (Patient) and Referring Person
 * Creates Patient_Admission and links everything to Opportunity
 */
trigger LeadTrigger on Lead (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        LeadTriggerHandler.handleLeadConversion(Trigger.new, Trigger.oldMap);
    }
}
