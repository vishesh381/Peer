// Check Credible Integration Config custom metadata
List<pstar__Credible_Integration_Config__mdt> configs = [
    SELECT Id, DeveloperName, MasterLabel,
           pstar__Client_Export_Connection_String__c,
           pstar__Employee_Export_Connection_String__c,
           pstar__ClientVisit_Export_Connection_String__c
    FROM pstar__Credible_Integration_Config__mdt
];

System.debug('Found ' + configs.size() + ' Credible Integration Config records:');
for (pstar__Credible_Integration_Config__mdt config : configs) {
    System.debug('Config: ' + config.DeveloperName + ' (' + config.MasterLabel + ')');
    System.debug('  Client Export: ' + (String.isBlank(config.pstar__Client_Export_Connection_String__c) ? 'NOT SET' : 'SET (' + config.pstar__Client_Export_Connection_String__c.length() + ' chars)'));
    System.debug('  Employee Export: ' + (String.isBlank(config.pstar__Employee_Export_Connection_String__c) ? 'NOT SET' : 'SET (' + config.pstar__Employee_Export_Connection_String__c.length() + ' chars)'));
    System.debug('  ClientVisit Export: ' + (String.isBlank(config.pstar__ClientVisit_Export_Connection_String__c) ? 'NOT SET' : 'SET (' + config.pstar__ClientVisit_Export_Connection_String__c.length() + ' chars)'));
}
