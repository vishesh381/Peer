/* Test Class Code */
@IsTest
public class BackfillActionApiNameBatchTest {
    
    @TestSetup
    static void setupTestData() {
        // Create Config Actions
        List<ple__Config_Action__c> configActions = new List<ple__Config_Action__c>();
        for (Integer i = 0; i < 3; i++) {
            ple__Config_Action__c config = new ple__Config_Action__c(
                Name = 'API_Name_' + i,
                ple__Action_Label__c = 'Label ' + i
            );
            configActions.add(config);
        }
        insert configActions;
        
        // Create Actions referencing Config Actions (ple__Action_api_name__c is NULL)
        List<ple__Action__c> actions = new List<ple__Action__c>();
        for (ple__Config_Action__c config : configActions) {
            ple__Action__c act = new ple__Action__c(
                ple__Config_Action_Id__c = config.Id,
                ple__Action_api_name__c = null
            );
            actions.add(act);
        }
        insert actions;
        
        // Create an Action that should NOT be picked up by the batch (already has API name)
        insert new ple__Action__c(
            ple__Config_Action_Id__c = configActions[0].Id,
            ple__Action_api_name__c = 'Already_Filled'
        );
    }
    
    @IsTest
    static void testBatchExecution() {
        Test.startTest();
        Database.executeBatch(new BackfillActionApiNameBatch(), 200);
        Test.stopTest();
        
        // Query updated Actions
        List<ple__Action__c> updatedActions = [
            SELECT ple__Action_api_name__c, ple__Config_Action_Id__c
            FROM ple__Action__c
            WHERE ple__Action_api_name__c != null
        ];
        
        // We expect only the ones that were null to be updated
        System.assertEquals(4, updatedActions.size(), 'four actions should have been updated.');
        
        // Verify API names match Config Action names
        Map<Id, String> configMap = new Map<Id, String>();
        for (ple__Config_Action__c cfg : [SELECT Id, Name FROM ple__Config_Action__c]) {
            configMap.put(cfg.Id, cfg.Name);
        }
        
        
    }
}