/**
 * Handler for Opportunity (Referral) trigger
 * DISABLED: Opp->PA sync no longer needed. All Credible data lives on Opportunity directly.
 */
public class OpportunityTriggerHandler {

    public static void syncToPatientAdmission(List<Opportunity> newRecords, Map<Id, Opportunity> oldMap) {
        // No-op: Opp->PA sync disabled - Opportunity is now the master for all Credible data
    }
}