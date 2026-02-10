public class BackfillActionApiNameBatch implements Database.Batchable<SObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, ple__Config_Action_Id__c, ple__Action_api_name__c
            FROM ple__Action__c
            WHERE ple__Action_api_name__c = null
            AND ple__Config_Action_Id__c != null
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<ple__Action__c> scope) {        
        // Collect related Config Action Ids
        Set<Id> configActionIds = new Set<Id>();
        for (ple__Action__c actionRec : scope) {
            configActionIds.add(actionRec.ple__Config_Action_Id__c);
        }
        
        // Query Config Actions to get their API names
        if (!configActionIds.isEmpty()) {
            Map<Id, ple__Config_Action__c> configMap = new Map<Id, ple__Config_Action__c>([SELECT Id, Name, ple__Action_Label__c  FROM ple__Config_Action__c WHERE Id IN :configActionIds]);
            
			List<ple__Action__c> actionList = new List<ple__Action__c>();
            for (ple__Action__c actionRec : scope) {
                if(configMap.containsKey(actionRec.ple__Config_Action_Id__c)){
                    ple__Config_Action__c configRec = configMap.get(actionRec.ple__Config_Action_Id__c);
                    if (configRec != null) {
                        actionRec.ple__Action_api_name__c = configRec.Name;
                        actionList.add(actionRec);
                    }   
                }
            }
            
            // Update Action records with the API name
            if (!actionList.isEmpty()) {
                Database.update(actionList,false) ;
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('BackfillActionApiNameBatch completed.');
    }
}