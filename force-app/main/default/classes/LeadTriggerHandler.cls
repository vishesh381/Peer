/**
 * Handler for Lead trigger
 * Handles Lead conversion to create:
 * - Contact for Peer (Patient)
 * - Contact for Referring Person
 * - OpportunityContactRoles for related list
 * - Links all to Opportunity
 * - Copies peer + referral fields to Opportunity
 */
public class LeadTriggerHandler {

    /**
     * Handle Lead conversion - creates Contacts and populates Opportunity fields
     * Uses the auto-created Contact from Lead conversion as Peer (Patient) Contact
     * Creates a NEW Contact for Referring Person
     */
    public static void handleLeadConversion(List<Lead> newLeads, Map<Id, Lead> oldMap) {
        // Find leads that were just converted
        List<Lead> convertedLeads = new List<Lead>();

        for (Lead lead : newLeads) {
            Lead oldLead = oldMap.get(lead.Id);
            // Check if lead was just converted (IsConverted changed from false to true)
            if (lead.IsConverted && !oldLead.IsConverted && lead.ConvertedOpportunityId != null) {
                convertedLeads.add(lead);
            }
        }

        if (convertedLeads.isEmpty()) {
            return;
        }

        // Maps for tracking contacts
        Map<Id, Id> leadToPeerContactIdMap = new Map<Id, Id>();
        Map<Id, Contact> leadToReferrerContactMap = new Map<Id, Contact>();

        // Update existing Peer Contacts (created by Lead conversion) and create new Referrer Contacts
        List<Contact> peerContactsToUpdate = new List<Contact>();
        List<Contact> referrerContactsToInsert = new List<Contact>();

        for (Lead lead : convertedLeads) {
            System.debug('Processing Lead conversion: ' + lead.Id);
            System.debug('ConvertedContactId: ' + lead.ConvertedContactId);
            System.debug('ConvertedOpportunityId: ' + lead.ConvertedOpportunityId);

            // Use the auto-created Contact from Lead conversion as Peer (Patient) Contact
            // Just update it with our custom fields
            if (lead.ConvertedContactId != null) {
                Contact peerContact = new Contact(Id = lead.ConvertedContactId);
                peerContact.pstar__Referral__c = lead.ConvertedOpportunityId;
                peerContact.pstar__Contact_Type__c = 'Patient';
                peerContact.Phone = lead.pstar__Peers_Phone_Number__c;
                peerContact.MobilePhone = lead.pstar__Peers_Phone_Number__c;
                peerContact.Birthdate = lead.pstar__Date_of_Birth__c;
                peerContactsToUpdate.add(peerContact);
                leadToPeerContactIdMap.put(lead.Id, lead.ConvertedContactId);
                System.debug('Will update Peer Contact: ' + lead.ConvertedContactId);
            }

            // ALWAYS create NEW Referring Person Contact - linked to Opportunity via pstar__Referral__c
            Contact referrerContact = createReferrerContact(lead);
            referrerContact.pstar__Referral__c = lead.ConvertedOpportunityId;
            // Link to the same Account as the Peer Contact
            referrerContact.AccountId = lead.ConvertedAccountId;
            referrerContactsToInsert.add(referrerContact);
            leadToReferrerContactMap.put(lead.Id, referrerContact);

            System.debug('Creating Referrer Contact for Lead: ' + lead.Id);
        }

        // Update Peer Contacts with custom fields
        if (!peerContactsToUpdate.isEmpty()) {
            List<Database.SaveResult> updateResults = Database.update(peerContactsToUpdate, false);
            for (Integer i = 0; i < updateResults.size(); i++) {
                if (!updateResults[i].isSuccess()) {
                    System.debug('Peer Contact update failed: ' + updateResults[i].getErrors());
                } else {
                    System.debug('Peer Contact updated successfully: ' + updateResults[i].getId());
                }
            }
        }

        // Insert Referrer Contacts
        if (!referrerContactsToInsert.isEmpty()) {
            List<Database.SaveResult> insertResults = Database.insert(referrerContactsToInsert, false);
            for (Integer i = 0; i < insertResults.size(); i++) {
                if (!insertResults[i].isSuccess()) {
                    System.debug('Referrer Contact insert failed: ' + insertResults[i].getErrors());
                } else {
                    System.debug('Referrer Contact inserted successfully: ' + insertResults[i].getId());
                }
            }
        }

        // Update Opportunities with Contact links and peer/referral fields
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (Lead lead : convertedLeads) {
            Opportunity opp = new Opportunity(Id = lead.ConvertedOpportunityId);

            // Link Peer (Patient) Contact - use the converted Contact from Lead
            Id peerContactId = leadToPeerContactIdMap.get(lead.Id);
            if (peerContactId != null) {
                opp.pstar__Patient__c = peerContactId;
            }

            // Link Referring Person Contact - the newly created one
            Contact referrerContact = leadToReferrerContactMap.get(lead.Id);
            if (referrerContact != null && referrerContact.Id != null) {
                opp.pstar__Referring_Person__c = referrerContact.Id;
            }

            // Link to Lead for Name formula field (pstar__Name__c references pstar__Peer_Lead__r)
            opp.pstar__Peer_Lead__c = lead.Id;

            // Copy Peer (Patient) name fields to Opportunity
            opp.pstar__Patient_First_Name__c = lead.FirstName;
            opp.pstar__Patient_Last_Name__c = String.isNotBlank(lead.LastName) ? lead.LastName : 'Unknown';

            // Copy Peer (Patient) fields from Lead to Opportunity
            opp.pstar__DOB__c = lead.pstar__Date_of_Birth__c;
            opp.pstar__Mobile_Phone__c = lead.pstar__Peers_Phone_Number__c;
            opp.pstar__Home_Phone__c = lead.Phone;
            opp.pstar__Email__c = lead.Email;
            opp.pstar__County__c = lead.pstar__County__c;

            // Copy Peer address fields from Lead
            opp.pstar__Street_Address__c = lead.Street;
            opp.pstar__Address_City__c = lead.City;
            opp.pstar__State__c = lead.State;
            opp.pstar__Zip_Code__c = lead.PostalCode;

            // Copy Referral fields from Lead to Opportunity
            opp.pstar__Referral_Date__c = lead.pstar__Date__c;
            opp.pstar__Relationship_to_Peer__c = getReferrerRelationship(lead);
            opp.pstar__Referral_Phone__c = getReferrerPhone(lead);
            opp.pstar__Referred_By__c = getReferrerName(lead);

            opportunitiesToUpdate.add(opp);
        }

        // Update Opportunities
        if (!opportunitiesToUpdate.isEmpty()) {
            Database.update(opportunitiesToUpdate, false);
        }

        // Create OpportunityContactRoles for the Related Contacts list
        createContactRoles(convertedLeads, leadToPeerContactIdMap, leadToReferrerContactMap);
    }

    /**
     * Create OpportunityContactRole records so Contacts appear in Related Contacts list
     */
    private static void createContactRoles(List<Lead> convertedLeads, Map<Id, Id> peerIdMap, Map<Id, Contact> referrerMap) {
        List<OpportunityContactRole> rolesToInsert = new List<OpportunityContactRole>();

        for (Lead lead : convertedLeads) {
            // Add Peer Contact role
            Id peerContactId = peerIdMap.get(lead.Id);
            if (peerContactId != null) {
                OpportunityContactRole peerRole = new OpportunityContactRole();
                peerRole.OpportunityId = lead.ConvertedOpportunityId;
                peerRole.ContactId = peerContactId;
                peerRole.Role = 'Patient';
                peerRole.IsPrimary = true;
                rolesToInsert.add(peerRole);
            }

            // Add Referrer Contact role
            Contact referrerContact = referrerMap.get(lead.Id);
            if (referrerContact != null && referrerContact.Id != null) {
                OpportunityContactRole referrerRole = new OpportunityContactRole();
                referrerRole.OpportunityId = lead.ConvertedOpportunityId;
                referrerRole.ContactId = referrerContact.Id;
                referrerRole.Role = 'Referral Source';
                referrerRole.IsPrimary = false;
                rolesToInsert.add(referrerRole);
            }
        }

        if (!rolesToInsert.isEmpty()) {
            List<Database.SaveResult> results = Database.insert(rolesToInsert, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug('ContactRole insert failed: ' + results[i].getErrors());
                }
            }
        }
    }

    /**
     * Create Peer (Patient) Contact from Lead data
     */
    private static Contact createPeerContact(Lead lead) {
        Contact peerContact = new Contact();
        peerContact.FirstName = lead.FirstName;
        peerContact.LastName = String.isNotBlank(lead.LastName) ? lead.LastName : 'Unknown';
        peerContact.Phone = lead.pstar__Peers_Phone_Number__c;
        peerContact.MobilePhone = lead.pstar__Peers_Phone_Number__c;
        peerContact.Email = lead.Email;
        peerContact.Birthdate = lead.pstar__Date_of_Birth__c;
        peerContact.MailingStreet = lead.Street;
        peerContact.MailingCity = lead.City;
        peerContact.MailingState = lead.State;
        peerContact.MailingPostalCode = lead.PostalCode;
        peerContact.MailingCountry = lead.Country;
        peerContact.pstar__Contact_Type__c = 'Patient';

        return peerContact;
    }

    /**
     * Create Referring Person Contact from Lead data
     * Checks both pstar__ prefixed and non-prefixed fields
     */
    private static Contact createReferrerContact(Lead lead) {
        Contact referrerContact = new Contact();

        // Get name from either field version
        String fullName = getReferrerName(lead);
        if (String.isNotBlank(fullName)) {
            List<String> nameParts = fullName.trim().split('\\s+', 2);
            if (nameParts.size() >= 2) {
                referrerContact.FirstName = nameParts[0];
                referrerContact.LastName = nameParts[1];
            } else {
                referrerContact.LastName = nameParts[0];
            }
        } else {
            referrerContact.LastName = 'Unknown Referrer';
        }

        referrerContact.Phone = getReferrerPhone(lead);
        referrerContact.Email = getReferrerEmail(lead);
        referrerContact.pstar__Contact_Type__c = 'Referral Source';

        return referrerContact;
    }

    /**
     * Check if Lead has any Referring Person information
     * Checks both pstar__ prefixed and non-prefixed fields
     */
    private static Boolean hasReferrerInfo(Lead lead) {
        return String.isNotBlank(getReferrerName(lead)) ||
               String.isNotBlank(getReferrerPhone(lead)) ||
               String.isNotBlank(getReferrerEmail(lead));
    }

    /**
     * Get referrer name from either field version
     */
    private static String getReferrerName(Lead lead) {
        if (String.isNotBlank(lead.pstar__Referring_Person_Name__c)) {
            return lead.pstar__Referring_Person_Name__c;
        }
        return lead.Referring_Person_Name__c;
    }

    /**
     * Get referrer phone from either field version
     */
    private static String getReferrerPhone(Lead lead) {
        if (String.isNotBlank(lead.pstar__Referring_Person_Phone__c)) {
            return lead.pstar__Referring_Person_Phone__c;
        }
        return lead.Referring_Person_Phone__c;
    }

    /**
     * Get referrer email from either field version
     */
    private static String getReferrerEmail(Lead lead) {
        if (String.isNotBlank(lead.pstar__Referring_Persons_Email__c)) {
            return lead.pstar__Referring_Persons_Email__c;
        }
        return lead.Referring_Persons_Email__c;
    }

    /**
     * Get referrer relationship from either field version
     */
    private static String getReferrerRelationship(Lead lead) {
        if (String.isNotBlank(lead.pstar__Relationship_to_Peer__c)) {
            return lead.pstar__Relationship_to_Peer__c;
        }
        return lead.Relationship_to_Peer__c;
    }
}
