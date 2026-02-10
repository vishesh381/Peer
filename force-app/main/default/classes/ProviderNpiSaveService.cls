/*
------------------------------------------------------------------------------
 Class Name    : ProviderNpiSaveService
 Developer     : Vishesh Sharma
 Created Date  : Jan 2026
 Description   :
 This Apex service class is used to persist Referring Provider information 
 captured through a custom Lightning Web Component (LWC) invoked via a Screen Flow / Quick Action on the Opportunity (Referrals) record.
 Usage Context :
 • Called from LWC using @AuraEnabled
 • LWC is embedded inside a Screen Flow launched from an Opportunity Quick Action
------------------------------------------------------------------------------
*/

public with sharing class ProviderNpiSaveService {
    @AuraEnabled
    public static Opportunity saveProviderNpi(Id oppId, String providerValue, String npiValue) {
        if (oppId == null) throw new AuraHandledException('Missing Opportunity Id.');
        if (String.isBlank(providerValue) || String.isBlank(npiValue)) {
            throw new AuraHandledException('Provider and NPI are required.');
        }

        Opportunity o = [
            SELECT Id, pstar__Referring_Provider__c, pstar__Referring_NPI__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        o.pstar__Referring_Provider__c = providerValue.trim();
        o.pstar__Referring_NPI__c      = npiValue.trim();
        update o;

        // Re-query after update
        return [
            SELECT Id, pstar__Referring_Provider__c, pstar__Referring_NPI__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
    }
}