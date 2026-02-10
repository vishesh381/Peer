// Check synced records from Credible
System.debug('=== Checking Synced Records ===');

// Check Patient Admissions
Integer patientCount = [SELECT COUNT() FROM pstar__Patient_Admission__c WHERE pstar__Credible_ID__c != null];
System.debug('Patient Admissions with Credible ID: ' + patientCount);

// Check recent synced records
List<pstar__Patient_Admission__c> recentPatients = [
    SELECT Id, pstar__Credible_ID__c, pstar__Credible_Patient_First_Name__c, pstar__Credible_Patient_Last_Name__c, CreatedDate, LastModifiedDate
    FROM pstar__Patient_Admission__c
    WHERE pstar__Credible_ID__c != null
    ORDER BY LastModifiedDate DESC
    LIMIT 5
];
System.debug('Recent Patient Admissions:');
for (pstar__Patient_Admission__c pa : recentPatients) {
    System.debug('  - ' + pa.pstar__Credible_Patient_First_Name__c + ' ' + pa.pstar__Credible_Patient_Last_Name__c + ' (Credible ID: ' + pa.pstar__Credible_ID__c + ') - Modified: ' + pa.LastModifiedDate);
}

System.debug('=== Check Complete ===');
