@isTest
public class MailingAddressControllerTest {
    
    @testSetup
    static void setupTestData() {
        List<ple__Zip_To_County_Mapping__c> testData = new List<ple__Zip_To_County_Mapping__c>();
        
        testData.add(new ple__Zip_To_County_Mapping__c(
            ple__Zip_Code__c = '10001',
            ple__County__c = 'New York'
        ));
        
        testData.add(new ple__Zip_To_County_Mapping__c(
            ple__Zip_Code__c = '10002',
            ple__County__c = 'New York'
        ));
        
        testData.add(new ple__Zip_To_County_Mapping__c(
            ple__Zip_Code__c = '20001',
            ple__County__c = 'Washington'
        ));
        
        insert testData;
    }
    
    @isTest
    static void testGetCountyCodeList() {
        Test.startTest();
        MailingAddressController.CountyWrapper result = MailingAddressController.getCountyCodeList();
        Test.stopTest();
        
        // Assertions
        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assertNotEquals(null, result.countyOptions, 'County Options should not be null');
        System.assertNotEquals(null, result.zipCountyMap, 'ZipCountyMap should not be null');
        
        // Verify county options (unique values only)
        Set<String> expectedCounties = new Set<String>{'New York', 'Washington'};
        Set<String> actualCounties = new Set<String>();
        for (MailingAddressController.SelectOption opt : result.countyOptions) {
            actualCounties.add(opt.value);
        }
        System.assertEquals(expectedCounties, actualCounties, 'County options should match expected unique values');
        
        // Verify zip → county mapping
        System.assertEquals('New York', result.zipCountyMap.get('10001'), 'Zip 10001 should map to New York');
        System.assertEquals('New York', result.zipCountyMap.get('10002'), 'Zip 10002 should map to New York');
        System.assertEquals('Washington', result.zipCountyMap.get('20001'), 'Zip 20001 should map to Washington');
    }
    
    @isTest
    static void testNoRecords() {
        // Delete all test data to simulate no records
        delete [SELECT Id FROM ple__Zip_To_County_Mapping__c];
        
        Test.startTest();
        MailingAddressController.CountyWrapper result = MailingAddressController.getCountyCodeList();
        Test.stopTest();
        
        // Assertions
        System.assertEquals(0, result.countyOptions.size(), 'County options should be empty');
        System.assertEquals(0, result.zipCountyMap.size(), 'ZipCountyMap should be empty');
    }
}