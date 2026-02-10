/**
 * Handler for Patient_Admission__c trigger
 * DISABLED: PA<->Opp sync no longer needed. All Credible data lives on Opportunity directly.
 */
public class PatientAdmissionTriggerHandler {

    public static void syncToOpportunity(List<pstar__Patient_Admission__c> newRecords, Map<Id, pstar__Patient_Admission__c> oldMap) {
        // No-op: PA sync disabled - Opportunity is now the master for all Credible data
    }
}
