public class MailingAddressController {
    public class CountyWrapper {
        @AuraEnabled public List<SelectOption> countyOptions { get; set; }
        @AuraEnabled public Map<String, String> zipCountyMap { get; set; }
    }

    public class SelectOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        
        public SelectOption(String l, String v) {
            label = l;
            value = v;
        }
    }

    @AuraEnabled(cacheable=true)
    public static CountyWrapper getCountyCodeList() {
        CountyWrapper wrapper = new CountyWrapper();
        wrapper.countyOptions = new List<SelectOption>();
        wrapper.zipCountyMap = new Map<String, String>();
        Set<String> uniqueCounties = new Set<String>();

        for (ple__Zip_To_County_Mapping__c rec : [
            SELECT ple__Zip_Code__c, ple__County__c 
            FROM ple__Zip_To_County_Mapping__c 
            WHERE ple__Zip_Code__c != null 
            AND ple__County__c != null Order by ple__County__c LIMIT 50000 
        ]) {
            // Build zip → county map
            wrapper.zipCountyMap.put(rec.ple__Zip_Code__c, rec.ple__County__c);

            // Add county option only once
            if (!uniqueCounties.contains(rec.ple__County__c)) {
                wrapper.countyOptions.add(
                    new SelectOption(rec.ple__County__c, rec.ple__County__c)
                );
                uniqueCounties.add(rec.ple__County__c);
            }
        }

        return wrapper;
    }
}