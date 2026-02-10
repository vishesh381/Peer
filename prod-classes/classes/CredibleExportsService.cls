public class CredibleExportsService { 
    
    public static void importClientData(String startDate, String endDate, Date customParam1, Date customParam2, String customParam3) { 
        System.debug('Client Data Import');
        
        List<Credible_Integration_Config__mdt> configRecord = [SELECT Client_Export_Connection_String__c FROM Credible_Integration_Config__mdt WHERE DeveloperName = 'Client_Credible_Connection' And Client_Export_Connection_String__c !=null LIMIT 1];
        if(configRecord.isEmpty()){
            System.debug('No Credible Integration Config Metadata found with a valid Client Export Connection String.');
            return; 
        }
        String exportConnection = configRecord[0].Client_Export_Connection_String__c;
        
        //  String startDateStr = startDate!=null ? String.valueOf(startDate).split(' ')[0] : ''; 
        //  String endDateStr = endDate != null ? String.valueOf(endDate).split(' ')[0] : ''; 
        String url = Label.Credible_Export_BaseUrl + '?connection=' + EncodingUtil.urlEncode(exportConnection, 'UTF-8') + 
            '&start_date=' + EncodingUtil.urlEncode(startDate != null ? startDate : '', 'UTF-8') + 
            '&end_date=' + EncodingUtil.urlEncode(endDate != null ? endDate : '', 'UTF-8') + 
            '&custom_param1=' + String.valueOf(customParam1) +        // CreatedDate
            '&custom_param2=' + String.valueOf(customParam2) + 		// updatedDate
            '&custom_param3=' + EncodingUtil.urlEncode(customParam3 != null ? customParam3 : '', 'UTF-8'); 
        
        System.debug('URL: ' + url); 
        
        HttpRequest req = new HttpRequest(); 
        req.setEndpoint(url); 
        req.setMethod('GET'); 
		req.setTimeout(120000);
        HttpResponse res =  new HttpResponse();
        try{
            Http http = new Http(); 
            res = http.send(req); 
            System.debug('HTTP Status Code: ' + res.getStatusCode()); 
            
            if (res.getStatusCode() == 200) { 
                String responseBody = res.getBody(); 
                System.debug('Response Body: ' + responseBody); 
                
                if(String.isBlank(responseBody)) {
                    System.debug('Response body is empty.');
                    return;
                }
                Dom.Document doc = new Dom.Document(); 
                doc.load(responseBody); 
                Dom.XMLNode root = doc.getRootElement(); 
                
                if (root == null) { 
                    System.debug('No root node found.'); 
                    return; 
                } 
                Dom.XMLNode diffgramNode = root.getChildElement('diffgram', 'urn:schemas-microsoft-com:xml-diffgram-v1'); 
                
                if (diffgramNode == null) { 
                    System.debug('No diffgram node found.'); 
                    return; 
                } 
                
                Dom.XMLNode newDataSetNode = diffgramNode.getChildElements().isEmpty() ? null : diffgramNode.getChildElements().get(0); 
                if (newDataSetNode == null) { 
                    System.debug('No NewDataSet node found.'); 
                    return; 
                } 
                
                List<Dom.XMLNode> tables = newDataSetNode.getChildElements(); 
                System.debug('Number of Table records: ' + tables.size()); 
                
              /*   Map<String, String> countyConfigMap = new Map<String, String>(); 
                for (Credible_County_Config__mdt cfg : [SELECT Id, DeveloperName, MasterLabel, County_Code__c FROM Credible_County_Config__mdt]) {
                    countyConfigMap.put(cfg.County_Code__c, cfg.MasterLabel); 
                }
                
                
                
                ClientLookupWrapper cl = new ClientLookupWrapper();
                
                  for(Credible_Lookup__c lookupRecord: [SELECT Id, Credible_Lookup_Id__c, Credible_Table__c, Credible_Value__c, Credible_Lookup_Category__c FROM Credible_Lookup__c WHERE Credible_Table__c INCLUDES ('Client')]){
                    
			    if(lookupRecord.Credible_Lookup_Category__c == 'Peer Type'){
                        cl.peerTypeCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'State'){
                        cl.stateCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Living Situation'){
                        cl.livingSituationCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Preferred Contact Method'){
                        cl.preferredContactCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Race OMB'){
                        cl.raceCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Ethnicity OMB'){
                        cl.ethnicityCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Preferred Language'){
                        cl.preferredLanguageCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Gender'){
                        cl.genderCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Sexual Orientation'){
                        cl.sexualOrientationCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Gender Identity'){
                        cl.genderIdentityCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Assigned Sex at Birth'){
                        cl.assignedSexAtBirthCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Preferred Pronouns'){
                        cl.preferredPronounCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Signature Source Code'){
                        cl.signatureSourceCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Release Information Code'){
                        cl.releaseInformationCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Bullying Last Occurrence'){
                        cl.bullyingLastOccurrenceCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Forensic Status'){
                        cl.forensicStatusCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Smoking Status'){
                        cl.smokingStatusCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Referral Source'){
                        cl.referralSourceCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Providers'){
                        cl.providersCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    
                    else if(lookupRecord.Credible_Lookup_Category__c == 'No Admit Reason'){
                        cl.noAdmitReasonCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Domain Focus Area Scores'){
                        cl.domainFocusAreaScoresCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Staff Peer Involvement'){
                        cl.staffPeerInvolvementCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Marital Status'){
                        cl.maritalStatusCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    
                    
                } */
                
                Set<String> clientProfileId = new  Set<String>();
                Map<String, Contact> existingContactsMap = new Map<String, Contact>();
                Map<String, Contact> contactToInsert = new Map<String, Contact>();
                
                
                for (Dom.XMLNode table : tables) { 
                    String clientId = table.getChildElement('client_id', null) != null && !isDataEncrypted(table.getChildElement('client_id', null).getText()) ? table.getChildElement('client_id', null).getText() : null;
                    clientProfileId.add(clientId);
                }
                for(Contact c : [ SELECT Id, ple__Contact_Type__c, Credible_Profile_ID__c FROM Contact WHERE ple__Contact_Type__c = 'Patient'  AND Credible_Profile_ID__c IN :clientProfileId]){
                    existingContactsMap.put(c.Credible_Profile_ID__c, c);
                }    
                
                List<ple__Patient_Admission__c> patientAdmissions = new List<ple__Patient_Admission__c>();
                for (Dom.XMLNode table : tables) { 
                   /* String peerType = (table.getChildElement('dd29', null) != null && !isDataEncrypted(table.getChildElement('dd29', null).getText())) ? table.getChildElement('dd29', null).getText() : '';
                    String county = (table.getChildElement('county', null) != null && !isDataEncrypted(table.getChildElement('county', null).getText())) ? table.getChildElement('county', null).getText() : '';
                    String state = (table.getChildElement('state', null) != null && !isDataEncrypted(table.getChildElement('state', null).getText())) ? table.getChildElement('state', null).getText() : '';
                    String livingSituation = (table.getChildElement('dd1', null) != null && !isDataEncrypted(table.getChildElement('dd1', null).getText())) ? table.getChildElement('dd1', null).getText() : '';
                    String preferredContact = (table.getChildElement('preferred_contact', null) != null && !isDataEncrypted(table.getChildElement('preferred_contact', null).getText())) ? table.getChildElement('preferred_contact', null).getText() : '';
                    String race = (table.getChildElement('race_omb', null) != null && !isDataEncrypted(table.getChildElement('race_omb', null).getText())) ? table.getChildElement('race_omb', null).getText() : '';
                    String ethnicity = (table.getChildElement('ethnicity_omb', null) != null && !isDataEncrypted(table.getChildElement('ethnicity_omb', null).getText())) ? table.getChildElement('ethnicity_omb', null).getText() : '';
                    String preferredLanguage = (table.getChildElement('preferred_language', null) != null && !isDataEncrypted(table.getChildElement('preferred_language', null).getText())) ? table.getChildElement('preferred_language', null).getText() : '';
                    String gender = (table.getChildElement('sex', null) != null && !isDataEncrypted(table.getChildElement('sex', null).getText())) ? table.getChildElement('sex', null).getText() : '';
                    String sexualOrientation = (table.getChildElement('dd35', null) != null && !isDataEncrypted(table.getChildElement('dd35', null).getText())) ? table.getChildElement('dd35', null).getText() : '';
                    String genderIdentity = (table.getChildElement('dd36', null) != null && !isDataEncrypted(table.getChildElement('dd36', null).getText())) ? table.getChildElement('dd36', null).getText() : '';
                    String assignedSexAtBirth = (table.getChildElement('dd37', null) != null && !isDataEncrypted(table.getChildElement('dd37', null).getText())) ? table.getChildElement('dd37', null).getText() : '';
                    String preferredPronouns = (table.getChildElement('dd38', null) != null && !isDataEncrypted(table.getChildElement('dd38', null).getText())) ? table.getChildElement('dd38', null).getText() : '';
                    String primaryWrittenLanguage = (table.getChildElement('dd39', null) != null && !isDataEncrypted(table.getChildElement('dd39', null).getText())) ? table.getChildElement('dd39', null).getText() : '';
                    String maritalStatus = (table.getChildElement('maritalstatus', null) != null && !isDataEncrypted(table.getChildElement('maritalstatus', null).getText())) ? table.getChildElement('maritalstatus', null).getText() : '';
                    String clientSignatureSource = (table.getChildElement('sig_source', null) != null && !isDataEncrypted(table.getChildElement('sig_source', null).getText())) ? table.getChildElement('sig_source', null).getText() : '';
                    String releaseInformation = (table.getChildElement('release_information', null) != null && !isDataEncrypted(table.getChildElement('release_information', null).getText())) ? table.getChildElement('release_information', null).getText() : '';
                    String ifYesHowLongAgo_DD33 = (table.getChildElement('dd33', null) != null && !isDataEncrypted(table.getChildElement('dd33', null).getText())) ? table.getChildElement('dd33', null).getText() : '';
                    String ifYesHowLongAgo_DD34 = (table.getChildElement('dd34', null) != null && !isDataEncrypted(table.getChildElement('dd34', null).getText())) ? table.getChildElement('dd34', null).getText() : '';
                    String credibleForensicStatus = (table.getChildElement('dd26', null) != null && !isDataEncrypted(table.getChildElement('dd26', null).getText())) ? table.getChildElement('dd26', null).getText() : '';
                    String smokingStatus = (table.getChildElement('smoking_status', null) != null && !isDataEncrypted(table.getChildElement('smoking_status', null).getText())) ? table.getChildElement('smoking_status', null).getText() : '';
                    String credibleReferralType = (table.getChildElement('referred_source', null) != null && !isDataEncrypted(table.getChildElement('referred_source', null).getText())) ? table.getChildElement('referred_source', null).getText() : '';
                    String credibleReferringProvider = (table.getChildElement('text34', null) != null && !isDataEncrypted(table.getChildElement('text34', null).getText())) ? table.getChildElement('text34', null).getText() : '';
                    String credibleNoAdmitReason = (table.getChildElement('dd31', null) != null && !isDataEncrypted(table.getChildElement('dd31', null).getText())) ? table.getChildElement('dd31', null).getText() : '';
                    String credibleSDoHCurrentRating = (table.getChildElement('num14', null) != null && !isDataEncrypted(table.getChildElement('num14', null).getText())) ? table.getChildElement('num14', null).getText() : '';
                    String credibleIRPInvolvement = (table.getChildElement('dd32', null) != null && !isDataEncrypted(table.getChildElement('dd32', null).getText())) ? table.getChildElement('dd32', null).getText() : ''; */
                    
                    ple__Patient_Admission__c patientAdmission = new ple__Patient_Admission__c();
                    patientAdmission.Credible_ID__c = table.getChildElement('client_id', null) != null && !isDataEncrypted(table.getChildElement('client_id', null).getText()) ? table.getChildElement('client_id', null).getText() : null;
                    patientAdmission.Credible_Referral_Notes__c = table.getChildElement('functional_status', null) != null && !isDataEncrypted(table.getChildElement('functional_status', null).getText()) ? table.getChildElement('functional_status', null).getText() : '';
                    patientAdmission.Credible_Peer_Type__c = table.getChildElement('peertype', null) != null && !isDataEncrypted(table.getChildElement('peertype', null).getText()) ? table.getChildElement('peertype', null).getText() : '';
                    patientAdmission.Credible_Patient_First_Name__c = table.getChildElement('first_name', null) != null && !isDataEncrypted(table.getChildElement('first_name', null).getText()) ? table.getChildElement('first_name', null).getText() : '';
                    patientAdmission.Credible_Patient_Last_Name__c = table.getChildElement('last_name', null) != null && !isDataEncrypted(table.getChildElement('last_name', null).getText()) ? table.getChildElement('last_name', null).getText() : '';
                    patientAdmission.Credible_Patient_Middle_Initial__c = table.getChildElement('mi', null) != null && !isDataEncrypted(table.getChildElement('mi', null).getText()) ? table.getChildElement('mi', null).getText() : '';
                    patientAdmission.Credible_Preferred_Name__c = table.getChildElement('text21', null) != null && !isDataEncrypted(table.getChildElement('text21', null).getText()) ? table.getChildElement('text21', null).getText() : '';
                    patientAdmission.Credible_DOB__c = table.getChildElement('dob', null) != null && !isDataEncrypted(table.getChildElement('dob', null).getText()) ? Date.valueOf(table.getChildElement('dob', null).getText()) : null;
                    patientAdmission.Credible_address1__c = table.getChildElement('address1', null) != null && !isDataEncrypted(table.getChildElement('address1', null).getText()) ? table.getChildElement('address1', null).getText() : '';
                    patientAdmission.Credible_address2__c = table.getChildElement('address2', null) != null && !isDataEncrypted(table.getChildElement('address2', null).getText()) ? table.getChildElement('address2', null).getText() : '';
                    patientAdmission.Credible_City__c = table.getChildElement('city', null) != null && !isDataEncrypted(table.getChildElement('city', null).getText()) ? table.getChildElement('city', null).getText() : '';
                    patientAdmission.Credible_County__c = table.getChildElement('county', null) != null && !isDataEncrypted(table.getChildElement('county', null).getText()) ? table.getChildElement('county', null).getText() : '';
                    patientAdmission.Credible_State__c = table.getChildElement('state', null) != null && !isDataEncrypted(table.getChildElement('state', null).getText()) ? table.getChildElement('state', null).getText() : '';
                    patientAdmission.Credible_Zip__c = table.getChildElement('zip', null) != null && !isDataEncrypted(table.getChildElement('zip', null).getText()) ? table.getChildElement('zip', null).getText() : '';
                    patientAdmission.Credible_Home_Phone__c = table.getChildElement('home_phone', null) != null && !isDataEncrypted(table.getChildElement('home_phone', null).getText()) ? table.getChildElement('home_phone', null).getText() : '';
                    patientAdmission.Credible_Mobile_Phone__c = table.getChildElement('mobile_phone', null) != null && !isDataEncrypted(table.getChildElement('mobile_phone', null).getText()) ? table.getChildElement('mobile_phone', null).getText() : '';
                    patientAdmission.Credible_Email__c = table.getChildElement('client_email', null) != null && !isDataEncrypted(table.getChildElement('client_email', null).getText()) ? table.getChildElement('client_email', null).getText() : '';
                    patientAdmission.Credible_Client_Satus__c = table.getChildElement('client_status', null) != null && !isDataEncrypted(table.getChildElement('client_status', null).getText()) ? table.getChildElement('client_status', null).getText() : '';
                    patientAdmission.Credible_Revision_Due_Date__c = table.getChildElement('date1', null) != null && !isDataEncrypted(table.getChildElement('date1', null).getText()) ? Date.valueOf(table.getChildElement('date1', null).getText()) : null;
                    patientAdmission.Credible_Denied_Transportation__c = table.getChildElement('bool22', null) != null && !isDataEncrypted(table.getChildElement('bool22', null).getText()) ? Boolean.valueOf(table.getChildElement('bool22', null).getText()) : false;
                    patientAdmission.Credible_Age__c = table.getChildElement('age', null) != null && !isDataEncrypted(table.getChildElement('age', null).getText()) ? Decimal.valueOf(table.getChildElement('age', null).getText()) : null;
                    patientAdmission.Credible_Admission_Date__c = table.getChildElement('admission_date', null) != null && !isDataEncrypted(table.getChildElement('admission_date', null).getText()) ? Date.valueOf(table.getChildElement('admission_date', null).getText()) : null;
                    patientAdmission.Credible_Peer_Assigned__c = table.getChildElement('bool17', null) != null && !isDataEncrypted(table.getChildElement('bool17', null).getText()) ? Boolean.valueOf(table.getChildElement('bool17', null).getText()) : false;
                    patientAdmission.Credible_Discharge_Date__c = table.getChildElement('date14', null) != null && !isDataEncrypted(table.getChildElement('date14', null).getText()) ? Date.valueOf(table.getChildElement('date14', null).getText()) : null;
                    patientAdmission.Credible_ssn__c = table.getChildElement('ssn', null) != null && !isDataEncrypted(table.getChildElement('ssn', null).getText()) ? table.getChildElement('ssn', null).getText() : null;
                    patientAdmission.Credible_MAID__c = table.getChildElement('text29', null) != null && !isDataEncrypted(table.getChildElement('text29', null).getText()) ? table.getChildElement('text29', null).getText() : null;
                    patientAdmission.Credible_Do_Not_Bill_Mail__c = table.getChildElement('do_not_bill_direct', null) != null && !isDataEncrypted(table.getChildElement('do_not_bill_direct', null).getText()) ? Boolean.valueOf(table.getChildElement('do_not_bill_direct', null).getText()) : false;
                    patientAdmission.Credible_May_we_call_as_Peerstar__c = table.getChildElement('donotcall', null) != null && !isDataEncrypted(table.getChildElement('donotcall', null).getText()) ? Boolean.valueOf(table.getChildElement('donotcall', null).getText()) : false;
                    patientAdmission.Credible_First_Service_Date__c = table.getChildElement('first_svc_date', null) != null && !isDataEncrypted(table.getChildElement('first_svc_date', null).getText()) ? Date.valueOf(table.getChildElement('first_svc_date', null).getText()) : null;
                    patientAdmission.Credible_Last_Service__c = table.getChildElement('last_svc_date', null) != null && !isDataEncrypted(table.getChildElement('last_svc_date', null).getText()) ? Date.valueOf(table.getChildElement('last_svc_date', null).getText()) : null;
                    patientAdmission.Credible_Living_Situation__c = table.getChildElement('livingsituation', null) != null && !isDataEncrypted(table.getChildElement('livingsituation', null).getText()) ? table.getChildElement('livingsituation', null).getText() : '';
                    patientAdmission.Creedible_Facility_Name__c = table.getChildElement('text3', null) != null && !isDataEncrypted(table.getChildElement('text3', null).getText()) ? table.getChildElement('text3', null).getText() : null;
                    patientAdmission.Credible_Preferred_Contact__c = table.getChildElement('preferredcontactmethod', null) != null && !isDataEncrypted(table.getChildElement('preferredcontactmethod', null).getText()) ? table.getChildElement('preferredcontactmethod', null).getText() : '';
                    patientAdmission.Credible_Race__c = table.getChildElement('raceomb', null) != null && !isDataEncrypted(table.getChildElement('raceomb', null).getText()) ? table.getChildElement('raceomb', null).getText() : '';
                    patientAdmission.Credible_Ethnicity__c = table.getChildElement('ethnicityomb', null) != null && !isDataEncrypted(table.getChildElement('ethnicityomb', null).getText()) ? table.getChildElement('ethnicityomb', null).getText() : '';
                    patientAdmission.Credible_Preferred_Language__c = table.getChildElement('preferredlanguage', null) != null && !isDataEncrypted(table.getChildElement('preferredlanguage', null).getText()) ? table.getChildElement('preferredlanguage', null).getText() : '';
                    patientAdmission.Credible_Is_Restricted__c = table.getChildElement('is_restricted', null) != null && !isDataEncrypted(table.getChildElement('is_restricted', null).getText()) ?  Boolean.valueOf(table.getChildElement('is_restricted', null).getText()) : false;
                    patientAdmission.Credible_Gender_Sex__c	 = table.getChildElement('gender', null) != null && !isDataEncrypted(table.getChildElement('gender', null).getText()) ? table.getChildElement('gender', null).getText() : '';
                    patientAdmission.Credible_Sexual_Orientation__c =  table.getChildElement('sexualorientation', null) != null && !isDataEncrypted(table.getChildElement('sexualorientation', null).getText()) ? table.getChildElement('sexualorientation', null).getText() : '';
                    patientAdmission.Credible_Gender_Identity__c = table.getChildElement('genderidentity', null) != null && !isDataEncrypted(table.getChildElement('genderidentity', null).getText()) ? table.getChildElement('genderidentity', null).getText() : '';
                    patientAdmission.Credible_Assigned_Sex_At_Birth__c = table.getChildElement('assignedsexatbirth', null) != null && !isDataEncrypted(table.getChildElement('assignedsexatbirth', null).getText()) ? table.getChildElement('assignedsexatbirth', null).getText() : '';
                    patientAdmission.Credible_Preferred_Pronouns__c = table.getChildElement('preferredpronouns', null) != null && !isDataEncrypted(table.getChildElement('preferredpronouns', null).getText()) ? table.getChildElement('preferredpronouns', null).getText() : '';
                    patientAdmission.Credible_Primary_Written_Language__c = table.getChildElement('primarywrittenlanguage', null) != null && !isDataEncrypted(table.getChildElement('primarywrittenlanguage', null).getText()) ? table.getChildElement('primarywrittenlanguage', null).getText() : '';
                     patientAdmission.Credible_Marital_Status__c = table.getChildElement('maritalstatus', null) != null && !isDataEncrypted(table.getChildElement('maritalstatus', null).getText()) ? table.getChildElement('maritalstatus', null).getText() : '';
                    patientAdmission.Credible_Next_Appt_Date__c = table.getChildElement('next_appt_date', null) != null && !isDataEncrypted(table.getChildElement('next_appt_date', null).getText()) ? table.getChildElement('next_appt_date', null).getText() : null;
                    patientAdmission.Credible_Any_Allergies__c = table.getChildElement('no_allergy_flag', null) != null && !isDataEncrypted(table.getChildElement('no_allergy_flag', null).getText()) ? Boolean.valueOf(table.getChildElement('no_allergy_flag', null).getText()) : false;
                    patientAdmission.Credible_Allergy_last_Updated__c = table.getChildElement('date_allergy_last_updated', null) != null && !isDataEncrypted(table.getChildElement('date_allergy_last_updated', null).getText()) ? Date.valueOf(table.getChildElement('date_allergy_last_updated', null).getText()) : null;
                    patientAdmission.Credible_No_Medications__c = table.getChildElement('no_med_flag', null) != null && !isDataEncrypted(table.getChildElement('no_med_flag', null).getText()) ? Boolean.valueOf(table.getChildElement('no_med_flag', null).getText()) : false;
                    patientAdmission.Credible_Medications_Last_Updated__c = table.getChildElement('date_medication_last_updated', null) != null && !isDataEncrypted(table.getChildElement('date_medication_last_updated', null).getText()) ? Date.valueOf(table.getChildElement('date_medication_last_updated', null).getText()) : null;
                    patientAdmission.Credible_Client_Signature_Source__c = table.getChildElement('clientsignaturesource', null) != null && !isDataEncrypted(table.getChildElement('clientsignaturesource', null).getText()) ? table.getChildElement('clientsignaturesource', null).getText() : '';
                    patientAdmission.Credible_Release_Of_Information__c = table.getChildElement('releaseofinformation', null) != null && !isDataEncrypted(table.getChildElement('releaseofinformation', null).getText()) ? table.getChildElement('releaseofinformation', null).getText() : '';
                    patientAdmission.Credible_First_Bill_Service_Date__c = table.getChildElement('first_bill_svc_date', null) != null && !isDataEncrypted(table.getChildElement('first_bill_svc_date', null).getText()) ? Date.valueOf(table.getChildElement('first_bill_svc_date', null).getText()) : null;
                    patientAdmission.Credible_Last_Bill_Service_Date__c = table.getChildElement('last_bill_svc_date', null) != null && !isDataEncrypted(table.getChildElement('last_bill_svc_date', null).getText()) ? Date.valueOf(table.getChildElement('last_bill_svc_date', null).getText()) : null;
                    //patientAdmission.Credible_Last_Billable_Service_Typ__c = table.getChildElement('last_bill_visittype_id', null) != null && !isDataEncrypted(table.getChildElement('last_bill_visittype_id', null).getText()) ? table.getChildElement('last_bill_visittype_id', null).getText() : null;
                    patientAdmission.Credible_Date_Created__c = table.getChildElement('date_created', null) != null && !isDataEncrypted(table.getChildElement('date_created', null).getText()) ? Date.valueOf(table.getChildElement('date_created', null).getText()) : null;
                    patientAdmission.Credible_Date_Updated__c = table.getChildElement('date_updated', null) != null && !isDataEncrypted(table.getChildElement('date_updated', null).getText()) ? Date.valueOf(table.getChildElement('date_updated', null).getText()) : null;                    
                    patientAdmission.Credible_Last_Client_Status_Update__c = table.getChildElement('client_status_date', null) != null && !isDataEncrypted(table.getChildElement('client_status_date', null).getText()) ? Date.valueOf(table.getChildElement('client_status_date', null).getText()) : null;
                    patientAdmission.Credible_Reason_Seeking_Services__c = table.getChildElement('textlong1', null) != null && !isDataEncrypted(table.getChildElement('textlong1', null).getText()) ? table.getChildElement('textlong1', null).getText() : null;
                    patientAdmission.Credible_Diagnosis_Intake__c = table.getChildElement('text26', null) != null && !isDataEncrypted(table.getChildElement('text26', null).getText()) ? table.getChildElement('text26', null).getText() : null;
                    patientAdmission.Credible_Diagnosis_Primary__c = table.getChildElement('axis_1', null) != null && !isDataEncrypted(table.getChildElement('axis_1', null).getText()) ? table.getChildElement('axis_1', null).getText() : null;
                    patientAdmission.Credible_Date_Dx_Last_Updated__c = table.getChildElement('date_diagnosis_last_updated', null) != null && !isDataEncrypted(table.getChildElement('date_diagnosis_last_updated', null).getText()) ? Date.valueOf(table.getChildElement('date_diagnosis_last_updated', null).getText()) : null;
                    patientAdmission.Credible_Primary_Care_Physician__c = table.getChildElement('text24', null) != null && !isDataEncrypted(table.getChildElement('text24', null).getText()) ? table.getChildElement('text24', null).getText() : null;
                    patientAdmission.Credible_IDD__c = table.getChildElement('bool40', null) != null && !isDataEncrypted(table.getChildElement('bool40', null).getText()) ? Boolean.valueOf(table.getChildElement('bool40', null).getText()) : false;
                    patientAdmission.Credible_Medical_Problems__c = table.getChildElement('textlong2', null) != null && !isDataEncrypted(table.getChildElement('textlong2', null).getText()) ? table.getChildElement('textlong2', null).getText() : null;
                    patientAdmission.Credible_Psychiatrist__c = table.getChildElement('text25', null) != null && !isDataEncrypted(table.getChildElement('text25', null).getText()) ? table.getChildElement('text25', null).getText() : null;
                    patientAdmission.Credible_Last_Psych_Eval__c = table.getChildElement('text5', null) != null && !isDataEncrypted(table.getChildElement('text5', null).getText()) ? table.getChildElement('text5', null).getText() : null;
                    patientAdmission.Credible_Is_There_a_Hx_of_Trauma__c = table.getChildElement('bool1', null) != null && !isDataEncrypted(table.getChildElement('bool1', null).getText()) ? Boolean.valueOf(table.getChildElement('bool1', null).getText()) : false;
                    patientAdmission.Credible_If_Yes_Action_Taken__c = table.getChildElement('text10', null) != null && !isDataEncrypted(table.getChildElement('text10', null).getText()) ? table.getChildElement('text10', null).getText() : null;
                    patientAdmission.Credible_Been_victim_of_bullying__c = table.getChildElement('bool27', null) != null && !isDataEncrypted(table.getChildElement('bool27', null).getText()) ? Boolean.valueOf(table.getChildElement('bool27', null).getText()) : false;
                    patientAdmission.Credible_dd33_If_yes_How_long_ago__c	 = table.getChildElement('ifyeshowlongago_dd33', null) != null && !isDataEncrypted(table.getChildElement('ifyeshowlongago_dd33', null).getText()) ? table.getChildElement('ifyeshowlongago_dd33', null).getText() : '';
                    patientAdmission.Credible_Have_you_bullied_others__c = table.getChildElement('bool28', null) != null && !isDataEncrypted(table.getChildElement('bool28', null).getText()) ? Boolean.valueOf(table.getChildElement('bool28', null).getText()) : false;
                    patientAdmission.Credible_dd34_If_yes_How_long_ago__c = table.getChildElement('ifyeshowlongago_dd34', null) != null && !isDataEncrypted(table.getChildElement('ifyeshowlongago_dd34', null).getText()) ? table.getChildElement('ifyeshowlongago_dd34', null).getText() : '';
                    patientAdmission.Credible_Is_There_a_Hx_of_D_A_Use__c = table.getChildElement('bool3', null) != null && !isDataEncrypted(table.getChildElement('bool3', null).getText()) ? Boolean.valueOf(table.getChildElement('bool3', null).getText()) : false;
                    patientAdmission.Credible_text11_If_Yes_Specify__c = table.getChildElement('text11', null) != null && !isDataEncrypted(table.getChildElement('text11', null).getText()) ? table.getChildElement('text11', null).getText() : null;
                    patientAdmission.Credible_Participated_in_D_A_Tx__c = table.getChildElement('bool2', null) != null && !isDataEncrypted(table.getChildElement('bool2', null).getText()) ? Boolean.valueOf(table.getChildElement('bool2', null).getText()) : false;
                    patientAdmission.Credible_text6If_Yes_Specify__c = table.getChildElement('text6', null) != null && !isDataEncrypted(table.getChildElement('text6', null).getText()) ? table.getChildElement('text6', null).getText() : null;
                    patientAdmission.Credible_Inpatient_Trtmnt_Hx__c = table.getChildElement('bool8', null) != null && !isDataEncrypted(table.getChildElement('bool8', null).getText()) ? Boolean.valueOf(table.getChildElement('bool8', null).getText()) : false;
                    patientAdmission.Credible_Inpt_Tx_Location_Dates__c = table.getChildElement('text15', null) != null && !isDataEncrypted(table.getChildElement('text15', null).getText()) ? table.getChildElement('text15', null).getText() : null;
                    patientAdmission.Credible_D_A_Inpt_Trtmnt_Hx__c = table.getChildElement('bool9', null) != null && !isDataEncrypted(table.getChildElement('bool9', null).getText()) ? Boolean.valueOf(table.getChildElement('bool9', null).getText()) : false;
                    patientAdmission.Credible_D_A_Inpt_TxLocation_Dates__c = table.getChildElement('text16', null) != null && !isDataEncrypted(table.getChildElement('text16', null).getText()) ? table.getChildElement('text16', null).getText() : null;
                    patientAdmission.Credible_Outpt_Therapy_Trtmnt_Hx__c = table.getChildElement('bool10', null) != null && !isDataEncrypted(table.getChildElement('bool10', null).getText()) ? Boolean.valueOf(table.getChildElement('bool10', null).getText()) : false;
                    patientAdmission.Credible_Outpt_Tx_Location_Dates__c = table.getChildElement('text17', null) != null && !isDataEncrypted(table.getChildElement('text17', null).getText()) ? table.getChildElement('text17', null).getText() : null;
                    patientAdmission.Credible_Residential_Trtmnt_Hx__c = table.getChildElement('bool11', null) != null && !isDataEncrypted(table.getChildElement('bool11', null).getText()) ? Boolean.valueOf(table.getChildElement('bool11', null).getText()) : false;
                    patientAdmission.Credible_ResidentialLocation_Dates__c = table.getChildElement('text18', null) != null && !isDataEncrypted(table.getChildElement('text18', null).getText()) ? table.getChildElement('text18', null).getText() : null;
                    patientAdmission.Credible_Other_Service_Involvement__c = table.getChildElement('text8', null) != null && !isDataEncrypted(table.getChildElement('text8', null).getText()) ? table.getChildElement('text8', null).getText() : null;
                    patientAdmission.Credible_Legal_Involve_in_Past_Yr__c = table.getChildElement('bool4', null) != null && !isDataEncrypted(table.getChildElement('bool4', null).getText()) ? Boolean.valueOf(table.getChildElement('bool4', null).getText()) : false;
                    patientAdmission.Credible_Forensic_Status__c = table.getChildElement('forensicstatus', null) != null && !isDataEncrypted(table.getChildElement('forensicstatus', null).getText()) ? table.getChildElement('forensicstatus', null).getText() : '';
                    patientAdmission.Credible_If_Yes_Specify_on_Form__c = table.getChildElement('text7', null) != null && !isDataEncrypted(table.getChildElement('text7', null).getText()) ? table.getChildElement('text7', null).getText() : null;
                    patientAdmission.Credible_Served_In_Military__c = table.getChildElement('bool5', null) != null && !isDataEncrypted(table.getChildElement('bool5', null).getText()) ? Boolean.valueOf(table.getChildElement('bool5', null).getText()) : false;
                    patientAdmission.Credible_If_Yes_When_Branch__c = table.getChildElement('text9', null) != null && !isDataEncrypted(table.getChildElement('text9', null).getText()) ? table.getChildElement('text9', null).getText() : null;
                    patientAdmission.Credible_Employed__c = table.getChildElement('bool7', null) != null && !isDataEncrypted(table.getChildElement('bool7', null).getText()) ? Boolean.valueOf(table.getChildElement('bool7', null).getText()) : false;
                    patientAdmission.Credible_Place_of_Employment__c = table.getChildElement('text12', null) != null && !isDataEncrypted(table.getChildElement('text12', null).getText()) ? table.getChildElement('text12', null).getText() : null;
                    patientAdmission.Credible_Are_there_pets_in_home__c = table.getChildElement('bool12', null) != null && !isDataEncrypted(table.getChildElement('bool12', null).getText()) ? Boolean.valueOf(table.getChildElement('bool12', null).getText()) : false;
                    patientAdmission.Credible_If_pets_Yes_what_kind__c = table.getChildElement('text20', null) != null && !isDataEncrypted(table.getChildElement('text20', null).getText()) ? table.getChildElement('text20', null).getText() : null;
                    patientAdmission.Credible_Hx_of_pet_aggression__c = table.getChildElement('bool29', null) != null && !isDataEncrypted(table.getChildElement('bool29', null).getText()) ? Boolean.valueOf(table.getChildElement('bool29', null).getText()) : false;
                    patientAdmission.Credible_Smoking_Status__c = table.getChildElement('smokingstatus', null) != null && !isDataEncrypted(table.getChildElement('smokingstatus', null).getText()) ? table.getChildElement('smokingstatus', null).getText() : '';
                    patientAdmission.Credible_Agrees_to_staff_w_Crim_Hx__c = table.getChildElement('bool6', null) != null && !isDataEncrypted(table.getChildElement('bool6', null).getText()) ? Boolean.valueOf(table.getChildElement('bool6', null).getText()) : false;
                    patientAdmission.Credible_CPS_Preference__c = table.getChildElement('text28', null) != null && !isDataEncrypted(table.getChildElement('text28', null).getText()) ? table.getChildElement('text28', null).getText() : null;
                    patientAdmission.Credible_Need_Interpreter__c = table.getChildElement('deaf', null) != null && !isDataEncrypted(table.getChildElement('deaf', null).getText()) ? Boolean.valueOf(table.getChildElement('deaf', null).getText()) : false;
                    patientAdmission.Credible_Available_Days_Su_Sa__c = table.getChildElement('text13', null) != null && !isDataEncrypted(table.getChildElement('text13', null).getText()) ? table.getChildElement('text13', null).getText() : null;
                    patientAdmission.Available_Times_am_pm__c = table.getChildElement('text14', null) != null && !isDataEncrypted(table.getChildElement('text14', null).getText()) ? table.getChildElement('text14', null).getText() : null;
                    patientAdmission.Credible_Date_of_Death__c = table.getChildElement('date_of_death', null) != null && !isDataEncrypted(table.getChildElement('date_of_death', null).getText()) ? Date.valueOf(table.getChildElement('date_of_death', null).getText()) : null;
                    patientAdmission.Credible_6_or_12_Month_Auth__c = table.getChildElement('num1', null) != null && !isDataEncrypted(table.getChildElement('num1', null).getText()) ? table.getChildElement('num1', null).getText() : '';
                    patientAdmission.Credible_Authorization_Due_Date__c = table.getChildElement('date10', null) != null && !isDataEncrypted(table.getChildElement('date10', null).getText()) ? Date.valueOf(table.getChildElement('date10', null).getText()) : null;
                    patientAdmission.Credible_How_did_you_hear_of_us__c = table.getChildElement('text2', null) != null && !isDataEncrypted(table.getChildElement('text2', null).getText()) ? table.getChildElement('text2', null).getText() : null;
                    patientAdmission.Credible_Referred_By__c = table.getChildElement('text33', null) != null && !isDataEncrypted(table.getChildElement('text33', null).getText()) ? table.getChildElement('text33', null).getText() : null;
                    patientAdmission.Credible_Web_Referral__c = table.getChildElement('bool26', null) != null && !isDataEncrypted(table.getChildElement('bool26', null).getText()) ? Boolean.valueOf(table.getChildElement('bool26', null).getText()) : false;
                    patientAdmission.Credible_Referral_Date__c = table.getChildElement('referral_date', null) != null && !isDataEncrypted(table.getChildElement('referral_date', null).getText()) ? Date.valueOf(table.getChildElement('referral_date', null).getText()) : null;
                    patientAdmission.Credible_Referral_Type__c = table.getChildElement('referralsource', null) != null && !isDataEncrypted(table.getChildElement('referralsource', null).getText()) ? table.getChildElement('referralsource', null).getText() : '';
                    patientAdmission.Credible_Referral_Phone__c = table.getChildElement('text1', null) != null && !isDataEncrypted(table.getChildElement('text1', null).getText()) ? table.getChildElement('text1', null).getText() : null;
                    patientAdmission.Credible_Is_High_No_Show__c = table.getChildElement('high_no_show', null) != null && !isDataEncrypted(table.getChildElement('high_no_show', null).getText()) ? Boolean.valueOf(table.getChildElement('high_no_show', null).getText()) : false;
                    patientAdmission.Credible_Activity_VF1__c = table.getChildElement('text31', null) != null && !isDataEncrypted(table.getChildElement('text31', null).getText()) ? table.getChildElement('text31', null).getText() : null;
                    patientAdmission.Credible_Activity_VID1__c = table.getChildElement('text43', null) != null && !isDataEncrypted(table.getChildElement('text43', null).getText()) ? table.getChildElement('text43', null).getText() : null;
                    patientAdmission.Credible_Activity_IIIC1__c = table.getChildElement('text37', null) != null && !isDataEncrypted(table.getChildElement('text37', null).getText()) ? table.getChildElement('text37', null).getText() : null;
                    patientAdmission.Credible_Activity_IIID1__c = table.getChildElement('text38', null) != null && !isDataEncrypted(table.getChildElement('text38', null).getText()) ? table.getChildElement('text38', null).getText() : null;
                    patientAdmission.Credible_Activities_Response__c = table.getChildElement('textlong4', null) != null && !isDataEncrypted(table.getChildElement('textlong4', null).getText()) ? table.getChildElement('textlong4', null).getText() : null;
                    patientAdmission.Credible_REFERRING_PROVIDER__c = table.getChildElement('providerdetails', null) != null && !isDataEncrypted(table.getChildElement('providerdetails', null).getText()) ? table.getChildElement('providerdetails', null).getText() : '';
                    patientAdmission.Credible_Referring_Provider_2__c = (table.getChildElement('referred_by', null) != null && !isDataEncrypted(table.getChildElement('referred_by', null).getText())) ? table.getChildElement('referred_by', null).getText() : '';
                    patientAdmission.Credible_Referring_NPI__c = table.getChildElement('referred_npi', null) != null && !isDataEncrypted(table.getChildElement('referred_npi', null).getText()) ? table.getChildElement('referred_npi', null).getText() : '';
                    patientAdmission.Credible_Referring_MA__c = table.getChildElement('referred_id', null) != null && !isDataEncrypted(table.getChildElement('referred_id', null).getText()) ? table.getChildElement('referred_id', null).getText() : '';
                    patientAdmission.Credible_Referring_Qualifier__c = (table.getChildElement('referred_id_qualifier', null) != null && !isDataEncrypted(table.getChildElement('referred_id_qualifier', null).getText())) ? table.getChildElement('referred_id_qualifier', null).getText() : '';
                    patientAdmission.Credible_Continued_Stay_Require__c = table.getChildElement('textlong5', null) != null && !isDataEncrypted(table.getChildElement('textlong5', null).getText()) ? table.getChildElement('textlong5', null).getText() : '';
                    patientAdmission.Credible_DOC_Number__c = table.getChildElement('text35', null) != null && !isDataEncrypted(table.getChildElement('text35', null).getText()) ? table.getChildElement('text35', null).getText() : '';
                    patientAdmission.Credible_BSU__c = table.getChildElement('text40', null) != null && !isDataEncrypted(table.getChildElement('text40', null).getText()) ? table.getChildElement('text40', null).getText() : '';
                    patientAdmission.Credible_Philadelphia_ID__c = table.getChildElement('text36', null) != null && !isDataEncrypted(table.getChildElement('text36', null).getText()) ? table.getChildElement('text36', null).getText() : '';
                    patientAdmission.Credible_No_Admit_Reason__c = table.getChildElement('noadmitreason', null) != null && !isDataEncrypted(table.getChildElement('noadmitreason', null).getText()) ? table.getChildElement('noadmitreason', null).getText() : '';
                    patientAdmission.Credible_Activity_36__c = table.getChildElement('text32', null) != null && !isDataEncrypted(table.getChildElement('text32', null).getText()) ? table.getChildElement('text32', null).getText() : '';
                    patientAdmission.Credible_Activity_37__c = table.getChildElement('text39', null) != null && !isDataEncrypted(table.getChildElement('text39', null).getText()) ? table.getChildElement('text39', null).getText() : '';
                    patientAdmission.Credible_Activity_38__c = table.getChildElement('text41', null) != null && !isDataEncrypted(table.getChildElement('text41', null).getText()) ? table.getChildElement('text41', null).getText() : '';
                    patientAdmission.Credible_Activity_39__c = table.getChildElement('text42', null) != null && !isDataEncrypted(table.getChildElement('text42', null).getText()) ? table.getChildElement('text42', null).getText() : '';
                    patientAdmission.Credible_Activity_40__c = table.getChildElement('text44', null) != null && !isDataEncrypted(table.getChildElement('text44', null).getText()) ? table.getChildElement('text44', null).getText() : '';
                    patientAdmission.Credible_Activity_41__c = table.getChildElement('text45', null) != null && !isDataEncrypted(table.getChildElement('text45', null).getText()) ? table.getChildElement('text45', null).getText() : '';
                    patientAdmission.Credible_Activity_42__c = table.getChildElement('text46', null) != null && !isDataEncrypted(table.getChildElement('text46', null).getText()) ? table.getChildElement('text46', null).getText() : '';
                    patientAdmission.Credible_Activity_43__c = table.getChildElement('text47', null) != null && !isDataEncrypted(table.getChildElement('text47', null).getText()) ? table.getChildElement('text47', null).getText() : '';
                    patientAdmission.Credible_Activity_44__c = table.getChildElement('text48', null) != null && !isDataEncrypted(table.getChildElement('text48', null).getText()) ? table.getChildElement('text48', null).getText() : '';
                    patientAdmission.Credible_Activity_45__c = table.getChildElement('text49', null) != null && !isDataEncrypted(table.getChildElement('text49', null).getText()) ? table.getChildElement('text49', null).getText() : '';
                    patientAdmission.Credible_Activity_46__c = table.getChildElement('text50', null) != null && !isDataEncrypted(table.getChildElement('text50', null).getText()) ? table.getChildElement('text50', null).getText() : '';
                    patientAdmission.Credible_Type_of_srvc_Telehealth__c = table.getChildElement('bool23', null) != null && !isDataEncrypted(table.getChildElement('bool23', null).getText()) ? Boolean.valueOf(table.getChildElement('bool23', null).getText()) : false;
                    patientAdmission.Credible_Type_of_srvc_Telephone__c = table.getChildElement('bool24', null) != null && !isDataEncrypted(table.getChildElement('bool24', null).getText()) ? Boolean.valueOf(table.getChildElement('bool24', null).getText()) : false;
                    patientAdmission.Credible_Type_of_srvc_F2F__c = table.getChildElement('bool25', null) != null && !isDataEncrypted(table.getChildElement('bool25', null).getText()) ? Boolean.valueOf(table.getChildElement('bool25', null).getText()) : false;
                    patientAdmission.Credible_SDoH__c = table.getChildElement('bool39', null) != null && !isDataEncrypted(table.getChildElement('bool39', null).getText()) ? Boolean.valueOf(table.getChildElement('bool39', null).getText()) : false;
                    patientAdmission.Credible_Goal_A__c = table.getChildElement('spouse_name', null) != null && !isDataEncrypted(table.getChildElement('spouse_name', null).getText()) ? table.getChildElement('spouse_name', null).getText() : '';
                    patientAdmission.Credible_Goal_B__c = table.getChildElement('company', null) != null && !isDataEncrypted(table.getChildElement('company', null).getText()) ? table.getChildElement('company', null).getText() : '';
                    patientAdmission.Credible_Goal_C__c = table.getChildElement('granular_ethnicity', null) != null && !isDataEncrypted(table.getChildElement('granular_ethnicity', null).getText()) ? table.getChildElement('granular_ethnicity', null).getText() : '';
                    patientAdmission.Credible_Goal_D__c = table.getChildElement('immunization_publicity_code', null) != null && !isDataEncrypted(table.getChildElement('immunization_publicity_code', null).getText()) ? table.getChildElement('immunization_publicity_code', null).getText() : '';
                    patientAdmission.Credible_Goal_E__c = table.getChildElement('granular_race', null) != null && !isDataEncrypted(table.getChildElement('granular_race', null).getText()) ? table.getChildElement('granular_race', null).getText() : '';
                    patientAdmission.Credible_Goal_F__c = table.getChildElement('gender_identity', null) != null && !isDataEncrypted(table.getChildElement('gender_identity', null).getText()) ? table.getChildElement('gender_identity', null).getText() : '';
                    patientAdmission.Credible_Goal_G__c = table.getChildElement('referred_upin', null) != null && !isDataEncrypted(table.getChildElement('referred_upin', null).getText()) ? table.getChildElement('referred_upin', null).getText() : '';
                    patientAdmission.Credible_Goal_H__c = table.getChildElement('previous_name', null) != null && !isDataEncrypted(table.getChildElement('previous_name', null).getText()) ? table.getChildElement('previous_name', null).getText() : '';
                    patientAdmission.Credible_Goal_I__c = table.getChildElement('emergency_contact', null) != null && !isDataEncrypted(table.getChildElement('emergency_contact', null).getText()) ? table.getChildElement('emergency_contact', null).getText() : '';
                    patientAdmission.Credible_Activity_A__c = table.getChildElement('sexual_orientation', null) != null && !isDataEncrypted(table.getChildElement('sexual_orientation', null).getText()) ? table.getChildElement('sexual_orientation', null).getText() : '';
                    patientAdmission.Credible_Activity_B__c = table.getChildElement('text23', null) != null && !isDataEncrypted(table.getChildElement('text23', null).getText()) ? table.getChildElement('text23', null).getText() : '';
                    patientAdmission.Credible_Activity_C__c = table.getChildElement('cognitive_status', null) != null && !isDataEncrypted(table.getChildElement('cognitive_status', null).getText()) ? table.getChildElement('cognitive_status', null).getText() : '';
                    patientAdmission.Credible_Activity_D__c = table.getChildElement('text19', null) != null && !isDataEncrypted(table.getChildElement('text19', null).getText()) ? table.getChildElement('text19', null).getText() : '';
                    patientAdmission.Credible_Activity_E__c = table.getChildElement('mother_maiden_name', null) != null && !isDataEncrypted(table.getChildElement('mother_maiden_name', null).getText()) ? table.getChildElement('mother_maiden_name', null).getText() : '';
                    patientAdmission.Credible_Activity_F__c = table.getChildElement('suffix', null) != null && !isDataEncrypted(table.getChildElement('suffix', null).getText()) ? table.getChildElement('suffix', null).getText() : '';
                    patientAdmission.Credible_Activity_G__c = table.getChildElement('text27', null) != null && !isDataEncrypted(table.getChildElement('text27', null).getText()) ? table.getChildElement('text27', null).getText() : '';
                    patientAdmission.Credible_Activity_H__c = table.getChildElement('textlong3', null) != null && !isDataEncrypted(table.getChildElement('textlong3', null).getText()) ? table.getChildElement('textlong3', null).getText() : '';
                    patientAdmission.Credible_Activity_I__c = table.getChildElement('text30', null) != null && !isDataEncrypted(table.getChildElement('text30', null).getText()) ? table.getChildElement('text30', null).getText() : '';
                    patientAdmission.Credible_SDoH_ANSA_Total__c = table.getChildElement('num12', null) != null && !isDataEncrypted(table.getChildElement('num12', null).getText()) ? Decimal.valueOf(table.getChildElement('num12', null).getText()) : null;
                    patientAdmission.Credible_SDoH_Base__c = table.getChildElement('num13', null) != null && !isDataEncrypted(table.getChildElement('num13', null).getText()) ? table.getChildElement('num13', null).getText() : null;
                    patientAdmission.Credible_SDoH_Goal__c = table.getChildElement('num15', null) != null && !isDataEncrypted(table.getChildElement('num15', null).getText()) ? Decimal.valueOf(table.getChildElement('num15', null).getText()) : null;
                    patientAdmission.Credible_SDoH_Current_Rating__c =  table.getChildElement('sdohcurrentrating', null) != null && !isDataEncrypted(table.getChildElement('sdohcurrentrating', null).getText()) ? table.getChildElement('sdohcurrentrating', null).getText() : '';
                    patientAdmission.Credible_SDoH_Suggested_Hrs__c = table.getChildElement('num17', null) != null && !isDataEncrypted(table.getChildElement('num17', null).getText()) ? Decimal.valueOf(table.getChildElement('num17', null).getText()) : null;
                    patientAdmission.Credible_SDoH_Requested_Hrs__c = table.getChildElement('num16', null) != null && !isDataEncrypted(table.getChildElement('num16', null).getText()) ? Decimal.valueOf(table.getChildElement('num16', null).getText()) : null;
                    patientAdmission.Credible_MG_SDoH__c = table.getChildElement('textlong6', null) != null && !isDataEncrypted(table.getChildElement('textlong6', null).getText()) ? table.getChildElement('textlong6', null).getText() : '';
                    patientAdmission.Credible_Goal_IIH__c = table.getChildElement('text22', null) != null && !isDataEncrypted(table.getChildElement('text22', null).getText()) ? table.getChildElement('text22', null).getText() : '';
                    patientAdmission.Credible_Activity_IIH__c = table.getChildElement('textlong7', null) != null && !isDataEncrypted(table.getChildElement('textlong7', null).getText()) ? table.getChildElement('textlong7', null).getText() : '';
                    patientAdmission.Credible_IRP_involvement__c = table.getChildElement('irpinvolvement', null) != null && !isDataEncrypted(table.getChildElement('irpinvolvement', null).getText()) ? table.getChildElement('irpinvolvement', null).getText() : '';
                    patientAdmission.Credible_CRS_receiving_COE_services__c = table.getChildElement('bool21', null) != null && !isDataEncrypted(table.getChildElement('bool21', null).getText()) ? Boolean.valueOf(table.getChildElement('bool21', null).getText()) : false;
                    patientAdmission.Credible_Communicate_via_email__c = table.getChildElement('bool30', null) != null && !isDataEncrypted(table.getChildElement('bool30', null).getText()) ? Boolean.valueOf(table.getChildElement('bool30', null).getText()) : false;
                    patientAdmission.Credible_Communicate_via_text__c = table.getChildElement('bool31', null) != null && !isDataEncrypted(table.getChildElement('bool31', null).getText()) ? Boolean.valueOf(table.getChildElement('bool31', null).getText()) : false;
                    patientAdmission.Credible_Smoking_End_Date__c = table.getChildElement('smoking_end_date', null) != null && !isDataEncrypted(table.getChildElement('smoking_end_date', null).getText()) ? Date.valueOf(table.getChildElement('smoking_end_date', null).getText()) : null;
                    
                    
                    if(existingContactsMap.containsKey(patientAdmission.Credible_ID__c)){
                        patientAdmission.ple__Patient__c = existingContactsMap.get(patientAdmission.Credible_ID__c).Id;
                    }else{
                        String emailVal = patientAdmission.Credible_Email__c;
                        if (String.isBlank(emailVal) || emailVal.contains('N/A') || !Pattern.matches('^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$', emailVal)) {
                            emailVal = null;
                        }
                        Contact patient = new Contact(
                            ple__Contact_Type__c = 'Patient',
                            Credible_Profile_ID__c = patientAdmission.Credible_ID__c,
                            FirstName = patientAdmission.Credible_Patient_First_Name__c,
                            LastName = patientAdmission.Credible_Patient_Last_Name__c,
                            Birthdate = patientAdmission.Credible_DOB__c,
                            Email = emailVal
                        );
                        contactToInsert.put(patientAdmission.Credible_ID__c, patient);
                    }
                    patientAdmissions.add(patientAdmission);
                    
                } 
                if (!contactToInsert.values().isEmpty()) {
                    insert contactToInsert.values();
                }
                
                for(ple__Patient_Admission__c patientAdmission  : patientAdmissions){
                    if(contactToInsert.containsKey(patientAdmission.Credible_ID__c)){
                        patientAdmission.ple__Patient__c = contactToInsert.get(patientAdmission.Credible_ID__c).Id;
                    }
                }
                
                
                
                System.debug('patientAdmissions -- '+patientAdmissions);
                if(!patientAdmissions.isEmpty()) {
                    Database.UpsertResult[] results = Database.upsert(patientAdmissions, ple__Patient_Admission__c.Fields.Credible_ID__c, false);
                    
                    List<Error_Log__c> errorLogs = new List<Error_Log__c>();
                    
                    
                    for(Integer i = 0; i < results.size(); i++) {
                        Database.UpsertResult result = results[i];
                        ple__Patient_Admission__c admission = patientAdmissions[i];
                        
                        if(!result.isSuccess()) {
                            List<String> individualErrors = new List<String>();
                            
                            for(Database.Error err : result.getErrors()) {
                                individualErrors.add(err.getMessage());
                            }
                            
                            String combinedErrors = individualErrors.isEmpty() ? 'Unknown Error' : String.join(individualErrors, ', ');
                            
                            errorLogs.add(new Error_Log__c(
                                Error_Type__c = 'Apex',
                                Error_Message__c = combinedErrors,
                                Status__c = 'Failed',
                                Is_Import_Error__c = true,
                                Source_Name__c = 'Credible',
                                Source_Table__c = 'Client',
                                Source_System_Id__c = admission.Credible_ID__c
                            ));
                        }
                    }
                    
                    
                    
                    if(!errorLogs.isEmpty()) {
                        insert errorLogs;
                    }
                }
            }
            else { 
                System.debug('HTTP Request failed with status: ' + res.getStatusCode()); 
                System.debug('Response Body: ' + res.getBody()); 
                Error_Log__c errorLog = new Error_Log__c(
                    Source_Name__c     = 'Credible',
                    Error_Type__c = 'API',                  
                    Error_Message__c = 'Request failed with status: ' + res.getStatusCode() ,
                    Status_Code__c = String.valueOf(res.getStatusCode()),
                    Status__c   = res.getStatus(),
                    Error_Details__c   = res.getBody(),
                    Is_Import_Error__c = true,
                    Source_Table__c = 'Client'
                );
                
                insert errorLog;
            } 
        } catch (Exception e) { 
            List<Error_Log__c> errorLogs = new List<Error_Log__c>();
            try {
                if (res != null && res.getStatusCode() == 200 && !String.isBlank(res.getBody())) { 
                    String responseBody = res.getBody(); 
                    Dom.Document doc = new Dom.Document(); 
                    doc.load(responseBody); 
                    Dom.XMLNode root = doc.getRootElement(); 
                    
                    if (root == null) { 
                        errorLogs.add(new Error_Log__c(
                            Source_Name__c   = 'Credible',
                            Error_Type__c    = 'Apex',
                            Error_Message__c = e.getMessage(),
                            Stack_Trace__c   = e.getStackTraceString(),
                            Status__c        = 'Failed',
                            Is_Import_Error__c = true,
                            Source_Table__c = 'Client'
                        ));
                    } else {
                        Dom.XMLNode diffgramNode = root.getChildElement('diffgram', 'urn:schemas-microsoft-com:xml-diffgram-v1'); 
                        if (diffgramNode == null) { 
                            errorLogs.add(new Error_Log__c(
                                Source_Name__c   = 'Credible',
                                Error_Type__c    = 'Apex',
                                Error_Message__c = e.getMessage(),
                                Stack_Trace__c   = e.getStackTraceString(),
                                Status__c        = 'Failed',
                                Is_Import_Error__c = true,
                                Source_Table__c = 'Client'
                            ));
                        } else {
                            Dom.XMLNode newDataSetNode = diffgramNode.getChildElements().isEmpty() ? null : diffgramNode.getChildElements().get(0); 
                            if (newDataSetNode == null) { 
                                errorLogs.add(new Error_Log__c(
                                    Source_Name__c   = 'Credible',
                                    Error_Type__c    = 'Apex',
                                    Error_Message__c = e.getMessage(),
                                    Stack_Trace__c   = e.getStackTraceString(),
                                    Status__c        = 'Failed',
                                    Is_Import_Error__c = true,
                                    Source_Table__c = 'Client'
                                ));
                            } else {
                                List<Dom.XMLNode> tables = newDataSetNode.getChildElements();
                                if(!tables.isEmpty()){
                                    for (Dom.XMLNode table : tables) { 
                                        String clientId = table.getChildElement('client_id', null) != null && !isDataEncrypted(table.getChildElement('client_id', null).getText())  ? table.getChildElement('client_id', null).getText() : null;		
                                        errorLogs.add(new Error_Log__c(
                                            Source_Name__c   = 'Credible',
                                            Error_Type__c    = 'Apex',
                                            Error_Message__c = e.getMessage(),
                                            Stack_Trace__c   = e.getStackTraceString(),
                                            Status__c        = 'Failed',
                                            Is_Import_Error__c = true,
                                            Source_Table__c = 'Client',
                                            Source_System_Id__c = clientId
                                        ));
                                    }
                                }else{
                                    errorLogs.add(new Error_Log__c(
                                        Source_Name__c   = 'Credible',
                                        Error_Type__c    = 'Apex',
                                        Error_Message__c = e.getMessage(),
                                        Stack_Trace__c   = e.getStackTraceString(),
                                        Status__c        = 'Failed',
                                        Is_Import_Error__c = true,
                                        Source_Table__c = 'Client'
                                    ));
                                }
                            }
                        }
                    }
                } else {
                    errorLogs.add(new Error_Log__c(
                        Source_Name__c   = 'Credible',
                        Error_Type__c    = 'Apex',
                        Error_Message__c = e.getMessage(),
                        Stack_Trace__c   = e.getStackTraceString(),
                        Status__c        = 'Failed',
                        Is_Import_Error__c = true,
                        Source_Table__c = 'Client'
                    ));
                }
            } catch (Exception innerEx) {
                errorLogs.add(new Error_Log__c(
                    Source_Name__c   = 'Credible',
                    Error_Type__c    = 'Apex',
                    Error_Message__c = innerEx.getMessage(),
                    Stack_Trace__c   = innerEx.getStackTraceString(),
                    Status__c        = 'Failed',
                    Is_Import_Error__c = true,
                    Source_Table__c = 'Client'
                ));
                System.debug('Error while preparing error log: ' + innerEx.getMessage());
            }
            
            if (!errorLogs.isEmpty()) {
                insert errorLogs;
            }
            
            System.debug('Line Number: ' + e.getLineNumber());
            System.debug('Exception: ' + e.getMessage());
        }
        
    } 
    
    
    public static void importEmployeeData(String startDate, String endDate, Date customParam1, Date customParam2, String customParam3) { 
        System.debug('Employee data import');
        
        List<Credible_Integration_Config__mdt> configRecord = [SELECT Employee_Export_Connection_String__c FROM Credible_Integration_Config__mdt WHERE DeveloperName = 'Client_Credible_Connection' And Employee_Export_Connection_String__c !=null LIMIT 1];
        if(configRecord.isEmpty()){
            System.debug('No Credible Integration Config Metadata found with a valid Employee Export Connection String.');
            return; 
        }		 
        
        String exportConnection = configRecord[0].Employee_Export_Connection_String__c;
        // String startDateStr = String.valueOf(startDate).split(' ')[0];
        //String endDateStr   = String.valueOf(endDate).split(' ')[0];
        
        String url = Label.Credible_Export_BaseUrl + '?connection=' + EncodingUtil.urlEncode(exportConnection, 'UTF-8') + 
            '&start_date=' + EncodingUtil.urlEncode(startDate != null ? startDate : '', 'UTF-8') + 
            '&end_date=' + EncodingUtil.urlEncode(endDate != null ? endDate : '', 'UTF-8') + 
            '&custom_param1=' + String.valueOf(customParam1) +        // CreatedDate
            '&custom_param2=' + String.valueOf(customParam2) + 		// updatedDate
            '&custom_param3=' + EncodingUtil.urlEncode(customParam3 != null ? customParam3 : '', 'UTF-8'); 
        
        System.debug('Request URL: ' + url); 
        
        HttpRequest req = new HttpRequest(); 
        req.setEndpoint(url); 
        req.setMethod('GET'); 
        req.setTimeout(120000);

        HttpResponse res = new HttpResponse();
        try{
            Http http = new Http(); 
            res = http.send(req); 
            System.debug('HTTP Status Code: ' + res.getStatusCode()); 
            
            if (res.getStatusCode() == 200) { 
                String responseBody = res.getBody(); 
                System.debug('Response Body: ' + responseBody); 
                
                if(String.isBlank(responseBody)) {
                    System.debug('Response body is empty.');
                    return;
                }
                
                
                Dom.Document doc = new Dom.Document(); 
                doc.load(responseBody); 
                Dom.XMLNode root = doc.getRootElement(); 
                
                if (root == null) { 
                    System.debug('No root node found.'); 
                    return; 
                } 
                
                Dom.XMLNode diffgramNode = root.getChildElement('diffgram', 'urn:schemas-microsoft-com:xml-diffgram-v1'); 
                
                if (diffgramNode == null) { 
                    System.debug('No diffgram node found.'); 
                    return; 
                } 
                
                Dom.XMLNode newDataSetNode = diffgramNode.getChildElements().isEmpty() ? null : diffgramNode.getChildElements().get(0); 
                if (newDataSetNode == null) { 
                    System.debug('No NewDataSet node found.'); 
                    return; 
                } 
                
                List<Dom.XMLNode> tables = newDataSetNode.getChildElements(); 
                System.debug('Number of Table records: ' + tables.size()); 
                
                Map<String, String> countyConfigMap = new Map<String, String>(); 
                for (Credible_County_Config__mdt cfg : [SELECT Id, DeveloperName, MasterLabel, County_Code__c FROM Credible_County_Config__mdt]) {
                    countyConfigMap.put(cfg.County_Code__c, cfg.MasterLabel); 
                }
                
                
                EmployeeLookupWrapper el = new EmployeeLookupWrapper();
                
                for(Credible_Lookup__c lookupRecord: [SELECT Id, Credible_Lookup_Id__c, Credible_Table__c, Credible_Value__c,Credible_Lookup_Category__c FROM Credible_Lookup__c WHERE Credible_Table__c INCLUDES ('Employee')]){
                    
                    
                    if(lookupRecord.Credible_Lookup_Category__c == 'State'){
                        el.stateCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Gender'){
                        el.genderCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Employment Status'){
                        el.employmentstatusCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Regional Director'){
                        el.regionalDirectorCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    else if(lookupRecord.Credible_Lookup_Category__c == 'Race OMB'){
                        el.raceCodeMap.put(lookupRecord.Credible_Lookup_Id__c, lookupRecord.Credible_Value__c);
                    }
                    
                }
                Map<String,Contact> conMap = new Map<String,Contact>();
                Set<String> crediableIds = new Set<String>();
                for (Dom.XMLNode table : tables) { 
                    
                      String emailVal = table.getChildElement('email', null) != null ? table.getChildElement('email', null).getText() : '';
                        if (String.isBlank(emailVal) || emailVal.contains('N/A') || !Pattern.matches('^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$', emailVal)) {
                            emailVal = null;
                        }
                    
                    Contact newContact = new Contact(
                        FirstName = table.getChildElement('first_name', null) != null ? table.getChildElement('first_name', null).getText() : '',
                        LastName = table.getChildElement('last_name', null) != null ? table.getChildElement('last_name', null).getText() : '',
                        Email = emailVal,
                        Phone = table.getChildElement('mobile_phone', null) != null ? table.getChildElement('mobile_phone', null).getText() : '',
                        Birthdate = table.getChildElement('dob', null) != null ? Date.valueOf(table.getChildElement('dob', null).getText()) : null,
                        Credible_ID__c = table.getChildElement('emp_id', null) != null ? table.getChildElement('emp_id', null).getText() : '',
                        ple__Contact_Type__c = 'Certified Peer Specialist'
                    );
                    conMap.put(newContact.Credible_ID__c,newContact);
                    crediableIds.add(newContact.Credible_ID__c);
                }
                if(!conMap.isEmpty()){
                    Database.UpsertResult[] results = Database.upsert(conMap.values(), Contact.Fields.Credible_ID__c, false);
                    
                    List<Error_Log__c> errorLogs = new List<Error_Log__c>();
                    
                    List<Contact> conList = (List<Contact>)conMap.values();
                    for(Integer i = 0; i < results.size(); i++) {
                        Database.UpsertResult result = results[i];
                        Contact conObj = conList[i];
                        
                        if(!result.isSuccess()) {
                            List<String> individualErrors = new List<String>();
                            
                            for(Database.Error err : result.getErrors()) {
                                individualErrors.add(err.getMessage());
                            }
                            
                            String combinedErrors = individualErrors.isEmpty() ? 'Unknown Error' : String.join(individualErrors, ', ');
                            
                            errorLogs.add(new Error_Log__c(
                                Error_Type__c = 'Apex',
                                Error_Message__c = combinedErrors,
                                Status__c = 'Failed',
                                Is_Import_Error__c = true,
                                Source_Name__c = 'Credible',
                                Source_Table__c = 'Employee',
                                Source_System_Id__c = conObj.Credible_ID__c
                            ));
                        }
                    }
                    
                    if(!errorLogs.isEmpty()) {
                        insert errorLogs;
                    }
                    
                }
                
                for(Contact conObj : [SELECT Id,Credible_ID__c FROM Contact WHERE Credible_ID__c IN: crediableIds]){
                    conMap.put(conObj.Credible_ID__c,conObj);
                }
                
                List<ple__Employee_Profile__c> employeeProfiles = new List<ple__Employee_Profile__c>();
                for (Dom.XMLNode table : tables) { 
                    
                    String gender = table.getChildElement('gender', null) != null ? table.getChildElement('gender', null).getText() : '';
					String regionalSupportManager = table.getChildElement('dd6', null) != null ? table.getChildElement('dd6', null).getText() : '';
                    String mainCountyWorkedIn = table.getChildElement('dd7', null) != null ? table.getChildElement('dd7', null).getText() : '';
                    String county = table.getChildElement('text1', null) != null ? table.getChildElement('text1', null).getText() : '';
                    String state = table.getChildElement('state', null) != null ? table.getChildElement('state', null).getText() : '';
                    String employmentStatus =  table.getChildElement('dd1', null) != null ? table.getChildElement('dd1', null).getText() : ''; 
                    String race = table.getChildElement('dd12', null) != null ? table.getChildElement('dd12', null).getText() : ''; 
                    ple__Employee_Profile__c employeeProfile = new ple__Employee_Profile__c();
                    employeeProfile.Credible_ID__c	 = table.getChildElement('emp_id', null) != null ? table.getChildElement('emp_id', null).getText() : ''; 
                    employeeProfile.ple__Employee__c = conMap.containskey(employeeProfile.Credible_ID__c) ? conMap.get(employeeProfile.Credible_ID__c).Id : null;
                    employeeProfile.Credible_Employee_First_Name__c = table.getChildElement('first_name', null) != null ? table.getChildElement('first_name', null).getText() : ''; 
                    employeeProfile.Credible_Employee_Middle_Name__c	 =  table.getChildElement('middle_name', null) != null ? table.getChildElement('middle_name', null).getText() : ''; 
                    employeeProfile.Credible_Employee_Last_Name__c		 =   table.getChildElement('last_name', null) != null ? table.getChildElement('last_name', null).getText() : ''; 
                    employeeProfile.Credible_Employee_Preferred_Name__c	 =  table.getChildElement('text24', null) != null ? table.getChildElement('text24', null).getText() : ''; 
                    employeeProfile.Credible_Gender__c =  !String.isBlank(gender) && el.genderCodeMap.containsKey(gender) ?  el.genderCodeMap.get(gender) : '';  
                    employeeProfile.Credible_SSN__c	 =  table.getChildElement('ssn', null) != null ? table.getChildElement('ssn', null).getText() : ''; 
                    employeeProfile.Credible_DOB__c = table.getChildElement('dob', null) != null ? Date.valueOf(table.getChildElement('dob', null).getText()) : null; 
                    employeeProfile.Credible_Title__c	 =  table.getChildElement('title', null) != null ? table.getChildElement('title', null).getText() : ''; 
                    employeeProfile.Credible_address1__c	 = table.getChildElement('address1', null) != null ? table.getChildElement('address1', null).getText() : '';
                    employeeProfile.Credible_address2__c	 = table.getChildElement('address2', null) != null ? table.getChildElement('address2', null).getText() : '';
                    employeeProfile.Credible_City__c	 = table.getChildElement('city', null) != null ? table.getChildElement('city', null).getText() : '';
                    employeeProfile.Credible_State__c	 = !String.isBlank(state) && el.stateCodeMap.containsKey(state) ?  el.stateCodeMap.get(state) : ''; 
                    employeeProfile.Credible_Zip_Code__c = table.getChildElement('zip', null) != null ? table.getChildElement('zip', null).getText() : '';
                    employeeProfile.Credible_County__c	 = !String.isBlank(county) && countyConfigMap.containsKey(county) ?  countyConfigMap.get(county) : '';
                    employeeProfile.Credible_Home_Phone__c = table.getChildElement('home_phone', null) != null ? table.getChildElement('home_phone', null).getText() : '';
                    employeeProfile.Credible_Mobile_Phone__c = table.getChildElement('mobile_phone', null) != null ? table.getChildElement('mobile_phone', null).getText() : ''; 
                    employeeProfile.Credible_Work_Phone__c = table.getChildElement('work_phone', null) != null ? table.getChildElement('work_phone', null).getText() : ''; 
                    employeeProfile.Credible_Email__c = table.getChildElement('email', null) != null ? table.getChildElement('email', null).getText() : ''; 
                    employeeProfile.Credible_Status__c = table.getChildElement('emp_status', null) != null ? table.getChildElement('emp_status', null).getText() : ''; 
                    employeeProfile.Credible_Personal_Email__c = table.getChildElement('text5', null) != null ? table.getChildElement('text5', null).getText() : ''; 
                    employeeProfile.Credible_Employment_Status__c	 = !String.isBlank(employmentStatus) && el.employmentstatusCodeMap.containsKey(employmentStatus) ?  el.employmentstatusCodeMap.get(employmentStatus) : '';
                    employeeProfile.Credible_Emergency_Phone__c	 = table.getChildElement('emergency_phone', null) != null ? table.getChildElement('emergency_phone', null).getText() : ''; 
                    employeeProfile.Credible_Emergency_Contact__c	 = table.getChildElement('emergency_contact', null) != null ? table.getChildElement('emergency_contact', null).getText() : ''; 
                    employeeProfile.Credible_Can_Supervise__c       = table.getChildElement('is_supervisor_flag', null) != null ? Boolean.valueOf(table.getChildElement('is_supervisor_flag', null).getText()) : false;
                    employeeProfile.Credible_Part_Time__c           = table.getChildElement('part_time', null) != null ? Boolean.valueOf(table.getChildElement('part_time', null).getText()) : false;
                    employeeProfile.Credible_Date_Full_Time__c	 = table.getChildElement('date6', null) != null ? Date.valueOf(table.getChildElement('date6', null).getText()) : null; 
                    employeeProfile.Credible_Notes__c	 = table.getChildElement('notes', null) != null ? table.getChildElement('notes', null).getText() : ''; 
                    employeeProfile.Credible_Profile_Code__c	 = table.getChildElement('profile_code', null) != null ? table.getChildElement('profile_code', null).getText() : ''; 
                    employeeProfile.Credible_Id__c	 = table.getChildElement('emp_id', null) != null ? table.getChildElement('emp_id', null).getText() : ''; 
                    employeeProfile.Credible_External_ID__c	 = table.getChildElement('external_id', null) != null ? table.getChildElement('external_id', null).getText() : ''; 
                    employeeProfile.Credible_Username__c	 = table.getChildElement('username', null) != null ? table.getChildElement('username', null).getText() : ''; 
                    employeeProfile.Credible_Date_Last_TimeSheet_Appr__c	 = table.getChildElement('date14', null) != null ? Date.valueOf(table.getChildElement('date14', null).getText()) : null; 
                    employeeProfile.Credible_FBI_Clearance_Date__c	 = table.getChildElement('date4', null) != null ? Date.valueOf(table.getChildElement('date4', null).getText()) : null; 
                    employeeProfile.Credible_Previous_Supervision__c	 = table.getChildElement('date17', null) != null ? Date.valueOf(table.getChildElement('date17', null).getText()) : null; 
                    employeeProfile.Credible_Date_of_Last_Supervision__c	 = table.getChildElement('date11', null) != null ? Date.valueOf(table.getChildElement('date11', null).getText()) : null; 
                    employeeProfile.Credible_Last_Supervised_By__c	 = table.getChildElement('text22', null) != null ? table.getChildElement('text22', null).getText() : ''; 
                    employeeProfile.Credible_ANSA_Expiration_Date__c	 = table.getChildElement('date1', null) != null ? Date.valueOf(table.getChildElement('date1', null).getText()) : null; 
                    employeeProfile.Credible_CPS_Certificate_Date__c	 = table.getChildElement('date2', null) != null ? Date.valueOf(table.getChildElement('date2', null).getText()) : null; 
                    employeeProfile.Credible_CPSS_Certification_Date__c	 = table.getChildElement('date12', null) != null ? Date.valueOf(table.getChildElement('date12', null).getText()) : null; 
                    employeeProfile.Credible_CPS_CRS_training_hrs_due__c	 = table.getChildElement('date3', null) != null ? Date.valueOf(table.getChildElement('date3', null).getText()) : null; 
                    employeeProfile.Credible_CPS_PCB_Exp__c	 = table.getChildElement('date9', null) != null ? Date.valueOf(table.getChildElement('date9', null).getText()) : null; 
                    employeeProfile.Credible_CRS_Certificate_Date__c	 = table.getChildElement('date19', null) != null ? Date.valueOf(table.getChildElement('date19', null).getText()) : null; 
                    employeeProfile.Credible_CRS_PCB_Train_Expiration__c	 = table.getChildElement('date16', null) != null ? Date.valueOf(table.getChildElement('date16', null).getText()) : null; 
                    employeeProfile.Credible_Hire_Date__c	 = table.getChildElement('hire_date', null) != null ? Date.valueOf(table.getChildElement('hire_date', null).getText()) : null; 
                    employeeProfile.Credible_Child_Abuse_Clr_Date__c	 = table.getChildElement('date10', null) != null ? Date.valueOf(table.getChildElement('date10', null).getText()) : null; 
                    employeeProfile.Credible_Child_Abuse_Training__c= table.getChildElement('bool13', null) != null ? Boolean.valueOf(table.getChildElement('bool13', null).getText()) : false;
                    employeeProfile.Credible_Suicide_Screening_Trnging__c = table.getChildElement('bool4', null) != null ? Boolean.valueOf(table.getChildElement('bool4', null).getText()) : false;
                    employeeProfile.Credible_Credentials__c	 = table.getChildElement('credentials', null) != null ? table.getChildElement('credentials', null).getText() : ''; 
                    employeeProfile.Credible_Veteran_Status__c      = table.getChildElement('bool1', null) != null ? Boolean.valueOf(table.getChildElement('bool1', null).getText()) : false;
                    employeeProfile.Credible_Criminal_EPATCH__c	 = table.getChildElement('text10', null) != null ? table.getChildElement('text10', null).getText() : ''; 
                    employeeProfile.Credible_Comments__c	 = table.getChildElement('textlong1', null) != null ? table.getChildElement('textlong1', null).getText() : ''; 
                    employeeProfile.Credible_Term_Date__c	 = table.getChildElement('term_date', null) != null ? Date.valueOf(table.getChildElement('term_date', null).getText()) : null; 
                    employeeProfile.Credible_Is_HR__c               = table.getChildElement('is_hr', null) != null ? Boolean.valueOf(table.getChildElement('is_hr', null).getText()) : false;
                    employeeProfile.Credible_Is_Clinical__c         = table.getChildElement('is_clinical', null) != null ? Boolean.valueOf(table.getChildElement('is_clinical', null).getText()) : false;
                    employeeProfile.Credible_Issued_iPad__c	 = table.getChildElement('text23', null) != null ? table.getChildElement('text23', null).getText() : ''; 
                    employeeProfile.Credible_iPad_Returned__c       = table.getChildElement('bool15', null) != null ? Boolean.valueOf(table.getChildElement('bool15', null).getText()) : false;
                    employeeProfile.Credible_Criminal_History__c    = table.getChildElement('bool5', null) != null ? Boolean.valueOf(table.getChildElement('bool5', null).getText()) : false;
                    employeeProfile.Credible_Regional_Support_Manager__c	 =  !String.isBlank(regionalSupportManager) && el.regionalDirectorCodeMap.containsKey(regionalSupportManager) ?  el.regionalDirectorCodeMap.get(regionalSupportManager) : '';
                    employeeProfile.Credible_HR_Packet_Complete__c  = table.getChildElement('bool10', null) != null ? Boolean.valueOf(table.getChildElement('bool10', null).getText()) : false;
                    employeeProfile.Credible_Main_County_Worked_In__c	 =!String.isBlank(mainCountyWorkedIn) && countyConfigMap.containsKey(mainCountyWorkedIn) ?  countyConfigMap.get(mainCountyWorkedIn) : '';
                    employeeProfile.Credible_LOA_Suspension_Date__c	 = table.getChildElement('date5', null) != null ? Date.valueOf(table.getChildElement('date5', null).getText()) : null; 
                    employeeProfile.Credible_LOA_FMLA_Return_Date__c	 = table.getChildElement('date20', null) != null ? Date.valueOf(table.getChildElement('date20', null).getText()) : null; 
                    employeeProfile.Credible_CPS_Initial_6_Hours_Appro__c	 = table.getChildElement('date15', null) != null ? Date.valueOf(table.getChildElement('date15', null).getText()) : null; 
                    employeeProfile.Credible_CRS_Initial_6_Hours_Appro__c	 = table.getChildElement('date8', null) != null ? Date.valueOf(table.getChildElement('date8', null).getText()) : null; 
                    employeeProfile.Credible_Initial_PCB_App_sent__c= table.getChildElement('bool7', null) != null ? Boolean.valueOf(table.getChildElement('bool7', null).getText()) : false;
                    employeeProfile.Credible_Driver_license_expiration__c	 = table.getChildElement('date13', null) != null ? Date.valueOf(table.getChildElement('date13', null).getText()) : null; 
                    employeeProfile.Credible_Race__c	 =  !String.isBlank(race) &&  el.raceCodeMap.containsKey(race) ?   el.raceCodeMap.get(race) : ''; 
                    employeeProfile.Credible_3_hour_CPSL__c         = table.getChildElement('bool11', null) != null ? Boolean.valueOf(table.getChildElement('bool11', null).getText()) : false;
                    employeeProfile.Credible_401k_Eligible__c       = table.getChildElement('bool9', null) != null ? Boolean.valueOf(table.getChildElement('bool9', null).getText()) : false;
                    employeeProfile.Credible_Date_Created__c	 = table.getChildElement('date_created', null) != null ? Date.valueOf(table.getChildElement('date_created', null).getText()) : null; 
                    employeeProfile.Credible_Date_Updated__c	 = table.getChildElement('date_updated', null) != null ? Date.valueOf(table.getChildElement('date_updated', null).getText()) : null; 
                    employeeProfiles.add(employeeProfile);
                    
                    
                } 
                if(!employeeProfiles.isEmpty()) {
                    System.debug('results '+employeeProfiles.size());
                    Database.UpsertResult[] results = Database.upsert(employeeProfiles, ple__Employee_Profile__c.Fields.Credible_ID__c, false);
                    
                    List<Error_Log__c> errorLogs = new List<Error_Log__c>();
                    
                    
                    for(Integer i = 0; i < results.size(); i++) {
                        Database.UpsertResult result = results[i];
                        ple__Employee_Profile__c employeeProfile = employeeProfiles[i];
                        
                        if(!result.isSuccess()) {
                            List<String> individualErrors = new List<String>();
                            
                            for(Database.Error err : result.getErrors()) {
                                individualErrors.add(err.getMessage());
                            }
                            
                            String combinedErrors = individualErrors.isEmpty() ? 'Unknown Error' : String.join(individualErrors, ', ');
                            
                            errorLogs.add(new Error_Log__c(
                                Error_Type__c = 'Apex',
                                Error_Message__c = combinedErrors,
                                Status__c = 'Failed',
                                Is_Import_Error__c = true,
                                Source_Name__c = 'Credible',
                                Source_Table__c = 'Employee',
                                Source_System_Id__c = employeeProfile.Credible_ID__c
                            ));
                        }
                    }
                    
                    if(!errorLogs.isEmpty()) {
                        insert errorLogs;
                    }
                }
            } else { 
                Error_Log__c errorLog = new Error_Log__c(
                    Source_Name__c     = 'Credible',
                    Error_Type__c = 'API',                  
                    Error_Message__c = 'Request failed with status: ' + res.getStatusCode() ,
                    Status_Code__c = String.valueOf(res.getStatusCode()),
                    Status__c   = res.getStatus(),
                    Error_Details__c   = res.getBody(),
                    Is_Import_Error__c = true,
                    Source_Table__c = 'Employee'
                );
                
                insert errorLog;
                System.debug('HTTP Request failed with status: ' + res.getStatusCode()); 
                System.debug('Response Body: ' + res.getBody()); 
            } 
        } catch (Exception e) { 
            List<Error_Log__c> errorLogs = new List<Error_Log__c>();
            try {
                if (res != null && res.getStatusCode() == 200 && !String.isBlank(res.getBody())) { 
                    String responseBody = res.getBody(); 
                    Dom.Document doc = new Dom.Document(); 
                    doc.load(responseBody); 
                    Dom.XMLNode root = doc.getRootElement(); 
                    
                    if (root == null) { 
                        errorLogs.add(new Error_Log__c(
                            Source_Name__c   = 'Credible',
                            Error_Type__c    = 'Apex',
                            Error_Message__c = e.getMessage(),
                            Stack_Trace__c   = e.getStackTraceString(),
                            Status__c        = 'Failed',
                            Is_Import_Error__c = true,
                            Source_Table__c = 'Employee'
                        ));
                    } else {
                        Dom.XMLNode diffgramNode = root.getChildElement('diffgram', 'urn:schemas-microsoft-com:xml-diffgram-v1'); 
                        if (diffgramNode == null) { 
                            errorLogs.add(new Error_Log__c(
                                Source_Name__c   = 'Credible',
                                Error_Type__c    = 'Apex',
                                Error_Message__c = e.getMessage(),
                                Stack_Trace__c   = e.getStackTraceString(),
                                Status__c        = 'Failed',
                                Is_Import_Error__c = true,
                                Source_Table__c = 'Employee'
                            ));
                        } else {
                            Dom.XMLNode newDataSetNode = diffgramNode.getChildElements().isEmpty() ? null : diffgramNode.getChildElements().get(0); 
                            if (newDataSetNode == null) { 
                                errorLogs.add(new Error_Log__c(
                                    Source_Name__c   = 'Credible',
                                    Error_Type__c    = 'Apex',
                                    Error_Message__c = e.getMessage(),
                                    Stack_Trace__c   = e.getStackTraceString(),
                                    Status__c        = 'Failed',
                                    Is_Import_Error__c = true,
                                    Source_Table__c = 'Employee'
                                ));
                            } else {
                                List<Dom.XMLNode> tables = newDataSetNode.getChildElements();
                                if(!tables.isEmpty()){
                                    for (Dom.XMLNode table : tables) { 
                                        String empId = table.getChildElement('emp_id', null) != null && !isDataEncrypted(table.getChildElement('emp_id', null).getText())  ? table.getChildElement('emp_id', null).getText() : null;		
                                        errorLogs.add(new Error_Log__c(
                                            Source_Name__c   = 'Credible',
                                            Error_Type__c    = 'Apex',
                                            Error_Message__c = e.getMessage(),
                                            Stack_Trace__c   = e.getStackTraceString(),
                                            Status__c        = 'Failed',
                                            Is_Import_Error__c = true,
                                            Source_Table__c = 'Employee',
                                            Source_System_Id__c = empId
                                        ));
                                    }
                                }else{
                                    errorLogs.add(new Error_Log__c(
                                        Source_Name__c   = 'Credible',
                                        Error_Type__c    = 'Apex',
                                        Error_Message__c = e.getMessage(),
                                        Stack_Trace__c   = e.getStackTraceString(),
                                        Status__c        = 'Failed',
                                        Is_Import_Error__c = true,
                                        Source_Table__c = 'Employee'
                                    ));
                                }
                            }
                        }
                    }
                } else {
                    errorLogs.add(new Error_Log__c(
                        Source_Name__c   = 'Credible',
                        Error_Type__c    = 'Apex',
                        Error_Message__c = e.getMessage(),
                        Stack_Trace__c   = e.getStackTraceString(),
                        Status__c        = 'Failed',
                        Is_Import_Error__c = true,
                        Source_Table__c = 'Employee'
                    ));
                }
            } catch (Exception innerEx) {
                errorLogs.add(new Error_Log__c(
                    Source_Name__c   = 'Credible',
                    Error_Type__c    = 'Apex',
                    Error_Message__c = innerEx.getMessage(),
                    Stack_Trace__c   = innerEx.getStackTraceString(),
                    Status__c        = 'Failed',
                    Is_Import_Error__c = true,
                    Source_Table__c = 'Employee'
                ));
                System.debug('Error while preparing error log: ' + innerEx.getMessage());
            }
            
            if (!errorLogs.isEmpty()) {
                insert errorLogs;
            }
            
            System.debug('Line Number: ' + e.getLineNumber());
            System.debug('Exception: ' + e.getMessage());
        }
    } 
    
    private static Boolean isDataEncrypted(String data){
        return Pattern.matches('(?i)^x+$', data);
    }
    
  /*  public class ClientLookupWrapper {
        
        public Map<String, String> peerTypeCodeMap = new Map<String, String>();
        public Map<String, String> stateCodeMap = new Map<String, String>();
        public Map<String, String> livingSituationCodeMap = new Map<String, String>();
        public Map<String, String> preferredContactCodeMap = new Map<String, String>();
        public Map<String, String> raceCodeMap = new Map<String, String>();
        public Map<String, String> ethnicityCodeMap = new Map<String, String>();
        public Map<String, String> preferredLanguageCodeMap = new Map<String, String>();
        public Map<String, String> genderCodeMap = new Map<String, String>();
        public Map<String, String> sexualOrientationCodeMap = new Map<String, String>();
        public Map<String, String> genderIdentityCodeMap = new Map<String, String>();
        public Map<String, String> assignedSexAtBirthCodeMap = new Map<String, String>();
        public Map<String, String> preferredPronounCodeMap = new Map<String, String>();
        public Map<String, String> signatureSourceCodeMap = new Map<String, String>();
        public Map<String, String> releaseInformationCodeMap = new Map<String, String>();
        public Map<String, String> bullyingLastOccurrenceCodeMap = new Map<String, String>();
        public Map<String, String> forensicStatusCodeMap = new Map<String, String>();
        public Map<String, String> smokingStatusCodeMap = new Map<String, String>();
        public Map<String, String> referralSourceCodeMap = new Map<String, String>();
        public Map<String, String> providersCodeMap = new Map<String, String>();
        public Map<String, String> noAdmitReasonCodeMap = new Map<String, String>();
        public Map<String, String> domainFocusAreaScoresCodeMap = new Map<String, String>();
        public Map<String, String> staffPeerInvolvementCodeMap = new Map<String, String>();
         public Map<String, String> maritalStatusCodeMap = new Map<String, String>();
    } */
    
    
    public class EmployeeLookupWrapper {
        public Map<String, String> genderCodeMap = new Map<String, String>();
        public Map<String, String> stateCodeMap = new Map<String, String>();
        public Map<String, String> employmentstatusCodeMap = new Map<String, String>();
        public Map<String, String> raceCodeMap = new Map<String, String>();
        public Map<String, String> regionalDirectorCodeMap = new Map<String, String>();
    }
    
    
 
    
    /*   public static void exportAuthorizationsData(Date startDate, Date endDate, String customParam1, String customParam2, String customParam3) { 
System.debug('Authorization data export');

// Connection string 
List<Credible_Integration_Config__mdt> configRecord = [SELECT Authorization_Export_Connection_String__c	 FROM Credible_Integration_Config__mdt WHERE DeveloperName = 'Client_Credible_Connection' And Authorization_Export_Connection_String__c	 !=null LIMIT 1];
if(configRecord.isEmpty()){
System.debug('No Credible Integration Config Metadata found with a valid Authorization Export Connection String.');
return; 
}
String exportConnection = configRecord[0].Authorization_Export_Connection_String__c;


String startDateStr = startDate!=null ? String.valueOf(startDate).split(' ')[0] : ''; 
String endDateStr = endDate != null ? String.valueOf(endDate).split(' ')[0] : ''; 

String url = Label.Credible_Export_BaseUrl + '?connection=' + EncodingUtil.urlEncode(exportConnection, 'UTF-8') + 
'&start_date=' + EncodingUtil.urlEncode(startDateStr, 'UTF-8') + 
'&end_date=' + EncodingUtil.urlEncode(endDateStr, 'UTF-8') + 
'&custom_param1=' + customParam1 + 
'&custom_param2=' + EncodingUtil.urlEncode(customParam2 != null ? customParam2 : '', 'UTF-8') + 
'&custom_param3=' + EncodingUtil.urlEncode(customParam3 != null ? customParam3 : '', 'UTF-8'); 

System.debug('URL: ' + url); 

HttpRequest req = new HttpRequest(); 
req.setEndpoint(url); 
req.setMethod('GET'); 

try{
Http http = new Http(); 
HttpResponse res = http.send(req); 
System.debug('HTTP Status Code: ' + res.getStatusCode()); 

if (res.getStatusCode() == 200) { 
String responseBody = res.getBody(); 
System.debug('Response Body: ' + responseBody); 

if(String.isBlank(responseBody)) {
System.debug('Response body is empty.');
return;
}                
Dom.Document doc = new Dom.Document(); 
doc.load(responseBody); 
Dom.XMLNode root = doc.getRootElement(); 

if (root == null) { 
System.debug('No root node found.'); 
return; 
} 
Dom.XMLNode diffgramNode = root.getChildElement('diffgram', 'urn:schemas-microsoft-com:xml-diffgram-v1'); 

if (diffgramNode == null) { 
System.debug('No diffgram node found.'); 
return; 
} 

Dom.XMLNode newDataSetNode = diffgramNode.getChildElements().isEmpty() ? null : diffgramNode.getChildElements().get(0); 
if (newDataSetNode == null) { 
System.debug('No NewDataSet node found.'); 
return; 
} 

List<Dom.XMLNode> tables = newDataSetNode.getChildElements(); 
System.debug('Number of Table records: ' + tables.size()); 

for (Dom.XMLNode table : tables) { 
String authId = table.getChildElement('auth_id', null)?.getText(); 
String authDate = table.getChildElement('auth_date', null)?.getText(); 
String clientId = table.getChildElement('client_id', null)?.getText(); 
System.debug('Authorization  ID: ' + authId + ', Authorization Date: ' + authDate + ' Client Id : ' + clientId ); 
} 
}   
else { 
System.debug('HTTP Request failed with status: ' + res.getStatusCode()); 
System.debug('Response Body: ' + res.getBody()); 
} 
} catch (Exception e) { 
System.debug('Exception: ' + e.getMessage()); 
return; 
} 
} */

    public static void importClientVisitData(String startDate, String endDate, Date customParam1, Date customParam2, String customParam3) {
    System.debug('ClientVisit Data Import');
        
    Map<String,Id> mapToStoreClientIdToPA = new Map<String,Id>();
    Map<String,Id> mapToStoreEmpIdToEP = new Map<String,Id>();
    Set<String> setToStoreClientId = new Set<String>();
    Set<String> setToStoreEmpId = new Set<String>();
    
    List<Credible_Integration_Config__mdt> configRecord = [SELECT ClientVisit_Export_Connection_String__c FROM Credible_Integration_Config__mdt WHERE DeveloperName = 'Client_Credible_Connection' AND ClientVisit_Export_Connection_String__c != null LIMIT 1];
    if(configRecord.isEmpty()){
        System.debug('No Credible Integration Config Metadata found with a valid Client Export Connection String.');
        return; 
    }
    
    String exportConnection = configRecord[0].ClientVisit_Export_Connection_String__c;
    
    String url = Label.Credible_Export_BaseUrl + '?connection=' + EncodingUtil.urlEncode(exportConnection, 'UTF-8') + 
        '&start_date=' + EncodingUtil.urlEncode(startDate != null ? startDate : '', 'UTF-8') + 
        '&end_date=' + EncodingUtil.urlEncode(endDate != null ? endDate : '', 'UTF-8') + 
        '&custom_param1=' + String.valueOf(customParam1) +        // CreatedDate
        '&custom_param2=' + String.valueOf(customParam2) + 		// updatedDate
        '&custom_param3=' + EncodingUtil.urlEncode(customParam3 != null ? customParam3 : '', 'UTF-8'); 
    
    System.debug('URL: ' + url); 
    
    HttpRequest req = new HttpRequest(); 
    req.setEndpoint(url); 
    req.setMethod('GET'); 
    req.setTimeout(120000);
    
    HttpResponse res = new HttpResponse();
    try {
        Http http = new Http(); 
        res = http.send(req); 
        System.debug('HTTP Status Code: ' + res.getStatusCode()); 
        
        if (res.getStatusCode() == 200) { 
            String responseBody = res.getBody(); 
            //System.debug('Response Body: ' + responseBody); 
            
            if(String.isBlank(responseBody)) {
                System.debug('Response body is empty.');
                return;
            }
            
            Dom.Document doc = new Dom.Document(); 
            doc.load(responseBody); 
            Dom.XMLNode root = doc.getRootElement(); 
            
            if (root == null) { 
                System.debug('No root node found.'); 
                return; 
            } 
            
            Dom.XMLNode diffgramNode = root.getChildElement('diffgram', 'urn:schemas-microsoft-com:xml-diffgram-v1'); 
            
            if (diffgramNode == null) { 
                System.debug('No diffgram node found.'); 
                return; 
            } 
            
            Dom.XMLNode newDataSetNode = diffgramNode.getChildElements().isEmpty() ? null : diffgramNode.getChildElements().get(0); 
            if (newDataSetNode == null) { 
                System.debug('No NewDataSet node found.'); 
                return; 
            } 
            
            List<Dom.XMLNode> tables = newDataSetNode.getChildElements(); 
            System.debug('Number of Table records: ' + tables.size()); 
            
            List<ple__Appointment__c> credibleVisits = new List<ple__Appointment__c>();
            
            for (Dom.XMLNode table : tables) { 
                ple__Appointment__c visit = new ple__Appointment__c();
                
                // Direct field mapping from XML to Credible_Visit object
                visit.Credible_Clientvisit_Id__c = table.getChildElement('clientvisit_id', null) != null ? table.getChildElement('clientvisit_id', null).getText() : '';
                visit.Credible_Client_Id__c = table.getChildElement('client_id', null) != null ? table.getChildElement('client_id', null).getText() : '';
                visit.Credible_Emp_Id__c = table.getChildElement('emp_id', null) != null ? table.getChildElement('emp_id', null).getText() : '';
                if(!String.isBlank(visit.Credible_Client_Id__c)){
                    setToStoreClientId.add(visit.Credible_Client_Id__c);
                }
                if(!String.isBlank(visit.Credible_Emp_Id__c)){
                    setToStoreEmpId.add(visit.Credible_Emp_Id__c);
                }
                
                visit.Credible_By_Emp_Id__c = table.getChildElement('by_emp_id', null) != null ? table.getChildElement('by_emp_id', null).getText() : '';
                visit.Credible_Program_Id__c = table.getChildElement('program_code', null) != null ? table.getChildElement('program_code', null).getText() : '';
                visit.Credible_Visittype_Id__c = table.getChildElement('visittype_id', null) != null ? table.getChildElement('visittype_id', null).getText() : '';
                visit.Credible_Visittype__c = table.getChildElement('visittype', null) != null ? table.getChildElement('visittype', null).getText() : '';
                visit.Credible_CPT_Code__c = table.getChildElement('cptcode', null) != null ? table.getChildElement('cptcode', null).getText() : '';
                visit.Credible_Location_Id__c = table.getChildElement('location_code', null) != null ? table.getChildElement('location_code', null).getText() : '';
                visit.Credible_Matrix_Id__c = table.getChildElement('matrix_id', null) != null ? table.getChildElement('matrix_id', null).getText() : '';
                visit.Credible_Status__c = table.getChildElement('status', null) != null ? table.getChildElement('status', null).getText() : '';
                visit.Credible_Rev_Timein__c = table.getChildElement('rev_timein', null) != null ? parseDateTime(table.getChildElement('rev_timein', null).getText()) : null;
                visit.Credible_Rev_Timeout__c = table.getChildElement('rev_timeout', null) != null ? parseDateTime(table.getChildElement('rev_timeout', null).getText()) : null;
                visit.Credible_Duration__c = table.getChildElement('duration', null) != null ? Integer.valueOf(table.getChildElement('duration', null).getText()) : null;
                visit.Credible_Transfer_Date__c = table.getChildElement('transfer_date', null) != null ? parseDateTime(table.getChildElement('transfer_date', null).getText()) : null;
                visit.Credible_Non_Billable__c = table.getChildElement('non_billable', null) != null ? Boolean.valueOf(table.getChildElement('non_billable', null).getText()) : false;
                visit.Credible_Client_First_Name__c = table.getChildElement('clientfirstname', null) != null ? table.getChildElement('clientfirstname', null).getText() : '';
                visit.Credible_Client_Last_Name__c = table.getChildElement('clientlastname', null) != null ? table.getChildElement('clientlastname', null).getText() : '';
                visit.Credible_Emp_Name__c = table.getChildElement('emp_name', null) != null ? table.getChildElement('emp_name', null).getText() : '';
                visit.Credible_Rate__c = table.getChildElement('rate', null) != null ? Decimal.valueOf(table.getChildElement('rate', null).getText()) : null;
                visit.Credible_Contract_Rate__c = table.getChildElement('contract_rate', null) != null ? Decimal.valueOf(table.getChildElement('contract_rate', null).getText()) : null;
                visit.Credible_Units_Of_Svc__c = table.getChildElement('units_of_svc', null) != null ? Decimal.valueOf(table.getChildElement('units_of_svc', null).getText()) : null;
                visit.Credible_Recipient_Id__c = table.getChildElement('recipient_code', null) != null ? table.getChildElement('recipient_code', null).getText() : '';
                visit.Credible_Form_Ver_Id__c = table.getChildElement('form_ver_id', null) != null ? table.getChildElement('form_ver_id', null).getText() : '';
                visit.Credible_Auth_Id__c = table.getChildElement('auth_id', null) != null ? table.getChildElement('auth_id', null).getText() : '';
                visit.Credible_Appr__c = table.getChildElement('appr', null) != null ? Boolean.valueOf(table.getChildElement('appr', null).getText()) : false;
                visit.Credible_Comb_Primary__c = table.getChildElement('comb_primary', null) != null ? Boolean.valueOf(table.getChildElement('comb_primary', null).getText()) : false;
                visit.Credible_Comb_Secondary__c = table.getChildElement('comb_secondary', null) != null ? Boolean.valueOf(table.getChildElement('comb_secondary', null).getText()) : false;
                visit.Credible_Comb_Parent_Id__c = table.getChildElement('comb_parent_id', null) != null ? table.getChildElement('comb_parent_id', null).getText() : '';
                visit.Credible_Comb_Timeout__c = table.getChildElement('comb_timeout', null) != null ? parseDateTime(table.getChildElement('comb_timeout', null).getText()) : null;
                visit.Credible_Comb_Duration__c = table.getChildElement('comb_duration', null) != null ? Integer.valueOf(table.getChildElement('comb_duration', null).getText()) : null;
                visit.Credible_Comb_Units__c = table.getChildElement('comb_units', null) != null ? Decimal.valueOf(table.getChildElement('comb_units', null).getText()) : null;
                visit.Credible_Comb_Rate__c = table.getChildElement('comb_rate', null) != null ? Decimal.valueOf(table.getChildElement('comb_rate', null).getText()) : null;
                visit.Credible_Multiple_Flag__c = table.getChildElement('multiple_flag', null) != null ? Boolean.valueOf(table.getChildElement('multiple_flag', null).getText()) : false;
                visit.Credible_Plan_Id__c = table.getChildElement('plan_id', null) != null ? table.getChildElement('plan_id', null).getText() : '';
                visit.Credible_Team_Id__c = table.getChildElement('team_name', null) != null ? table.getChildElement('team_name', null).getText() : '';
                visit.Credible_Timein__c = table.getChildElement('timein', null) != null ? parseDateTime(table.getChildElement('timein', null).getText()) : null;
                visit.Credible_Timeout__c = table.getChildElement('timeout', null) != null ? parseDateTime(table.getChildElement('timeout', null).getText()) : null;
                visit.Credible_Visit_Dateday__c = table.getChildElement('visit_dateday', null) != null ? Integer.valueOf(table.getChildElement('visit_dateday', null).getText()) : null;
                visit.Credible_Visitguid__c = table.getChildElement('visitguid', null) != null ? table.getChildElement('visitguid', null).getText() : '';
                visit.Credible_Credentials__c = table.getChildElement('credentials', null) != null ? table.getChildElement('credentials', null).getText() : '';
                visit.Credible_Signature_Datetime__c = table.getChildElement('signature_datetime', null) != null ? parseDateTime(table.getChildElement('signature_datetime', null).getText()) : null;
                visit.Credible_Billing_Group_Id__c = table.getChildElement('billing_group_name', null) != null ? table.getChildElement('billing_group_name', null).getText() : '';
                visit.Credible_Appr_Date__c = table.getChildElement('appr_date', null) != null ? parseDateTime(table.getChildElement('appr_date', null).getText()) : null;
                visit.Credible_Appr_User__c = table.getChildElement('appr_user', null) != null ? table.getChildElement('appr_user', null).getText() : '';
                visit.Credible_Appr_Emp_Id__c = table.getChildElement('appr_emp_id', null) != null ? table.getChildElement('appr_emp_id', null).getText() : '';
                visit.Credible_CPT_Modifier_1__c = table.getChildElement('cpt_modifier1', null) != null ? table.getChildElement('cpt_modifier1', null).getText() : '';
                visit.Credible_CPT_Modifier_2__c = table.getChildElement('cpt_modifier2', null) != null ? table.getChildElement('cpt_modifier2', null).getText() : '';
                visit.Credible_CPT_Modifier_3__c = table.getChildElement('cpt_modifier3', null) != null ? table.getChildElement('cpt_modifier3', null).getText() : '';
                visit.Credible_CPT_Modifier_4__c = table.getChildElement('cpt_modifier4', null) != null ? table.getChildElement('cpt_modifier4', null).getText() : '';
                visit.Credible_Is_Emergency__c = table.getChildElement('is_emergency', null) != null ? table.getChildElement('is_emergency', null).getText() : '';
                visit.Credible_Cotherapist__c = table.getChildElement('cotherapist', null) != null ? table.getChildElement('cotherapist', null).getText() : '';
                visit.Credible_Unscheduled__c = table.getChildElement('unscheduled', null) != null ? Boolean.valueOf(table.getChildElement('unscheduled', null).getText()) : false;
                visit.Credible_Auth_Exceeded__c = table.getChildElement('auth_exceeded', null) != null ? Boolean.valueOf(table.getChildElement('auth_exceeded', null).getText()) : false;
                visit.Credible_Has_Picture__c = table.getChildElement('has_picture', null) != null ? Boolean.valueOf(table.getChildElement('has_picture', null).getText()) : false;
                visit.Credible_Is_Readonly__c = table.getChildElement('is_readonly', null) != null ? Boolean.valueOf(table.getChildElement('is_readonly', null).getText()) : false;
                visit.Credible_Is_Multistage_Appr__c = table.getChildElement('is_multistage_appr', null) != null ? Boolean.valueOf(table.getChildElement('is_multistage_appr', null).getText()) : false;
                visit.Credible_Approvalrole_Id__c = table.getChildElement('approvalrole_id', null) != null ? table.getChildElement('approvalrole_id', null).getText() : '';
                visit.Credible_Exportbatch_Id__c = table.getChildElement('exportbatch_id', null) != null ? table.getChildElement('exportbatch_id', null).getText() : '';
                visit.Credible_Rem_Address__c = table.getChildElement('rem_address', null) != null ? table.getChildElement('rem_address', null).getText() : '';
                visit.Credible_Source__c = table.getChildElement('source', null) != null ? table.getChildElement('source', null).getText() : '';
                visit.Credible_Notes__c = table.getChildElement('notes', null) != null ? table.getChildElement('notes', null).getText() : '';
                visit.Credible_Reviewer_Comment__c = table.getChildElement('reviewer_comment', null) != null ? table.getChildElement('reviewer_comment', null).getText() : '';
                visit.Credible_Signature_Cnt__c = table.getChildElement('signature_cnt', null) != null ? Integer.valueOf(table.getChildElement('signature_cnt', null).getText()) : null;
                visit.Credible_Handheld_Version__c = table.getChildElement('handheld_version', null) != null ? table.getChildElement('handheld_version', null).getText() : '';
                visit.Credible_Overproduction_Units__c = table.getChildElement('overproduction_units', null) != null ? Decimal.valueOf(table.getChildElement('overproduction_units', null).getText()) : null;
                visit.Credible_Episode_Id__c = table.getChildElement('episode_id', null) != null ? table.getChildElement('episode_id', null).getText() : '';
                visit.Credible_Bill_Rendering_Id__c = table.getChildElement('bill_rendering_id', null) != null ? table.getChildElement('bill_rendering_id', null).getText() : '';
                visit.Credible_Cat_Completed__c = table.getChildElement('cat_completed', null) != null ? table.getChildElement('cat_completed', null).getText() : '';
                visit.Credible_Tx_Id__c = table.getChildElement('tx_id', null) != null ? table.getChildElement('tx_id', null).getText() : '';
                visit.Credible_Splitsecondary_Clientvisit_Id__c = table.getChildElement('splitsecondary_clientvisit_id', null) != null ? table.getChildElement('splitsecondary_clientvisit_id', null).getText() : '';
                visit.Credible_Splitprimary_Clientvisit_Id__c = table.getChildElement('splitprimary_clientvisit_id', null) != null ? table.getChildElement('splitprimary_clientvisit_id', null).getText() : '';
                visit.Credible_Axis_Code__c = table.getChildElement('axis_code', null) != null ? table.getChildElement('axis_code', null).getText() : '';
                visit.Credible_Clientaxisdetail_Id__c = table.getChildElement('clientaxisdetail_id', null) != null ? table.getChildElement('clientaxisdetail_id', null).getText() : '';
                visit.Credible_Manual_Redx__c = table.getChildElement('manual_redx', null) != null ? Boolean.valueOf(table.getChildElement('manual_redx', null).getText()) : false;
                visit.Credible_Manual_Redx_Note__c = table.getChildElement('manual_redx_note', null) != null ? table.getChildElement('manual_redx_note', null).getText() : '';
                visit.Credible_Manual_Update_To_Modifier__c = table.getChildElement('manual_update_to_modifier', null) != null ? Boolean.valueOf(table.getChildElement('manual_update_to_modifier', null).getText()) : false;
                visit.Credible_Overlapped_Primary_Id__c = table.getChildElement('overlapped_primary_id', null) != null ? table.getChildElement('overlapped_primary_id', null).getText() : '';
                visit.Credible_Subtract_Overlapping__c = table.getChildElement('subtract_overlapping', null) != null ? Boolean.valueOf(table.getChildElement('subtract_overlapping', null).getText()) : false;
                visit.Credible_Is_Incident_Form__c = table.getChildElement('is_incident_form', null) != null ? Boolean.valueOf(table.getChildElement('is_incident_form', null).getText()) : false;
                visit.Credible_Is_Late__c = table.getChildElement('is_late', null) != null ? Boolean.valueOf(table.getChildElement('is_late', null).getText()) : false;
                visit.Credible_Bedboardbed_Id__c = table.getChildElement('bedboardbed_id', null) != null ? table.getChildElement('bedboardbed_id', null).getText() : '';
                visit.Credible_Clientbedboardinterval_Id__c = table.getChildElement('clientbedboardinterval_id', null) != null ? table.getChildElement('clientbedboardinterval_id', null).getText() : '';
                visit.Credible_Fosterhome_Id__c = table.getChildElement('fosterhome_id', null) != null ? table.getChildElement('fosterhome_id', null).getText() : '';
                visit.Credible_Fosterhomeinterval_Id__c = table.getChildElement('fosterhomeinterval_id', null) != null ? table.getChildElement('fosterhomeinterval_id', null).getText() : '';
                visit.Credible_Cloned_Clientvisit_Id__c = table.getChildElement('cloned_clientvisit_id', null) != null ? table.getChildElement('cloned_clientvisit_id', null).getText() : '';
                visit.Credible_Reprocess_For_Payroll__c = table.getChildElement('reprocess_for_payroll', null) != null ? Boolean.valueOf(table.getChildElement('reprocess_for_payroll', null).getText()) : false;
                visit.Credible_Formgroup_Incomplete__c = table.getChildElement('formgroup_incomplete', null) != null ? Boolean.valueOf(table.getChildElement('formgroup_incomplete', null).getText()) : false;
                visit.Credible_Formgroup_Id__c = table.getChildElement('formgroup_id', null) != null ? table.getChildElement('formgroup_id', null).getText() : '';
                visit.Credible_Pcp_Provider_Id__c = table.getChildElement('pcp_provider_id', null) != null ? table.getChildElement('pcp_provider_id', null).getText() : '';
                visit.Credible_Guarantor_Dependent_Id__c = table.getChildElement('guarantor_dependent_id', null) != null ? table.getChildElement('guarantor_dependent_id', null).getText() : '';
                visit.Credible_Auth_Level__c = table.getChildElement('auth_level', null) != null ? table.getChildElement('auth_level', null).getText() : '';
                visit.Credible_Submission_Reason_Code__c = table.getChildElement('submission_reason_code', null) != null ? table.getChildElement('submission_reason_code', null).getText() : '';
                visit.Credible_Text_1__c = table.getChildElement('text1', null) != null ? table.getChildElement('text1', null).getText() : '';
                visit.Credible_Text_2__c = table.getChildElement('text2', null) != null ? table.getChildElement('text2', null).getText() : '';
                visit.Credible_Text_3__c = table.getChildElement('text3', null) != null ? table.getChildElement('text3', null).getText() : '';
                visit.Credible_Bool_1__c = table.getChildElement('bool1', null) != null ? Boolean.valueOf(table.getChildElement('bool1', null).getText()) : false;
                visit.Credible_Bool_2__c = table.getChildElement('bool2', null) != null ? Boolean.valueOf(table.getChildElement('bool2', null).getText()) : false;
                visit.Credible_Bool_3__c = table.getChildElement('bool3', null) != null ? Boolean.valueOf(table.getChildElement('bool3', null).getText()) : false;
                visit.Credible_Date_1__c = table.getChildElement('date1', null) != null ? parseDateTime(table.getChildElement('date1', null).getText()) : null;
                visit.Credible_Date_2__c = table.getChildElement('date2', null) != null ? parseDateTime(table.getChildElement('date2', null).getText()) : null;
                visit.Credible_Date_3__c = table.getChildElement('date3', null) != null ? parseDateTime(table.getChildElement('date3', null).getText()) : null;
                visit.Credible_Num_1__c = table.getChildElement('num1', null) != null ? Integer.valueOf(table.getChildElement('num1', null).getText()) : null;
                visit.Credible_Num_2__c = table.getChildElement('num2', null) != null ? Integer.valueOf(table.getChildElement('num2', null).getText()) : null;
                visit.Credible_Num_3__c = table.getChildElement('num3', null) != null ? Integer.valueOf(table.getChildElement('num3', null).getText()) : null;
                visit.Credible_Date_Created__c = table.getChildElement('date_created', null) != null ? parseDateTime(table.getChildElement('date_created', null).getText()) : null;
                visit.Credible_Date_Updated__c = table.getChildElement('date_updated', null) != null ? parseDateTime(table.getChildElement('date_updated', null).getText()) : null;
                visit.Credible_Non_Release__c = table.getChildElement('non_release', null) != null ? Boolean.valueOf(table.getChildElement('non_release', null).getText()) : false;
                visit.Credible_Cascaded_Units__c = table.getChildElement('cascaded_units', null) != null ? Decimal.valueOf(table.getChildElement('cascaded_units', null).getText()) : null;
                visit.Credible_Cascaded_Comb_Units__c = table.getChildElement('cascaded_comb_units', null) != null ? Decimal.valueOf(table.getChildElement('cascaded_comb_units', null).getText()) : null;
                visit.Credible_Cascaded_Payer_Id__c = table.getChildElement('cascaded_payer_id', null) != null ? table.getChildElement('cascaded_payer_id', null).getText() : '';
                visit.Credible_Overproduction_Id__c = table.getChildElement('overproduction_id', null) != null ? table.getChildElement('overproduction_id', null).getText() : '';
                visit.Credible_Summary_Notes__c = table.getChildElement('summary_notes', null) != null ? table.getChildElement('summary_notes', null).getText() : '';
                visit.Credible_Timeframes__c = table.getChildElement('timeframes', null) != null ? table.getChildElement('timeframes', null).getText() : '';
                visit.Credible_Reserve_Auth_Id__c = table.getChildElement('reserve_auth_id', null) != null ? table.getChildElement('reserve_auth_id', null).getText() : '';
                visit.Credible_Axis_Code_2__c = table.getChildElement('axis_code2', null) != null ? table.getChildElement('axis_code2', null).getText() : '';
                visit.Credible_Axis_Code_3__c = table.getChildElement('axis_code3', null) != null ? table.getChildElement('axis_code3', null).getText() : '';
                visit.Credible_Axis_Code_4__c = table.getChildElement('axis_code4', null) != null ? table.getChildElement('axis_code4', null).getText() : '';
                visit.Credible_Axis_Code_5__c = table.getChildElement('axis_code5', null) != null ? table.getChildElement('axis_code5', null).getText() : '';
                visit.Credible_Release_Auth_Id__c = table.getChildElement('release_auth_id', null) != null ? table.getChildElement('release_auth_id', null).getText() : '';
                visit.Credible_Comb_On_Secondary__c = table.getChildElement('comb_on_secondary', null) != null ? Boolean.valueOf(table.getChildElement('comb_on_secondary', null).getText()) : false;
                visit.Credible_Txplus_Id__c = table.getChildElement('txplus_id', null) != null ? table.getChildElement('txplus_id', null).getText() : '';
                visit.Credible_Gcode_Primary_Clientvisit_Id__c = table.getChildElement('gcode_primary_clientvisit_id', null) != null ? table.getChildElement('gcode_primary_clientvisit_id', null).getText() : '';
                visit.Credible_Gcode_Secondary_Clientvisit_Id__c = table.getChildElement('gcode_secondary_clientvisit_id', null) != null ? table.getChildElement('gcode_secondary_clientvisit_id', null).getText() : '';
                visit.Credible_External_Id__c = table.getChildElement('external_id', null) != null ? table.getChildElement('external_id', null).getText() : '';
                visit.Credible_Text_4__c = table.getChildElement('text4', null) != null ? table.getChildElement('text4', null).getText() : '';
                visit.Credible_Text_5__c = table.getChildElement('text5', null) != null ? table.getChildElement('text5', null).getText() : '';
                visit.Credible_Text_6__c = table.getChildElement('text6', null) != null ? table.getChildElement('text6', null).getText() : '';
                visit.Credible_Schedule_Id__c = table.getChildElement('schedule_id', null) != null ? table.getChildElement('schedule_id', null).getText() : '';
                visit.Credible_Transfer_Date_UTC__c = table.getChildElement('transfer_date_utc', null) != null ? parseDateTime(table.getChildElement('transfer_date_utc', null).getText()) : null;
                visit.Credible_Signature_Datetime_UTC__c = table.getChildElement('signature_datetime_utc', null) != null ? parseDateTime(table.getChildElement('signature_datetime_utc', null).getText()) : null;
                visit.Credible_Date_Created_UTC__c = table.getChildElement('date_created_utc', null) != null ? parseDateTime(table.getChildElement('date_created_utc', null).getText()) : null;
                visit.Credible_Date_Updated_UTC__c = table.getChildElement('date_updated_utc', null) != null ? parseDateTime(table.getChildElement('date_updated_utc', null).getText()) : null;
                visit.Credible_Em_Code__c = table.getChildElement('em_code', null) != null ? table.getChildElement('em_code', null).getText() : '';
                visit.Credible_Cascaded_Rate__c = table.getChildElement('cascaded_rate', null) != null ? Decimal.valueOf(table.getChildElement('cascaded_rate', null).getText()) : null;
                visit.Credible_Cascaded_Comb_Rate__c = table.getChildElement('cascaded_comb_rate', null) != null ? Decimal.valueOf(table.getChildElement('cascaded_comb_rate', null).getText()) : null;
                visit.Credible_Reason_For_Visit__c = table.getChildElement('reason_for_visit', null) != null ? table.getChildElement('reason_for_visit', null).getText() : '';
                visit.Credible_Deleted_Diagnosis__c = table.getChildElement('deleted_diagnosis', null) != null ? table.getChildElement('deleted_diagnosis', null).getText() : '';
                visit.Credible_Chief_Complaint__c = table.getChildElement('chief_complaint', null) != null ? table.getChildElement('chief_complaint', null).getText() : '';
                visit.Credible_Unit_Timein__c = table.getChildElement('unit_timein', null) != null ? parseDateTime(table.getChildElement('unit_timein', null).getText()) : null;
                visit.Credible_Unit_Timeout__c = table.getChildElement('unit_timeout', null) != null ? parseDateTime(table.getChildElement('unit_timeout', null).getText()) : null;
                visit.Credible_Is_Episodeforced__c = table.getChildElement('is_episodeforced', null) != null ? Boolean.valueOf(table.getChildElement('is_episodeforced', null).getText()) : false;
                visit.Credible_Clientaxisdetail_Id_2__c = table.getChildElement('clientaxisdetail_id2', null) != null ? table.getChildElement('clientaxisdetail_id2', null).getText() : '';
                visit.Credible_Clientaxisdetail_Id_3__c = table.getChildElement('clientaxisdetail_id3', null) != null ? table.getChildElement('clientaxisdetail_id3', null).getText() : '';
                visit.Credible_Clientaxisdetail_Id_4__c = table.getChildElement('clientaxisdetail_id4', null) != null ? table.getChildElement('clientaxisdetail_id4', null).getText() : '';
                visit.Credible_Clientaxisdetail_Id_5__c = table.getChildElement('clientaxisdetail_id5', null) != null ? table.getChildElement('clientaxisdetail_id5', null).getText() : '';
                visit.Credible_ICD10_Code__c = table.getChildElement('icd10_code', null) != null ? table.getChildElement('icd10_code', null).getText() : '';
                visit.Credible_ICD10_Code_2__c = table.getChildElement('icd10_code2', null) != null ? table.getChildElement('icd10_code2', null).getText() : '';
                visit.Credible_ICD10_Code_3__c = table.getChildElement('icd10_code3', null) != null ? table.getChildElement('icd10_code3', null).getText() : '';
                visit.Credible_ICD10_Code_4__c = table.getChildElement('icd10_code4', null) != null ? table.getChildElement('icd10_code4', null).getText() : '';
                visit.Credible_ICD10_Code_5__c = table.getChildElement('icd10_code5', null) != null ? table.getChildElement('icd10_code5', null).getText() : '';
                visit.Credible_Ordering_Provider_Id__c = table.getChildElement('ordering_provider_id', null) != null ? table.getChildElement('ordering_provider_id', null).getText() : '';
                visit.Credible_Ordering_Provider_Id_External__c = table.getChildElement('ordering_provider_id_external', null) != null ? table.getChildElement('ordering_provider_id_external', null).getText() : '';
                visit.Credible_Billing_Supervisor_Emp_Id__c = table.getChildElement('billing_supervisor_emp_id', null) != null ? table.getChildElement('billing_supervisor_emp_id', null).getText() : '';
                visit.Credible_Rate_Per_Unit__c = table.getChildElement('rate_per_unit', null) != null ? Decimal.valueOf(table.getChildElement('rate_per_unit', null).getText()) : null;
                visit.Credible_Appr_Date_UTC__c = table.getChildElement('appr_date_utc', null) != null ? parseDateTime(table.getChildElement('appr_date_utc', null).getText()) : null;
                visit.Credible_Timein_UTC__c = table.getChildElement('timein_utc', null) != null ? parseDateTime(table.getChildElement('timein_utc', null).getText()) : null;
                visit.Credible_Timeout_UTC__c = table.getChildElement('timeout_utc', null) != null ? parseDateTime(table.getChildElement('timeout_utc', null).getText()) : null;
                visit.Credible_Rev_Timein_UTC__c = table.getChildElement('rev_timein_utc', null) != null ? parseDateTime(table.getChildElement('rev_timein_utc', null).getText()) : null;
                visit.Credible_Rev_Timeout_UTC__c = table.getChildElement('rev_timeout_utc', null) != null ? parseDateTime(table.getChildElement('rev_timeout_utc', null).getText()) : null;
                visit.Credible_Title__c = table.getChildElement('title', null) != null ? table.getChildElement('title', null).getText() : '';
                visit.Credible_Med_Schedule_Version__c = table.getChildElement('med_schedule_version', null) != null ? Integer.valueOf(table.getChildElement('med_schedule_version', null).getText()) : null;
                visit.Credible_Credibleplan_Id__c = table.getChildElement('credibleplan_id', null) != null ? table.getChildElement('credibleplan_id', null).getText() : '';
                visit.Credible_NDC__c = table.getChildElement('ndc', null) != null ? table.getChildElement('ndc', null).getText() : '';
                visit.Credible_Qty_Administered__c = table.getChildElement('qty_administered', null) != null ? Decimal.valueOf(table.getChildElement('qty_administered', null).getText()) : null;
                visit.Credible_Encounter_Id__c = table.getChildElement('encounter_id', null) != null ? table.getChildElement('encounter_id', null).getText() : '';
                visit.Credible_Fnum_1__c = table.getChildElement('fnum1', null) != null ? Decimal.valueOf(table.getChildElement('fnum1', null).getText()) : null;
                visit.Credible_Fnum_2__c = table.getChildElement('fnum2', null) != null ? Decimal.valueOf(table.getChildElement('fnum2', null).getText()) : null;
                visit.Credible_Fnum_3__c = table.getChildElement('fnum3', null) != null ? Decimal.valueOf(table.getChildElement('fnum3', null).getText()) : null;
                visit.Credible_Unit_Price__c = table.getChildElement('unit_price', null) != null ? Decimal.valueOf(table.getChildElement('unit_price', null).getText()) : null;
                visit.Credible_Unit_Qualifier__c = table.getChildElement('unit_qualifier', null) != null ? table.getChildElement('unit_qualifier', null).getText() : '';
                visit.Credible_Delayed_Reason_Code__c = table.getChildElement('delayed_reason_code', null) != null ? table.getChildElement('delayed_reason_code', null).getText() : '';
                visit.Credible_Sign_Sub_LU_1__c = table.getChildElement('signsublu1', null) != null ? Integer.valueOf(table.getChildElement('signsublu1', null).getText()) : null;
                visit.Credible_Sign_Sub_LU_2__c = table.getChildElement('signsublu2', null) != null ? Integer.valueOf(table.getChildElement('signsublu2', null).getText()) : null;
                visit.Credible_Sign_Sub_LU_3__c = table.getChildElement('signsublu3', null) != null ? Integer.valueOf(table.getChildElement('signsublu3', null).getText()) : null;
                visit.Credible_Sign_Sub_LU_4__c = table.getChildElement('signsublu4', null) != null ? Integer.valueOf(table.getChildElement('signsublu4', null).getText()) : null;
                visit.Credible_Info_Blocking_Exception__c = table.getChildElement('info_blocking_exception', null) != null ? Integer.valueOf(table.getChildElement('info_blocking_exception', null).getText()) : null;
                visit.Credible_Esignature_Status__c = table.getChildElement('esignature_status', null) != null ? Integer.valueOf(table.getChildElement('esignature_status', null).getText()) : null;
                visit.Credible_State_Reporting_Flag__c = table.getChildElement('state_reporting_flag', null) != null ? Boolean.valueOf(table.getChildElement('state_reporting_flag', null).getText()) : false;
                
                credibleVisits.add(visit);
            }
            
            for(ple__Employee_Profile__c ep : [Select Id,Credible_Id__c From ple__Employee_Profile__c Where Credible_Id__c In :setToStoreEmpId]){
                mapToStoreEmpIdToEP.put(ep.Credible_Id__c,ep.Id);
            }
            
            for(ple__Patient_Admission__c pa : [Select Id,Credible_ID__c From ple__Patient_Admission__c Where Credible_Id__c In :setToStoreClientId]){
                mapToStoreClientIdToPA.put(pa.Credible_Id__c,pa.Id);
            }
            
            if(!credibleVisits.isEmpty()) {
                for(ple__Appointment__c app : credibleVisits){
                    if(mapToStoreClientIdToPA.containsKey(app.Credible_Client_Id__c)){
                        app.ple__Patient__c = mapToStoreClientIdToPA.get(app.Credible_Client_Id__c);
                    }
                    if(mapToStoreEmpIdToEP.containsKey(app.Credible_Emp_Id__c)){
                        app.ple__Employee__c = mapToStoreEmpIdToEP.get(app.Credible_Emp_Id__c);
                    }
                }
            }
            
            // Upsert records using Credible_Clientvisit_Id__c as external ID
            if(!credibleVisits.isEmpty()) {
                Database.UpsertResult[] results = Database.upsert(credibleVisits, ple__Appointment__c.Fields.Credible_Clientvisit_Id__c, false);
                
                List<Error_Log__c> errorLogs = new List<Error_Log__c>();
                
                for(Integer i = 0; i < results.size(); i++) {
                    
                    Database.UpsertResult result = results[i];
                    System.debug('result['+i+']=>'+results[i]);
                    ple__Appointment__c visit = credibleVisits[i];
                    
                    if(!result.isSuccess()) {
                        List<String> individualErrors = new List<String>();
                        
                        for(Database.Error err : result.getErrors()) {
                            individualErrors.add(err.getMessage());
                        }
                        
                        String combinedErrors = individualErrors.isEmpty() ? 'Unknown Error' : String.join(individualErrors, ', ');
                        
                        errorLogs.add(new Error_Log__c(
                            Error_Type__c = 'Apex',
                            Error_Message__c = combinedErrors,
                            Status__c = 'Failed',
                            Is_Import_Error__c = true,
                            Source_Name__c = 'Credible',
                            Source_Table__c = 'Service',
                            Source_System_Id__c = visit.Credible_Clientvisit_Id__c
                        ));
                    }
                }
                
                if(!errorLogs.isEmpty()) {
                    insert errorLogs;
                }
            }
            
        } else { 
            Error_Log__c errorLog = new Error_Log__c(
                Source_Name__c     = 'Credible',
                Error_Type__c = 'API',                  
                Error_Message__c = 'Request failed with status: ' + res.getStatusCode(),
                Status_Code__c = String.valueOf(res.getStatusCode()),
                Status__c   = res.getStatus(),
                Error_Details__c   = res.getBody(),
                Is_Import_Error__c = true,
                Source_Table__c = 'Service'
            );
            
            insert errorLog;
            System.debug('HTTP Request failed with status: ' + res.getStatusCode()); 
            System.debug('Response Body: ' + res.getBody()); 
        } 
    } catch (Exception e) { 
        Error_Log__c errorLog = new Error_Log__c(
            Source_Name__c   = 'Credible',
            Error_Type__c    = 'Apex',
            Error_Message__c = e.getMessage(),
            Stack_Trace__c   = e.getStackTraceString(),
            Status__c        = 'Failed',
            Is_Import_Error__c = true,
            Source_Table__c = 'Service'
        );
        
        insert errorLog;
        System.debug('Line Number: ' + e.getLineNumber());
        System.debug('Exception: ' + e.getMessage());
    }
}

    public static DateTime parseDateTime(String dateTimeStr) {
        if (String.isBlank(dateTimeStr)) return null;
        try {
            // Use JSON deserialize for proper ISO 8601 parsing
            return (DateTime)JSON.deserialize('"' + dateTimeStr + '"', DateTime.class);
        } catch (Exception e) {
            System.debug('Error parsing datetime: ' + dateTimeStr + ' - ' + e.getMessage());
            return null;
        }
    }

}