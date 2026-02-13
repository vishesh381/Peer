/*
------------------------------------------------------------------------------
 Class Name    : ProviderNpiMapService
 Developer     : Vishesh Sharma
 Created Date  : Feb 2026
 Description   :
 Queries pstar__Credible_Lookup__c for REFERRING PROVIDER records and parses
 the pstar__Credible_Value__c field into a Provider Name → NPI map.

 Value format example:
   "John Smith MD - NPI - 1871512376 - MA # - 0015160490001"

 Usage Context :
 • Called from credibleReferringAutoComplete LWC via @AuraEnabled(cacheable=true)
 • Returns Map<String, String> where key = provider name, value = NPI
------------------------------------------------------------------------------
*/
public with sharing class ProviderNpiMapService {

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getProviderNpiMap() {

        Map<String, String> result = new Map<String, String>();

        List<pstar__Credible_Lookup__c> records = [
            SELECT pstar__Credible_Value__c
            FROM pstar__Credible_Lookup__c
            WHERE pstar__Credible_Lookup_Items__c = 'REFERRING PROVIDER'
        ];

        for (pstar__Credible_Lookup__c rec : records) {
            String val = rec.pstar__Credible_Value__c;

            if (val != null && val.contains('NPI -')) {
                List<String> parts = val.split(' - ');

                if (parts.size() >= 3) {
                    String name = parts[0].trim();
                    String npi  = parts[2].trim();
                    result.put(name, npi);
                }
            }
        }

        return result;
    }
}
