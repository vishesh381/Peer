// Check the data model and relationships

// 1. Check if Referral object exists
System.debug('=== Checking Data Model ===');

// Check Patient Admission relationships
List<pstar__Patient_Admission__c> admissions = [
    SELECT Id, Name, pstar__Credible_ID__c, pstar__Patient__c, pstar__Patient__r.Name
    FROM pstar__Patient_Admission__c
    WHERE pstar__Credible_ID__c != null
    LIMIT 5
];
System.debug('Patient Admissions with Credible ID: ' + admissions.size());
for (pstar__Patient_Admission__c pa : admissions) {
    System.debug('  PA: ' + pa.Name + ' -> Patient Contact: ' + pa.pstar__Patient__r.Name);
}

// Check Contacts with Patient type
List<Contact> patients = [
    SELECT Id, Name, pstar__Contact_Type__c, pstar__Credible_Profile_ID__c
    FROM Contact
    WHERE pstar__Contact_Type__c = 'Patient'
    LIMIT 5
];
System.debug('Contacts with Patient type: ' + patients.size());
for (Contact c : patients) {
    System.debug('  Contact: ' + c.Name + ' (Credible ID: ' + c.pstar__Credible_Profile_ID__c + ')');
}

// Check if there's a Case with referral-like fields
List<Case> cases = [
    SELECT Id, CaseNumber, ContactId, Contact.Name, Subject
    FROM Case
    LIMIT 5
];
System.debug('Cases: ' + cases.size());
for (Case c : cases) {
    System.debug('  Case: ' + c.CaseNumber + ' -> Contact: ' + c.Contact.Name);
}

System.debug('=== Check Complete ===');
