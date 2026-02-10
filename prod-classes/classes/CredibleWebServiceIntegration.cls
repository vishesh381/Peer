public class CredibleWebServiceIntegration {
    
    @AuraEnabled
    public static String pushDataToCredible(Id patientAdmissionId, Id referralId) {
        Error_Log__c errorlog = new Error_Log__c();
        
        try {
            List<ple__Patient_Admission__c> patientAdmissionList = [
                SELECT 
                Id,
                ple__Patient__c,
                ple__Patient__r.FirstName,
                ple__Patient__r.LastName,
                ple__Patient__r.Credible_Profile_ID__c,
                Credible_Primary_Written_Language__c,
                Credible_Need_Interpreter__c,
                Credible_Living_Situation__c,
                Credible_CPS_Preference__c,
                Credible_Type_of_srvc_F2F__c,
                Credible_Type_of_srvc_Telehealth__c,
                Credible_Type_of_srvc_Telephone__c,
                Credible_Smoking_Status__c,
                Credible_Are_there_pets_in_home__c,
                Credible_Available_Days_Su_Sa__c,
                Available_Times_am_pm__c,
                Credible_Agrees_to_staff_w_Crim_Hx__c,
                Credible_DOB__c,
                Credible_address1__c,
                Credible_City__c,
                Credible_State__c,
                Credible_Zip__c	,
                Credible_County__c,
                Credible_Mobile_Phone__c,
                Credible_Email__c, 
                Credible_ID__c,
                Credible_Preferred_Language__c,
                Credible_Peer_Type__c
                FROM ple__Patient_Admission__c
                WHERE Id = :patientAdmissionId AND ple__Patient__c != NULL 
                LIMIT 1
            ];
            
                     
            
            if (patientAdmissionList.isEmpty()) {
                return 'Error: Patient Admission not found or patient data missing.';
            }
            ple__Patient_Admission__c patientAdmission = patientAdmissionList[0];
            
            Map<String,Object> preferenceOptionMap = new Map<String,Object>();
            for(ple__Preference_Option__c preOptObj : [SELECT Id,ple__Value__c,ple__Preference_Option__r.ple__Value__c,ple__Preference__r.ple__Field_Label_Patient__c,ple__Contact__r.Name FROM ple__Preference_Option__c WHERE ple__Contact__C =: patientAdmission.ple__Patient__c Order By CreatedDate desc] ){
                
                if(preOptObj.ple__Preference__r.ple__Field_Label_Patient__c == 'Need Interpreter?'){
                    Boolean val = preOptObj.ple__Preference_Option__r.ple__Value__c == 'Yes' ? True : False;
                    preferenceOptionMap.put(preOptObj.ple__Preference__r.ple__Field_Label_Patient__c,val);
                }else if(preOptObj.ple__Preference__r.ple__Field_Label_Patient__c == 'Type of Service Delivery'){
                    preferenceOptionMap.put('Type of srvc (Telephone)',null);
                  
                    if(!preferenceOptionMap.containsKey('Type of srvc (Telehealth)') && preOptObj.ple__Preference_Option__r.ple__Value__c == 'Virtual'){
                                            preferenceOptionMap.put('Type of srvc (Telehealth)',preOptObj.ple__Preference_Option__r.ple__Value__c == 'Virtual' ? True : False);

                    }
                    if(!preferenceOptionMap.containsKey('Type of srvc (F2F)') && preOptObj.ple__Preference_Option__r.ple__Value__c == 'In Person' ){
                                            preferenceOptionMap.put('Type of srvc (F2F)',preOptObj.ple__Preference_Option__r.ple__Value__c == 'In Person' ? True : False);

                    }
                }else if(preOptObj.ple__Preference__r.ple__Field_Label_Patient__c == 'Pets in Home'){
                    preferenceOptionMap.put('Pets in Home',preOptObj.ple__Preference_Option__r.ple__Value__c == 'None' ? False : True);
                }else if(preOptObj.ple__Preference__r.ple__Field_Label_Patient__c == 'Agrees to Staff with Criminal History'){
                    Boolean val = preOptObj.ple__Preference_Option__r.ple__Value__c == 'Yes' ? True : False;
                    preferenceOptionMap.put('Agrees to Staff with Criminal History',val);
                }else if(!preferenceOptionMap.containskey(preOptObj.ple__Preference__r.ple__Field_Label_Patient__c)){
                    preferenceOptionMap.put(preOptObj.ple__Preference__r.ple__Field_Label_Patient__c,preOptObj.ple__Preference_Option__r.ple__Value__c);
                }else if(preferenceOptionMap.containskey(preOptObj.ple__Preference__r.ple__Field_Label_Patient__c)){
                    String val = String.valueOf(preferenceOptionMap.get(preOptObj.ple__Preference__r.ple__Field_Label_Patient__c)) +'; '+preOptObj.ple__Preference_Option__r.ple__Value__c;
                    preferenceOptionMap.put(preOptObj.ple__Preference__r.ple__Field_Label_Patient__c,val);
                }
            }  
			         
            Map<String,String> credLookupMap = new Map<String,String>();
            for(Credible_Lookup__c credLookupObj : [SELECT Id,Credible_Value__c,Credible_Lookup_Category__c	,Credible_Lookup_Id__c  FROM Credible_Lookup__c WHERE (Credible_Lookup_Category__c = 'Preferred Language' Or Credible_Lookup_Category__c = 'Smoking Status' Or Credible_Lookup_Category__c = 'Living Situation'  Or Credible_Lookup_Category__c = 'Peer Type')]){
               
                if(credLookupObj.Credible_Lookup_Category__c == 'Preferred Language' && credLookupObj.Credible_Value__c == String.valueOf(preferenceOptionMap.get('Preferred Language'))){
                    credLookupMap.put('Preferred Language',credLookupObj.Credible_Lookup_Id__c);
                }
                if(credLookupObj.Credible_Lookup_Category__c == 'Smoking Status' && credLookupObj.Credible_Value__c == String.valueOf(preferenceOptionMap.get('Smoking Status'))){
                    credLookupMap.put('Smoking Status',credLookupObj.Credible_Lookup_Id__c);
                }
                if(credLookupObj.Credible_Lookup_Category__c == 'Preferred Language' && credLookupObj.Credible_Value__c == String.valueOf(preferenceOptionMap.get('Primary Written Language'))){
                    credLookupMap.put('Primary Written Language',credLookupObj.Credible_Lookup_Id__c);
                }
                if(credLookupObj.Credible_Lookup_Category__c == 'Living Situation' && credLookupObj.Credible_Value__c == String.valueOf(preferenceOptionMap.get('Living Situation'))){
                    credLookupMap.put('Living Situation',credLookupObj.Credible_Lookup_Id__c);
                }
                if(credLookupObj.Credible_Lookup_Category__c == 'Peer Type' && patientAdmission.Credible_Peer_Type__c != NULL && credLookupObj.Credible_Value__c == patientAdmission.Credible_Peer_Type__c){
                    credLookupMap.put('Peer Type',credLookupObj.Credible_Lookup_Id__c);
                }
            }
            String countyCode = '';
            if (!String.isBlank(patientAdmission.Credible_County__c)) {
                List<Credible_County_Config__mdt> countyConfigs = [
                    SELECT Id, Label, County_Code__c 
                    FROM Credible_County_Config__mdt 
                    WHERE County_Code__c != NULL 
                    AND Label = :patientAdmission.Credible_County__c
                    LIMIT 1
                ];
                if (!countyConfigs.isEmpty()) {
                    countyCode = countyConfigs[0].County_Code__c;
                }
            }
            
            
           // Order of fields accepted by API: 
            // 1. Pulse ID 2. First Name  3. Last Name  4. DOB  5. Address 1  
            // 6. City  7. State  8. Zip Code  9. County  10. Mobile Phone  11. E-mail 
            // 12. Preferences (multiple fields) 13. Status 14. Summarized Preferences 15. Peer Type
            
            // Assuming patientAdmissionList has at least one record
            
            String avaDays;
            String avaTime;
            if(preferenceOptionMap.containskey('Available Times Sunday')){
                avaDays = 'Sunday;';
                avaTime = preferenceOptionMap.get('Available Times Sunday') +';';
            }
            if(preferenceOptionMap.containskey('Available Times Monday')){
                avaDays = avaDays != null ? avaDays + 'Monday;' : 'Monday;';
                avaTime = avaTime != null ? avaTime + preferenceOptionMap.get('Available Times Monday') +';' : preferenceOptionMap.get('Available Times Monday') +';';
            }
            if(preferenceOptionMap.containskey('Available Times Tuesday')){
                avaDays = avaDays != null ? avaDays + 'Tuesday;' : 'Tuesday;';
                avaTime = avaTime != null ? avaTime + preferenceOptionMap.get('Available Times Tuesday') +';' : preferenceOptionMap.get('Available Times Tuesday') +';';
            }
            if(preferenceOptionMap.containskey('Available Times Wednesday')){
                avaDays = avaDays != null ? avaDays + 'Wednesday;' : 'Wednesday;';
                avaTime = avaTime != null ? avaTime + preferenceOptionMap.get('Available Times Wednesday') +';' : preferenceOptionMap.get('Available Times Wednesday') +';';
            }
            if(preferenceOptionMap.containskey('Available Times Thursday')){
                avaDays = avaDays != null ? avaDays + 'Thursday;' : 'Thursday;';
                avaTime = avaTime != null ? avaTime + preferenceOptionMap.get('Available Times Thursday') +';' : preferenceOptionMap.get('Available Times Thursday') +';';
            }
            if(preferenceOptionMap.containskey('Available Times Friday')){
                avaDays = avaDays != null ? avaDays + 'Friday;' : 'Friday;';
                avaTime = avaTime != null ? avaTime + preferenceOptionMap.get('Available Times Friday') +';' : preferenceOptionMap.get('Available Times Friday') +';';
            }
            if(preferenceOptionMap.containskey('Available Times Saturday')){
                avaDays = avaDays != null ? avaDays + 'Saturday;' : 'Saturday;';
                avaTime = avaTime != null ? avaTime + preferenceOptionMap.get('Available Times Saturday') +';' : preferenceOptionMap.get('Available Times Saturday') +';';
            }
           
            
            String fullJson = 'Are there pets in home?: ' +
                (preferenceOptionMap.containskey('Pets in Home') ? String.valueOf(preferenceOptionMap.get('Pets in Home')) : '') +
                '; Smoking Status: ' + (preferenceOptionMap.containskey('Smoking Status') ? preferenceOptionMap.get('Smoking Status') : '') +
                '; Available Days (Su - Sa): ' + (avaDays != null ? avaDays : '') +
                '; Available Times (am, pm): ' + (avaTime != null  ? avaTime : '') +
                '; Preferred Language: ' + (preferenceOptionMap.containskey('Preferred Language') ? preferenceOptionMap.get('Preferred Language') : '') +
                '; Primary Written Language: ' + (preferenceOptionMap.containskey('Primary Written Language')? preferenceOptionMap.get('Primary Written Language'): '') +
                '; Need Interpreter?: ' + (preferenceOptionMap.containskey('Need Interpreter?') ? preferenceOptionMap.get('Need Interpreter?') : '') +
                '; Living Situation: ' + (preferenceOptionMap.containskey('Living Situation') ? preferenceOptionMap.get('Living Situation') : '') +
                '; CPS Preference: ' + (preferenceOptionMap.containskey('CPS Preference') ? preferenceOptionMap.get('CPS Preference') : '') +
                '; Type of srvc (Telehealth): ' + (preferenceOptionMap.containskey('Type of srvc (Telehealth)')  ? preferenceOptionMap.get('Type of srvc (Telehealth)') : '') +
                '; Type of srvc (Telephone): ' + (preferenceOptionMap.containskey('Type of srvc (Telephone)')  ? preferenceOptionMap.get('Type of srvc (Telephone)') : '') +
                '; Type of srvc (F2F): ' + (preferenceOptionMap.containskey('Type of srvc (F2F)') ? preferenceOptionMap.get('Type of srvc (F2F)') : '') +
                '; Agrees to staff w/Crim Hx: ' + (preferenceOptionMap.containskey('Agrees to Staff with Criminal History')  ? preferenceOptionMap.get('Agrees to Staff with Criminal History') : '') +
                ';';
            //fullJSON = '';
            String csvData = 
                '"' + (patientAdmission != null ? String.valueOf(patientAdmission.Id) : '') + '",' +
                '"' + (patientAdmission != null && patientAdmission.ple__Patient__r.FirstName != null ? patientAdmission.ple__Patient__r.FirstName : '') + '",' +
                '"' + (patientAdmission != null && patientAdmission.ple__Patient__r.LastName != null ? patientAdmission.ple__Patient__r.LastName : '') + '",' +
                '"' + (patientAdmission != null && patientAdmission.Credible_DOB__c != null ? String.valueOf(patientAdmission.Credible_DOB__c) : '') + '",' +
                '"' + (patientAdmission != null && patientAdmission.Credible_address1__c != null ? patientAdmission.Credible_address1__c : '') + '",' +
                '"' + (patientAdmission != null && patientAdmission.Credible_City__c != null ? patientAdmission.Credible_City__c : '') + '",' +
                '"' + (patientAdmission != null && patientAdmission.Credible_State__c != null ? patientAdmission.Credible_State__c : '') + '",' +
                '"' + (patientAdmission != null && patientAdmission.Credible_Zip__c != null ? patientAdmission.Credible_Zip__c : '') + '",' +
                '"' + (!String.isBlank(countyCode) ? countyCode : '') + '",' +
                '"' + (patientAdmission != null && patientAdmission.Credible_Mobile_Phone__c != null ? patientAdmission.Credible_Mobile_Phone__c.replaceAll('[^0-9]', '') : '') + '",' +
                '"' + (patientAdmission != null && patientAdmission.Credible_Email__c != null ? patientAdmission.Credible_Email__c : '') + '",' + 
                '"' + (preferenceOptionMap.containskey('Pets in Home') ? String.valueOf(preferenceOptionMap.get('Pets in Home')) : '' )+ '",' +
                '"' + (credLookupMap.containskey('Smoking Status') ? credLookupMap.get('Smoking Status') : '')+ '",' +
                '"' + (avaDays != null ? avaDays : '')+ '",' +
                '"' + (avaTime != null  ? avaTime : '')+ '",' +
                '"' + (credLookupMap.containskey('Preferred Language') ? credLookupMap.get('Preferred Language') : '')+ '",' +
                '"' + (credLookupMap.containskey('Primary Written Language') ? credLookupMap.get('Primary Written Language') : '')+ '",' +
                '"' + (preferenceOptionMap.containskey('Need Interpreter?') ? preferenceOptionMap.get('Need Interpreter?') : '')+ '",' +
                '"' + (credLookupMap.containskey('Living Situation') ? credLookupMap.get('Living Situation') : '')+ '",' +
                '"' + (preferenceOptionMap.containskey('CPS Preference') ? preferenceOptionMap.get('CPS Preference') : '')+ '",' +
                '"' + (preferenceOptionMap.containskey('Type of srvc (Telehealth)')  ? preferenceOptionMap.get('Type of srvc (Telehealth)') : '')+ '",' +
                '"' + (preferenceOptionMap.containskey('Type of srvc (F2F)') ? preferenceOptionMap.get('Type of srvc (F2F)')  : '')+ '",' +
                '"' + (preferenceOptionMap.containskey('Agrees to Staff with Criminal History')  ? preferenceOptionMap.get('Agrees to Staff with Criminal History') : '') + '",' +
                '"005",' + 
                '"' + (credLookupMap.containskey('Peer Type') ? credLookupMap.get('Peer Type') : '')+ '",' + 
                '"' + fullJson + 
                '"\n' ;
            	
            
            System.debug('Data : ' + csvData);
            String base64EncodedData = EncodingUtil.base64Encode(Blob.valueOf(csvData));
            
            List<Credible_Integration_Config__mdt> configs = [
                SELECT Import_Connection_String__c 
                FROM Credible_Integration_Config__mdt 
                WHERE DeveloperName = 'Client_Credible_Connection' 
                AND Import_Connection_String__c != NULL 
                LIMIT 1
            ];
            
            if (configs.isEmpty()) {
                errorlog = new Error_Log__c( Source_Name__c = 'Credible',Error_Type__c = 'Apex', Error_Message__c   = 'Import Client connection string is not configured in custom metadata.', Status__c = 'Failed', Error_Details__c  = 'Custom Metadata not found.');
                logErrorSafely(errorlog);
                return 'Import Client connection string is not configured in custom metadata. Please connect with your System Admin.';
            }
            
            String importConnectionStr = configs[0].Import_Connection_String__c;
            String body = 
                'connection=' + EncodingUtil.urlEncode(importConnectionStr, 'UTF-8') +
                '&encodedfile=' + EncodingUtil.urlEncode(base64EncodedData, 'UTF-8');
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(Label.Credible_Import_URL); 
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(body);
            req.setTimeout(12000);
            
            Http http = new Http();
            HttpResponse res = http.send(req) ;
            
            if (res.getStatusCode() == 200) {
                // Debug response headers
                for (String key : res.getHeaderKeys()) {
                    System.debug('Header: ' + key + ' = ' + res.getHeader(key));
                }
                
                String responseBody = res.getBody();
                System.debug('Credible Response Body: ' + responseBody);
                Boolean hasError = false;
                // String apiError = '';
                
                if (!String.isBlank(responseBody) && responseBody.startsWith('<?xml')) {
                    Dom.Document doc = new Dom.Document();
                    doc.load(responseBody);
                    Dom.XmlNode root = doc.getRootElement();
                    System.debug('Root Element: ' + root);
                    if (root.getName() == 'string') {
                        String errorText = root.getText();
                        System.debug(errorText);
                        if (!String.isBlank(errorText) && (errorText.contains('Error') || errorText.contains('error'))) {
                            hasError = true;
                            //   apiError = errorText;
                        }
                    }
                }
                
                if (hasError) {
                    errorlog = new Error_Log__c(
                        Source_Name__c   = 'Credible',
                        Error_Type__c    = 'API',
                        Status_Code__c   = String.valueOf(res.getStatusCode()),
                        Status__c        = 'Failed',
                        Error_Details__c = responseBody
                    );
                    logErrorSafely(errorlog);
                    return 'Error: Callout to Credible Failed';
                }
                
                String peerId = getPeerId(patientAdmissionId);
                System.debug('Returned Peer ID from Credible: ' + peerId);
                
                if (String.isBlank(peerId)) {
                    // Log error if Peer ID not returned
                    errorlog = new Error_Log__c(
                        Source_Name__c     = 'Credible',
                        Error_Type__c      = 'API',
                        Error_Message__c   = 'Peer ID not returned from Credible Export API',
                        Status_Code__c     = String.valueOf(res.getStatusCode()),
                        Status__c          = 'Failed',
                        Error_Details__c   = res.getBody()
                    );
                    logErrorSafely(errorlog);
                    
                    List<CustomNotificationType> customNotification =  [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Credible_Notification' LIMIT 1];
                    
                    if(!customNotification.isEmpty()){
                        Messaging.CustomNotification notification = new Messaging.CustomNotification();
                        notification.setTitle('Credible Profile Created');
                        notification.setBody('Profile was created but no Peer ID was returned.');
                        notification.setNotificationTypeId(customNotification[0].Id);
                        notification.setTargetId(referralId);
                        notification.send(new Set<String>{UserInfo.getUserId()});
                    }
                    
                    return 'Error: Data pushed successfully, Peer ID could not be retrieved';
                }
                
                if(patientAdmission !=  null){
                    patientAdmission.Credible_ID__c = peerId;
                    update patientAdmission;
                }
                
                if(patientAdmission.ple__Patient__c != null){
                    patientAdmission.ple__Patient__r.Credible_Profile_ID__c = peerId;
                    update patientAdmission.ple__Patient__r;
                }
                
                if(referralId!=null){
                    List<ple__Action__c> peerProfileActionList = [Select Id, Name, Credible_Profile_ID__c from ple__Action__c  Where Name = 'Create Peer Profile' And ple__Referral__r.Id = :referralId];
                    if(!peerProfileActionList.isEmpty()){
                        peerProfileActionList[0].Credible_Profile_ID__c = peerId;
                        update peerProfileActionList;
                    }
                    
                }
                
                errorlog = new Error_Log__c(
                    Source_Name__c     = 'Credible',
                    Error_Type__c      = 'API',
                    Error_Message__c   = 'Success',
                    Status_Code__c     = String.valueOf(res.getStatusCode()),
                    Status__c          = res.getStatus(),
                    Error_Details__c   = res.getBody()
                );
                logErrorSafely(errorlog); 
                
                
                
                return 'success';
            } else {
                errorlog = new Error_Log__c(
                    Source_Name__c     = 'Credible',
                    Error_Type__c      = 'API',
                    Error_Message__c   = 'Error while pushing data',
                    Status_Code__c     = String.valueOf(res.getStatusCode()),
                    Status__c          = res.getStatus(),
                    Error_Details__c   = res.getBody()
                );
                logErrorSafely(errorlog);
                return 'An error occurred while pushing data to Credible.';
            }
            
        } catch (Exception e) {
            errorlog = new Error_Log__c(
                Source_Name__c   = 'Credible',
                Error_Type__c    = 'Apex',
                Error_Message__c = e.getMessage(),
                Stack_Trace__c   = e.getStackTraceString(),
                Status__c        = 'Failed'
            );
            logErrorSafely(errorlog);
            return 'An error occurred while pushing data to Credible.';
        }
    }
    
    // Safe logger method to isolate error log insert from rollback
    private static void logErrorSafely(Error_Log__c logEntry) {
        try {
            Database.insert(logEntry, false);
        } catch (Exception logEx) {
            // Prevent recursive failure
            System.debug('Failed to insert error log: ' + logEx.getMessage());
        }
    }
    
    
    
    // Fetch Peer ID from Credible Export API
    public static String getPeerId(Id externalId) {
        String peerId = null;
        
        // Fetch connection string from metadata
        List<Credible_Integration_Config__mdt> configs = [SELECT PeerId_Export_Connection_String__c FROM Credible_Integration_Config__mdt  WHERE DeveloperName = 'Client_Credible_Connection' AND PeerId_Export_Connection_String__c != NULL LIMIT 1];
        
        if (configs.isEmpty()) {
            System.debug('Export connection string not configured in metadata.');
            return null;
        }
        
        String peerIdExportConnectionStr = configs[0].PeerId_Export_Connection_String__c;
        
        String exportUrl = 'https://reportservices.crediblebh.com/reports/ExportService.asmx/ExportDataSet'
            + '?connection=' + EncodingUtil.urlEncode(peerIdExportConnectionStr, 'UTF-8')
            + '&start_date='
            + '&end_date='
            + '&custom_param1=' + externalId
            + '&custom_param2='
            + '&custom_param3=';
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(exportUrl);
        req.setMethod('GET');
        req.setTimeout(120000);
        
        Integer attempts = 0;
        
        while (attempts < 5 && peerId == null) {
            attempts++;
            try {
                HttpResponse res = http.send(req);
                if (res.getStatusCode() == 200) {
                    String body = res.getBody();
                    System.debug('Credible Export Response: ' + body);
                    
                    // Parse XML
                    Dom.Document doc = new Dom.Document();
                    doc.load(body);
                    
                    Dom.XmlNode root = doc.getRootElement(); // DataSet
                    Dom.XmlNode diffgram = root.getChildElement('diffgram', 'urn:schemas-microsoft-com:xml-diffgram-v1');
                    if (diffgram != null) {
                        Dom.XmlNode newDataSet = !diffgram.getChildElements().isEmpty() ?  diffgram.getChildElements().get(0) : Null;
                        if (newDataSet != null) {
                            Dom.XmlNode tableNode =  !newDataSet.getChildElements().isEmpty() ? newDataSet.getChildElements().get(0) : Null;
                            if (tableNode != null) {
                                Dom.XmlNode clientNode = tableNode.getChildElement('client_id', null);
                                if (clientNode != null) {
                                    peerId = clientNode.getText();
                                    System.debug('Fetched PeerID: ' + peerId);
                                    
                                }
                            }
                        }
                    }
                    break;
                } 
                else {
                    System.debug('Attempt Number : ' + attempts + 'Error Status code' + res.getStatusCode());
                }
            } catch (Exception e) {
                System.debug('Export attempt ' + attempts + ' exception: ' + e.getMessage());
            }
            
            
        }
        return peerId;
    } 
   
}