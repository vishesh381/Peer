/**
 * Service class to handle data sync from Credible to Salesforce
 * Pulls client/patient data from Credible Export API and updates Opportunity (Referral) records
 */
public class CredibleExportsService {

    /**
     * Import client/patient data from Credible
     * @param startDate - Optional start date filter
     * @param endDate - Optional end date filter
     * @param customParam1 - Created date filter
     * @param customParam2 - Updated date filter
     * @param customParam3 - Optional custom parameter
     */
    public static void importClientData(String startDate, String endDate, Date customParam1, Date customParam2, String customParam3) {
        System.debug('CredibleExportsService: Starting Client Data Import');

        // Get connection string from custom metadata
        List<pstar__Credible_Integration_Config__mdt> configRecord = [
            SELECT pstar__Client_Export_Connection_String__c
            FROM pstar__Credible_Integration_Config__mdt
            WHERE DeveloperName = 'Client_Credible_Connection'
            AND pstar__Client_Export_Connection_String__c != null
            LIMIT 1
        ];

        if (configRecord.isEmpty()) {
            System.debug('CredibleExportsService: No Credible Integration Config found with a valid Client Export Connection String.');
            logError('Configuration', 'No Credible Integration Config found with a valid Client Export Connection String.', null, 'Client');
            return;
        }

        String exportConnection = configRecord[0].pstar__Client_Export_Connection_String__c;
        System.debug('CredibleExportsService [CLIENT SYNC]: Using Client_Export_Connection_String: ' + exportConnection);

        // Build the export URL
        String url = Label.Credible_Export_BaseUrl +
            '?connection=' + EncodingUtil.urlEncode(exportConnection, 'UTF-8') +
            '&start_date=' + EncodingUtil.urlEncode(startDate != null ? startDate : '', 'UTF-8') +
            '&end_date=' + EncodingUtil.urlEncode(endDate != null ? endDate : '', 'UTF-8') +
            '&custom_param1=' + String.valueOf(customParam1) +
            '&custom_param2=' + String.valueOf(customParam2) +
            '&custom_param3=' + EncodingUtil.urlEncode(customParam3 != null ? customParam3 : '', 'UTF-8');

        System.debug('CredibleExportsService [CLIENT SYNC]: Full URL: ' + url);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setTimeout(120000);

        HttpResponse res = new HttpResponse();

        try {
            Http http = new Http();
            res = http.send(req);
            System.debug('CredibleExportsService: HTTP Status Code: ' + res.getStatusCode());

            if (res.getStatusCode() == 200) {
                String responseBody = res.getBody();
                System.debug('CredibleExportsService: Response received, length: ' + (responseBody != null ? responseBody.length() : 0));

                if (String.isBlank(responseBody)) {
                    System.debug('CredibleExportsService: Response body is empty.');
                    return;
                }

                // Parse XML response
                Dom.Document doc = new Dom.Document();
                doc.load(responseBody);
                Dom.XMLNode root = doc.getRootElement();

                if (root == null) {
                    System.debug('CredibleExportsService: No root node found.');
                    return;
                }

                Dom.XMLNode diffgramNode = root.getChildElement('diffgram', 'urn:schemas-microsoft-com:xml-diffgram-v1');

                if (diffgramNode == null) {
                    System.debug('CredibleExportsService: No diffgram node found.');
                    return;
                }

                Dom.XMLNode newDataSetNode = diffgramNode.getChildElements().isEmpty() ? null : diffgramNode.getChildElements().get(0);
                if (newDataSetNode == null) {
                    System.debug('CredibleExportsService: No NewDataSet node found.');
                    return;
                }

                List<Dom.XMLNode> tables = newDataSetNode.getChildElements();
                System.debug('CredibleExportsService: Number of records to process: ' + tables.size());

                // Process records
                processClientRecords(tables);

            } else {
                System.debug('CredibleExportsService: HTTP Request failed with status: ' + res.getStatusCode());
                logError('API', 'Request failed with status: ' + res.getStatusCode(), res.getBody(), 'Client');
            }

        } catch (Exception e) {
            System.debug('CredibleExportsService: Exception - ' + e.getMessage());
            System.debug('CredibleExportsService: Stack Trace - ' + e.getStackTraceString());
            logException(e, 'Client');
        }
    }

    /**
     * Process client records from XML and update Opportunity (Referral) records.
     * Only updates existing Opportunities that have a matching Credible_ID__c.
     * Also creates/links Contact records for new clients.
     */
    private static void processClientRecords(List<Dom.XMLNode> tables) {
        Set<String> clientProfileIds = new Set<String>();
        Map<String, Contact> existingContactsMap = new Map<String, Contact>();
        Map<String, Contact> contactsToInsert = new Map<String, Contact>();
        Map<String, Map<String, Object>> clientDataMap = new Map<String, Map<String, Object>>();

        // First pass: collect all client IDs and parse data
        for (Dom.XMLNode table : tables) {
            String clientId = getXmlNodeText(table, 'client_id');
            if (!String.isBlank(clientId)) {
                clientProfileIds.add(clientId);
                clientDataMap.put(clientId, parseClientXml(table));
            }
        }

        // Query existing contacts with Credible Profile IDs
        for (Contact c : [
            SELECT Id, pstar__Contact_Type__c, pstar__Credible_Profile_ID__c
            FROM Contact
            WHERE pstar__Contact_Type__c = 'Patient'
            AND pstar__Credible_Profile_ID__c IN :clientProfileIds
        ]) {
            existingContactsMap.put(c.pstar__Credible_Profile_ID__c, c);
        }

        // Query existing Opportunities with matching Credible IDs
        Map<String, Opportunity> existingOppsMap = new Map<String, Opportunity>();
        for (Opportunity opp : [
            SELECT Id, pstar__Credible_ID__c, pstar__Patient__c
            FROM Opportunity
            WHERE pstar__Credible_ID__c IN :clientProfileIds
        ]) {
            existingOppsMap.put(opp.pstar__Credible_ID__c, opp);
        }

        // Process contacts - create new ones for unknown clients
        for (String clientId : clientDataMap.keySet()) {
            Map<String, Object> data = clientDataMap.get(clientId);

            if (!existingContactsMap.containsKey(clientId) && !contactsToInsert.containsKey(clientId)) {
                String emailVal = (String) data.get('email');
                if (String.isBlank(emailVal) || emailVal.contains('N/A') || !isValidEmail(emailVal)) {
                    emailVal = null;
                }

                Contact patient = new Contact(
                    pstar__Contact_Type__c = 'Patient',
                    pstar__Credible_Profile_ID__c = clientId,
                    FirstName = (String) data.get('first_name'),
                    LastName = String.isBlank((String) data.get('last_name')) ? 'Unknown' : (String) data.get('last_name'),
                    Birthdate = (Date) data.get('dob'),
                    Email = emailVal
                );
                contactsToInsert.put(clientId, patient);
            }
        }

        // Insert new contacts
        if (!contactsToInsert.values().isEmpty()) {
            Database.SaveResult[] contactResults = Database.insert(contactsToInsert.values(), false);
            for (Integer i = 0; i < contactResults.size(); i++) {
                if (!contactResults[i].isSuccess()) {
                    System.debug('CredibleExportsService: Failed to insert contact: ' + contactResults[i].getErrors());
                }
            }
        }

        // Load Credible-to-Salesforce field mappings from custom metadata
        Map<String, Map<String, String>> fieldMappings = loadFieldMappings();

        // Update existing Opportunities with Credible data
        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (String clientId : clientDataMap.keySet()) {
            if (!existingOppsMap.containsKey(clientId)) {
                // No matching Opportunity - skip (client exists in Credible but not as a Referral in SF)
                continue;
            }

            Opportunity existingOpp = existingOppsMap.get(clientId);
            Map<String, Object> data = clientDataMap.get(clientId);
            Opportunity opp = mapDataToOpportunity(existingOpp.Id, data, fieldMappings);

            // Link contact if not already linked
            if (existingOpp.pstar__Patient__c == null) {
                if (existingContactsMap.containsKey(clientId)) {
                    opp.pstar__Patient__c = existingContactsMap.get(clientId).Id;
                } else if (contactsToInsert.containsKey(clientId) && contactsToInsert.get(clientId).Id != null) {
                    opp.pstar__Patient__c = contactsToInsert.get(clientId).Id;
                }
            }

            oppsToUpdate.add(opp);
        }

        // Update Opportunities
        if (!oppsToUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(oppsToUpdate, false);

            List<pstar__Error_Log__c> errorLogs = new List<pstar__Error_Log__c>();

            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    List<String> individualErrors = new List<String>();
                    for (Database.Error err : results[i].getErrors()) {
                        individualErrors.add(err.getMessage());
                    }
                    String combinedErrors = individualErrors.isEmpty() ? 'Unknown Error' : String.join(individualErrors, ', ');

                    errorLogs.add(new pstar__Error_Log__c(
                        pstar__Error_Type__c = 'Apex',
                        pstar__Error_Message__c = combinedErrors,
                        pstar__Status__c = 'Failed',
                        pstar__Is_Import_Error__c = true,
                        pstar__Source_Name__c = 'Credible',
                        pstar__Source_Table__c = 'Client',
                        pstar__Source_System_Id__c = oppsToUpdate[i].pstar__Credible_ID__c
                    ));
                }
            }

            if (!errorLogs.isEmpty()) {
                insert errorLogs;
            }

            System.debug('CredibleExportsService: Updated ' + oppsToUpdate.size() + ' Opportunities with ' + errorLogs.size() + ' errors.');
        }
    }

    /**
     * Parse client XML into a data map
     */
    private static Map<String, Object> parseClientXml(Dom.XMLNode table) {
        Map<String, Object> data = new Map<String, Object>();

        // Core
        data.put('client_id', getXmlNodeText(table, 'client_id'));

        // Name fields
        data.put('first_name', getXmlNodeText(table, 'first_name'));
        data.put('last_name', getXmlNodeText(table, 'last_name'));
        data.put('middle_name', getXmlNodeText(table, 'middle_name'));
        data.put('preferred_name', getXmlNodeText(table, 'preferred_name'));

        // Date fields
        data.put('dob', getXmlNodeDate(table, 'dob'));
        data.put('admission_date', getXmlNodeDate(table, 'admission_date'));
        data.put('referral_date', getXmlNodeDate(table, 'referral_date'));
        data.put('last_psych_eval', getXmlNodeDate(table, 'date7'));

        // Address
        data.put('address1', getXmlNodeText(table, 'address1'));
        data.put('address2', getXmlNodeText(table, 'address2'));
        data.put('city', getXmlNodeText(table, 'city'));
        data.put('county', getXmlNodeText(table, 'county'));
        data.put('state', getXmlNodeText(table, 'state'));
        data.put('zip', getXmlNodeText(table, 'zip'));

        // Contact
        data.put('home_phone', getXmlNodeText(table, 'home_phone'));
        data.put('mobile_phone', getXmlNodeText(table, 'mobile_phone'));
        data.put('email', getXmlNodeText(table, 'client_email'));
        data.put('preferred_contact', getXmlNodeText(table, 'text15'));

        // Demographics
        data.put('gender', getXmlNodeText(table, 'gender'));
        data.put('race', getXmlNodeText(table, 'race'));
        data.put('ethnicity', getXmlNodeText(table, 'ethnicity'));
        data.put('marital_status', getXmlNodeText(table, 'marital_status'));
        data.put('sexual_orientation', getXmlNodeText(table, 'dd2'));
        data.put('gender_identity', getXmlNodeText(table, 'dd3'));
        data.put('assigned_sex_at_birth', getXmlNodeText(table, 'dd4'));
        data.put('preferred_pronouns', getXmlNodeText(table, 'dd5'));
        data.put('ssn', getXmlNodeText(table, 'ssn'));

        // Status
        data.put('client_status', getXmlNodeText(table, 'client_status'));
        data.put('status_reason', getXmlNodeText(table, 'status_reason'));
        data.put('program_type', getXmlNodeText(table, 'program_type'));
        data.put('maid_number', getXmlNodeText(table, 'maid_number'));
        data.put('peertype', getXmlNodeText(table, 'peertype'));

        // Language
        data.put('preferred_language', getXmlNodeText(table, 'preferredlanguage'));
        data.put('primary_written_language', getXmlNodeText(table, 'primarywrittenlanguage'));
        data.put('need_interpreter', getXmlNodeBoolean(table, 'deaf'));

        // Living/Lifestyle
        data.put('living_situation', getXmlNodeText(table, 'livingsituation'));
        data.put('cps_preference', getXmlNodeText(table, 'text28'));
        data.put('smoking_status', getXmlNodeText(table, 'smokingstatus'));
        data.put('pets_in_home', getXmlNodeBoolean(table, 'bool12'));
        data.put('pet_aggression', getXmlNodeBoolean(table, 'bool13'));
        data.put('agrees_crim_hx', getXmlNodeBoolean(table, 'bool6'));
        data.put('call_as_peerstar', getXmlNodeBoolean(table, 'bool7'));

        // Service delivery
        data.put('srvc_telehealth', getXmlNodeBoolean(table, 'bool23'));
        data.put('srvc_telephone', getXmlNodeBoolean(table, 'bool24'));
        data.put('srvc_f2f', getXmlNodeBoolean(table, 'bool25'));

        // Medical/Clinical
        data.put('facility_name', getXmlNodeText(table, 'text3'));
        data.put('pcp', getXmlNodeText(table, 'text4'));
        data.put('psychiatrist', getXmlNodeText(table, 'text5'));
        data.put('diagnosis_intake', getXmlNodeText(table, 'text6'));
        data.put('reason_seeking', getXmlNodeText(table, 'text7'));
        data.put('no_admit_reason', getXmlNodeText(table, 'text8'));
        data.put('forensic_status', getXmlNodeText(table, 'text9'));
        data.put('signature_source', getXmlNodeText(table, 'text10'));
        data.put('release_of_info', getXmlNodeText(table, 'text11'));
        data.put('how_heard', getXmlNodeText(table, 'text12'));
        data.put('idd', getXmlNodeBoolean(table, 'bool8'));
        data.put('da_hx', getXmlNodeBoolean(table, 'bool9'));
        data.put('legal_involve', getXmlNodeBoolean(table, 'bool10'));
        data.put('megans_law', getXmlNodeBoolean(table, 'bool11'));

        // Referral
        data.put('referral_source', getXmlNodeText(table, 'referral_source'));
        data.put('referral_type', getXmlNodeText(table, 'referral_type'));
        data.put('referral_phone', getXmlNodeText(table, 'referral_phone'));
        data.put('web_referral', getXmlNodeBoolean(table, 'bool14'));

        // Availability
        data.put('available_days', getXmlNodeText(table, 'text13'));
        data.put('available_times', getXmlNodeText(table, 'text14'));

        return data;
    }

    /**
     * Map parsed data to Opportunity fields
     */
    private static Opportunity mapDataToOpportunity(Id oppId, Map<String, Object> data, Map<String, Map<String, String>> mappings) {
        Opportunity opp = new Opportunity(Id = oppId);

        // Name fields
        opp.pstar__Patient_First_Name__c = (String) data.get('first_name');
        opp.pstar__Patient_Last_Name__c = (String) data.get('last_name');
        opp.pstar__Middle_Initial__c = (String) data.get('middle_name');
        opp.pstar__Peer_Preferred_Name__c = (String) data.get('preferred_name');

        // Date fields
        opp.pstar__DOB__c = (Date) data.get('dob');
        opp.pstar__Admission_Date__c = (Date) data.get('admission_date');
        opp.pstar__Referral_Date__c = (Date) data.get('referral_date');
        // Last_Psych_Eval__c is Text(255) on Opportunity, convert Date to String
        Date lastPsychDate = (Date) data.get('last_psych_eval');
        opp.pstar__Last_Psych_Eval__c = lastPsychDate != null ? String.valueOf(lastPsychDate) : null;

        // Address
        opp.pstar__Street_Address__c = (String) data.get('address1');
        opp.pstar__Street_Address2__c = (String) data.get('address2');
        opp.pstar__Address_City__c = (String) data.get('city');
        opp.pstar__County__c = (String) data.get('county');
        opp.pstar__State__c = translateValue(mappings, 'State', (String) data.get('state'));
        opp.pstar__Zip_Code__c = (String) data.get('zip');

        // Contact
        opp.pstar__Home_Phone__c = (String) data.get('home_phone');
        opp.pstar__Mobile_Phone__c = (String) data.get('mobile_phone');
        opp.pstar__Email__c = (String) data.get('email');
        opp.pstar__Preferred_Contact__c = translateValue(mappings, 'Preferred Contact', (String) data.get('preferred_contact'));

        // Demographics - translate Credible codes to Salesforce picklist values
        opp.pstar__Gender__c = translateValue(mappings, 'Gender', (String) data.get('gender'));
        opp.pstar__Race__c = translateValue(mappings, 'Race', (String) data.get('race'));
        opp.pstar__Ethnicity__c = translateValue(mappings, 'Ethnicity', (String) data.get('ethnicity'));
        opp.pstar__Marital_Status__c = translateValue(mappings, 'Marital Status', (String) data.get('marital_status'));
        opp.pstar__Sexual_Orientation__c = translateValue(mappings, 'Sexual Orientation', (String) data.get('sexual_orientation'));
        opp.pstar__Gender_Identity__c = translateValue(mappings, 'Gender Identity', (String) data.get('gender_identity'));
        opp.pstar__Assigned_sex_at_birth__c = translateValue(mappings, 'Assigned Sex At Birth', (String) data.get('assigned_sex_at_birth'));
        opp.pstar__Preferred_Pronouns__c = translateValue(mappings, 'Preferred Pronouns', (String) data.get('preferred_pronouns'));
        opp.pstar__Peer_ssn__c = (String) data.get('ssn');

        // Status - translate codes
        opp.pstar__Status__c = (String) data.get('client_status');
        opp.pstar__Status_Reason__c = translateValue(mappings, 'Status Reason', (String) data.get('status_reason'));
        opp.pstar__Program_Type__c = (String) data.get('program_type');
        opp.pstar__MAID__c = (String) data.get('maid_number');
        opp.pstar__Peer_Type__c = translateValue(mappings, 'Peer Type', (String) data.get('peertype'));

        // Language - translate codes
        opp.pstar__Preferred_Language__c = translateValue(mappings, 'Preferred Language', (String) data.get('preferred_language'));
        opp.pstar__Primary_Written_Language__c = translateValue(mappings, 'Preferred Language', (String) data.get('primary_written_language'));
        opp.pstar__Need_Interpreter__c = data.get('need_interpreter') != null ? (Boolean) data.get('need_interpreter') : false;

        // Living/Lifestyle - translate codes
        opp.pstar__Living_Situation__c = translateValue(mappings, 'Living Situation', (String) data.get('living_situation'));
        opp.pstar__CPS_Preference__c = (String) data.get('cps_preference');
        opp.pstar__Smoking_Status__c = translateValue(mappings, 'Smoking Status', (String) data.get('smoking_status'));
        opp.pstar__Are_there_pets_in_home__c = data.get('pets_in_home') != null ? (Boolean) data.get('pets_in_home') : false;
        opp.pstar__Hx_of_pet_aggression__c = data.get('pet_aggression') != null ? (Boolean) data.get('pet_aggression') : false;
        opp.pstar__Agrees_to_staff_w_Crim_Hx__c = data.get('agrees_crim_hx') != null ? (Boolean) data.get('agrees_crim_hx') : false;
        opp.pstar__May_we_call_as_Peerstar__c = data.get('call_as_peerstar') != null ? (Boolean) data.get('call_as_peerstar') : false;

        // Service delivery
        opp.pstar__Type_of_srvc_Telehealth__c = data.get('srvc_telehealth') != null ? (Boolean) data.get('srvc_telehealth') : false;
        opp.pstar__Type_of_srvc_Telephone__c = data.get('srvc_telephone') != null ? (Boolean) data.get('srvc_telephone') : false;
        opp.pstar__Type_of_srvc_F2F__c = data.get('srvc_f2f') != null ? (Boolean) data.get('srvc_f2f') : false;

        // Medical/Clinical
        opp.pstar__Facility_Name__c = (String) data.get('facility_name');
        opp.pstar__Primary_Care_Physician__c = (String) data.get('pcp');
        opp.pstar__Psychiatrist__c = (String) data.get('psychiatrist');
        opp.pstar__Diagnosis_Intake__c = (String) data.get('diagnosis_intake');
        opp.pstar__Reason_Seeking_Services__c = (String) data.get('reason_seeking');
        opp.pstar__No_Admit_Reason__c = translateValue(mappings, 'No Admit Reason', (String) data.get('no_admit_reason'));
        opp.pstar__Forensic_Status__c = translateValue(mappings, 'Forensic Status', (String) data.get('forensic_status'));
        opp.pstar__Client_Signature_Source__c = translateValue(mappings, 'Client Signature Source', (String) data.get('signature_source'));
        opp.pstar__Release_Of_Information__c = translateValue(mappings, 'Release Of Information', (String) data.get('release_of_info'));
        opp.pstar__How_did_you_hear_of_us__c = (String) data.get('how_heard');
        opp.pstar__IDD__c = data.get('idd') != null ? (Boolean) data.get('idd') : false;
        opp.pstar__Is_There_a_Hx_of_DA_Use__c = data.get('da_hx') != null ? (Boolean) data.get('da_hx') : false;
        opp.pstar__Legal_Involve_in_Past_Yr__c = data.get('legal_involve') != null ? (Boolean) data.get('legal_involve') : false;
        opp.pstar__Megan_s_Law__c = data.get('megans_law') != null ? (Boolean) data.get('megans_law') : false;

        // Referral - translate codes
        opp.pstar__Referred_By__c = translateValue(mappings, 'Referral Source', (String) data.get('referral_source'));
        opp.pstar__Referral_Type__c = translateValue(mappings, 'Referral Type', (String) data.get('referral_type'));
        opp.pstar__Referral_Phone__c = (String) data.get('referral_phone');
        opp.pstar__Web_Referral__c = data.get('web_referral') != null ? (Boolean) data.get('web_referral') : false;

        // Availability
        opp.pstar__Available_Days__c = (String) data.get('available_days');
        opp.pstar__Available_Times__c = (String) data.get('available_times');

        return opp;
    }

    /**
     * Load all Credible Field Mapping custom metadata into a nested map.
     * Outer key: Field_Category__c, Inner key: Credible_Code__c (Credible ID), Inner value: Salesforce_Value__c
     */
    private static Map<String, Map<String, String>> loadFieldMappings() {
        Map<String, Map<String, String>> mappings = new Map<String, Map<String, String>>();

        for (pstar__Credible_Field_Mapping__mdt mapping : [
            SELECT pstar__Field_Category__c, pstar__Credible_Code__c, pstar__Salesforce_Value__c
            FROM pstar__Credible_Field_Mapping__mdt
            WHERE pstar__Salesforce_Value__c != null
        ]) {
            String category = mapping.pstar__Field_Category__c;
            if (!mappings.containsKey(category)) {
                mappings.put(category, new Map<String, String>());
            }
            mappings.get(category).put(mapping.pstar__Credible_Code__c, mapping.pstar__Salesforce_Value__c);
        }

        return mappings;
    }

    /**
     * Translate a Credible value to its Salesforce equivalent using field mappings.
     * If CMT has a mapping for the code, returns the mapped SF value.
     * If no mapping exists, returns the raw Credible value as-is (user-entered passthrough).
     */
    private static String translateValue(Map<String, Map<String, String>> mappings, String category, String credibleCode) {
        if (String.isBlank(credibleCode)) {
            return null;
        }
        if (!mappings.containsKey(category)) {
            return credibleCode;
        }
        Map<String, String> categoryMap = mappings.get(category);
        return categoryMap.containsKey(credibleCode) ? categoryMap.get(credibleCode) : credibleCode;
    }

    /**
     * Get text from XML node, checking for encryption
     */
    private static String getXmlNodeText(Dom.XMLNode table, String elementName) {
        Dom.XMLNode node = table.getChildElement(elementName, null);
        if (node == null) {
            return null;
        }

        String text = node.getText();
        if (String.isBlank(text) || isDataEncrypted(text)) {
            return null;
        }

        return text;
    }

    /**
     * Get date from XML node
     */
    private static Date getXmlNodeDate(Dom.XMLNode table, String elementName) {
        String text = getXmlNodeText(table, elementName);
        if (String.isBlank(text)) {
            return null;
        }

        try {
            return Date.valueOf(text);
        } catch (Exception e) {
            System.debug('CredibleExportsService: Error parsing date ' + elementName + ': ' + text);
            return null;
        }
    }

    /**
     * Get boolean from XML node
     */
    private static Boolean getXmlNodeBoolean(Dom.XMLNode table, String elementName) {
        String text = getXmlNodeText(table, elementName);
        if (String.isBlank(text)) {
            return false;
        }

        return Boolean.valueOf(text);
    }

    /**
     * Check if data is encrypted (placeholder for future implementation)
     */
    private static Boolean isDataEncrypted(String text) {
        return false;
    }

    /**
     * Validate email format
     */
    private static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) {
            return false;
        }
        return Pattern.matches('^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$', email);
    }

    /**
     * Log error to Error_Log__c
     */
    private static void logError(String errorType, String message, String details, String sourceTable) {
        try {
            pstar__Error_Log__c errorLog = new pstar__Error_Log__c(
                pstar__Source_Name__c = 'Credible',
                pstar__Error_Type__c = errorType,
                pstar__Error_Message__c = message,
                pstar__Status__c = 'Failed',
                pstar__Error_Details__c = details,
                pstar__Is_Import_Error__c = true,
                pstar__Source_Table__c = sourceTable
            );
            insert errorLog;
        } catch (Exception e) {
            System.debug('CredibleExportsService: Failed to log error: ' + e.getMessage());
        }
    }

    /**
     * Log exception to Error_Log__c
     */
    private static void logException(Exception e, String sourceTable) {
        try {
            pstar__Error_Log__c errorLog = new pstar__Error_Log__c(
                pstar__Source_Name__c = 'Credible',
                pstar__Error_Type__c = 'Apex',
                pstar__Error_Message__c = e.getMessage(),
                pstar__Stack_Trace__c = e.getStackTraceString(),
                pstar__Status__c = 'Failed',
                pstar__Is_Import_Error__c = true,
                pstar__Source_Table__c = sourceTable
            );
            insert errorLog;
        } catch (Exception ex) {
            System.debug('CredibleExportsService: Failed to log exception: ' + ex.getMessage());
        }
    }

    /**
     * Parse DateTime from ISO 8601 string
     */
    public static DateTime parseDateTime(String dateTimeStr) {
        if (String.isBlank(dateTimeStr)) {
            return null;
        }

        try {
            return (DateTime) JSON.deserialize('"' + dateTimeStr + '"', DateTime.class);
        } catch (Exception e) {
            System.debug('CredibleExportsService: Error parsing datetime: ' + dateTimeStr + ' - ' + e.getMessage());
            return null;
        }
    }

    /**
     * Import employee data from Credible
     */
    public static void importEmployeeData(String startDate, String endDate, Date customParam1, Date customParam2, String customParam3) {
        System.debug('CredibleExportsService: Starting Employee Data Import');

        // Get connection string from custom metadata
        List<pstar__Credible_Integration_Config__mdt> configRecord = [
            SELECT pstar__Employee_Export_Connection_String__c
            FROM pstar__Credible_Integration_Config__mdt
            WHERE DeveloperName = 'Client_Credible_Connection'
            AND pstar__Employee_Export_Connection_String__c != null
            LIMIT 1
        ];

        if (configRecord.isEmpty()) {
            System.debug('CredibleExportsService: No Credible Integration Config found with a valid Employee Export Connection String.');
            logError('Configuration', 'No Credible Integration Config found with a valid Employee Export Connection String.', null, 'Employee');
            return;
        }

        String exportConnection = configRecord[0].pstar__Employee_Export_Connection_String__c;
        System.debug('CredibleExportsService [EMPLOYEE SYNC]: Using Employee_Export_Connection_String: ' + exportConnection);

        // Build the export URL
        String url = Label.Credible_Export_BaseUrl +
            '?connection=' + EncodingUtil.urlEncode(exportConnection, 'UTF-8') +
            '&start_date=' + EncodingUtil.urlEncode(startDate != null ? startDate : '', 'UTF-8') +
            '&end_date=' + EncodingUtil.urlEncode(endDate != null ? endDate : '', 'UTF-8') +
            '&custom_param1=' + String.valueOf(customParam1) +
            '&custom_param2=' + String.valueOf(customParam2) +
            '&custom_param3=' + EncodingUtil.urlEncode(customParam3 != null ? customParam3 : '', 'UTF-8');

        System.debug('CredibleExportsService [EMPLOYEE SYNC]: Full URL: ' + url);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setTimeout(120000);

        HttpResponse res = new HttpResponse();

        try {
            Http http = new Http();
            res = http.send(req);
            System.debug('CredibleExportsService: HTTP Status Code: ' + res.getStatusCode());

            if (res.getStatusCode() == 200) {
                String responseBody = res.getBody();
                System.debug('CredibleExportsService: Response received, length: ' + (responseBody != null ? responseBody.length() : 0));

                if (String.isBlank(responseBody)) {
                    System.debug('CredibleExportsService: Response body is empty.');
                    return;
                }

                // Parse XML response
                Dom.Document doc = new Dom.Document();
                doc.load(responseBody);
                Dom.XMLNode root = doc.getRootElement();

                if (root == null) {
                    System.debug('CredibleExportsService: No root node found.');
                    return;
                }

                Dom.XMLNode diffgramNode = root.getChildElement('diffgram', 'urn:schemas-microsoft-com:xml-diffgram-v1');

                if (diffgramNode == null) {
                    System.debug('CredibleExportsService: No diffgram node found.');
                    return;
                }

                Dom.XMLNode newDataSetNode = diffgramNode.getChildElements().isEmpty() ? null : diffgramNode.getChildElements().get(0);
                if (newDataSetNode == null) {
                    System.debug('CredibleExportsService: No NewDataSet node found.');
                    return;
                }

                List<Dom.XMLNode> tables = newDataSetNode.getChildElements();
                System.debug('CredibleExportsService: Number of employee records to process: ' + tables.size());

                // Process employee records
                processEmployeeRecords(tables);

            } else {
                System.debug('CredibleExportsService: HTTP Request failed with status: ' + res.getStatusCode());
                logError('API', 'Request failed with status: ' + res.getStatusCode(), res.getBody(), 'Employee');
            }

        } catch (Exception e) {
            System.debug('CredibleExportsService: Exception - ' + e.getMessage());
            System.debug('CredibleExportsService: Stack Trace - ' + e.getStackTraceString());
            logException(e, 'Employee');
        }
    }

    /**
     * Process employee records from XML and upsert to Employee_Profile__c
     */
    private static void processEmployeeRecords(List<Dom.XMLNode> tables) {
        Set<String> empIds = new Set<String>();
        Map<String, Contact> existingContactsMap = new Map<String, Contact>();
        List<pstar__Employee_Profile__c> employeeProfiles = new List<pstar__Employee_Profile__c>();

        // First pass: collect all employee IDs
        for (Dom.XMLNode table : tables) {
            String empId = getXmlNodeText(table, 'emp_id');
            if (!String.isBlank(empId)) {
                empIds.add(empId);
            }
        }

        // Query existing contacts with Credible IDs
        for (Contact c : [
            SELECT Id, pstar__Credible_Profile_ID__c
            FROM Contact
            WHERE pstar__Credible_Profile_ID__c IN :empIds
        ]) {
            existingContactsMap.put(c.pstar__Credible_Profile_ID__c, c);
        }

        // Second pass: process each record
        for (Dom.XMLNode table : tables) {
            pstar__Employee_Profile__c employeeProfile = mapXmlToEmployeeProfile(table);

            if (String.isBlank(employeeProfile.Credible_ID__c)) {
                continue;
            }

            // Link to existing contact if found
            if (existingContactsMap.containsKey(employeeProfile.Credible_ID__c)) {
                employeeProfile.pstar__Employee__c = existingContactsMap.get(employeeProfile.Credible_ID__c).Id;
            }

            employeeProfiles.add(employeeProfile);
        }

        // Upsert employee profiles using Credible_ID__c as external ID
        if (!employeeProfiles.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(employeeProfiles, pstar__Employee_Profile__c.Fields.Credible_ID__c, false);

            List<pstar__Error_Log__c> errorLogs = new List<pstar__Error_Log__c>();

            for (Integer i = 0; i < results.size(); i++) {
                Database.UpsertResult result = results[i];
                pstar__Employee_Profile__c emp = employeeProfiles[i];

                if (!result.isSuccess()) {
                    List<String> individualErrors = new List<String>();

                    for (Database.Error err : result.getErrors()) {
                        individualErrors.add(err.getMessage());
                    }

                    String combinedErrors = individualErrors.isEmpty() ? 'Unknown Error' : String.join(individualErrors, ', ');

                    errorLogs.add(new pstar__Error_Log__c(
                        pstar__Error_Type__c = 'Apex',
                        pstar__Error_Message__c = combinedErrors,
                        pstar__Status__c = 'Failed',
                        pstar__Is_Import_Error__c = true,
                        pstar__Source_Name__c = 'Credible',
                        pstar__Source_Table__c = 'Employee',
                        pstar__Source_System_Id__c = emp.Credible_ID__c
                    ));
                }
            }

            if (!errorLogs.isEmpty()) {
                insert errorLogs;
            }

            System.debug('CredibleExportsService: Upserted ' + employeeProfiles.size() + ' employee profiles with ' + errorLogs.size() + ' errors.');
        }
    }

    /**
     * Map XML node to Employee_Profile__c record
     */
    private static pstar__Employee_Profile__c mapXmlToEmployeeProfile(Dom.XMLNode table) {
        pstar__Employee_Profile__c emp = new pstar__Employee_Profile__c();

        // Core identification
        emp.Credible_ID__c = getXmlNodeText(table, 'emp_id');
        emp.Credible_External_ID__c = getXmlNodeText(table, 'external_id');
        emp.Credible_Username__c = getXmlNodeText(table, 'username');

        // Name fields
        emp.Credible_Employee_First_Name__c = getXmlNodeText(table, 'first_name');
        emp.Credible_Employee_Middle_Name__c = getXmlNodeText(table, 'middle_name');
        emp.Credible_Employee_Last_Name__c = getXmlNodeText(table, 'last_name');
        emp.Credible_Employee_Preferred_Name__c = getXmlNodeText(table, 'text24');

        // Personal info
        emp.Credible_Gender__c = getXmlNodeText(table, 'gender');
        emp.Credible_SSN__c = getXmlNodeText(table, 'ssn');
        emp.Credible_DOB__c = getXmlNodeDate(table, 'dob');
        emp.Credible_Race__c = getXmlNodeText(table, 'dd12');

        // Employment info
        emp.Credible_Title__c = getXmlNodeText(table, 'title');
        emp.Credible_Status__c = getXmlNodeText(table, 'emp_status');
        emp.Credible_Employment_Status__c = getXmlNodeText(table, 'dd1');
        emp.Credible_Hire_Date__c = getXmlNodeDate(table, 'hire_date');
        emp.Credible_Term_Date__c = getXmlNodeDate(table, 'term_date');
        emp.Credible_Part_Time__c = getXmlNodeBoolean(table, 'part_time');
        emp.Credible_Date_Full_Time__c = getXmlNodeDate(table, 'date6');
        emp.Credible_Can_Supervise__c = getXmlNodeBoolean(table, 'is_supervisor_flag');
        emp.Credible_Is_HR__c = getXmlNodeBoolean(table, 'is_hr');
        emp.Credible_Is_Clinical__c = getXmlNodeBoolean(table, 'is_clinical');

        // Address fields
        emp.Credible_address1__c = getXmlNodeText(table, 'address1');
        emp.Credible_address2__c = getXmlNodeText(table, 'address2');
        emp.Credible_City__c = getXmlNodeText(table, 'city');
        emp.Credible_State__c = getXmlNodeText(table, 'state');
        emp.Credible_Zip_Code__c = getXmlNodeText(table, 'zip');
        emp.Credible_County__c = getXmlNodeText(table, 'text1');
        emp.Credible_Main_County_Worked_In__c = getXmlNodeText(table, 'dd7');

        // Contact fields
        emp.Credible_Home_Phone__c = getXmlNodeText(table, 'home_phone');
        emp.Credible_Mobile_Phone__c = getXmlNodeText(table, 'mobile_phone');
        emp.Credible_Work_Phone__c = getXmlNodeText(table, 'work_phone');
        emp.Credible_Email__c = getXmlNodeText(table, 'email');
        emp.Credible_Personal_Email__c = getXmlNodeText(table, 'text5');
        emp.Credible_Emergency_Phone__c = getXmlNodeText(table, 'emergency_phone');
        emp.Credible_Emergency_Contact__c = getXmlNodeText(table, 'emergency_contact');

        // Credentials and certifications
        emp.Credible_Credentials__c = getXmlNodeText(table, 'credentials');
        emp.Credible_Profile_Code__c = getXmlNodeText(table, 'profile_code');
        emp.Credible_FBI_Clearance_Date__c = getXmlNodeDate(table, 'date4');
        emp.Credible_Child_Abuse_Clr_Date__c = getXmlNodeDate(table, 'date10');
        emp.Credible_Child_Abuse_Training__c = getXmlNodeBoolean(table, 'bool13');
        emp.Credible_Suicide_Screening_Trnging__c = getXmlNodeBoolean(table, 'bool4');
        emp.Credible_ANSA_Expiration_Date__c = getXmlNodeDate(table, 'date1');
        emp.Credible_CPS_Certificate_Date__c = getXmlNodeDate(table, 'date2');
        emp.Credible_CPSS_Certification_Date__c = getXmlNodeDate(table, 'date12');
        emp.Credible_CPS_CRS_training_hrs_due__c = getXmlNodeDate(table, 'date3');
        emp.Credible_CPS_PCB_Exp__c = getXmlNodeDate(table, 'date9');
        emp.Credible_CRS_Certificate_Date__c = getXmlNodeDate(table, 'date19');
        emp.Credible_CRS_PCB_Train_Expiration__c = getXmlNodeDate(table, 'date16');
        emp.Credible_CPS_Initial_6_Hours_Appro__c = getXmlNodeDate(table, 'date15');
        emp.Credible_CRS_Initial_6_Hours_Appro__c = getXmlNodeDate(table, 'date8');
        emp.Credible_Initial_PCB_App_sent__c = getXmlNodeBoolean(table, 'bool7');
        emp.Credible_3_hour_CPSL__c = getXmlNodeBoolean(table, 'bool11');

        // Supervision
        emp.Credible_Date_of_Last_Supervision__c = getXmlNodeDate(table, 'date11');
        emp.Credible_Previous_Supervision__c = getXmlNodeDate(table, 'date17');
        emp.Credible_Last_Supervised_By__c = getXmlNodeText(table, 'text22');
        emp.Credible_Date_Last_TimeSheet_Appr__c = getXmlNodeDate(table, 'date14');

        // Other fields
        emp.Credible_Notes__c = getXmlNodeText(table, 'notes');
        emp.Credible_Comments__c = getXmlNodeText(table, 'textlong1');
        emp.Credible_Veteran_Status__c = getXmlNodeBoolean(table, 'bool1');
        emp.Credible_Criminal_History__c = getXmlNodeBoolean(table, 'bool5');
        emp.Credible_Criminal_EPATCH__c = getXmlNodeText(table, 'text10');
        emp.Credible_HR_Packet_Complete__c = getXmlNodeBoolean(table, 'bool10');
        emp.Credible_401k_Eligible__c = getXmlNodeBoolean(table, 'bool9');
        emp.Credible_Issued_iPad__c = getXmlNodeText(table, 'text23');
        emp.Credible_iPad_Returned__c = getXmlNodeBoolean(table, 'bool15');
        emp.Credible_Driver_license_expiration__c = getXmlNodeDate(table, 'date13');
        emp.Credible_LOA_Suspension_Date__c = getXmlNodeDate(table, 'date5');
        emp.Credible_LOA_FMLA_Return_Date__c = getXmlNodeDate(table, 'date20');
        emp.Credible_Regional_Support_Manager__c = getXmlNodeText(table, 'dd6');
        emp.Credible_Date_Created__c = getXmlNodeDate(table, 'date_created');
        emp.Credible_Date_Updated__c = getXmlNodeDate(table, 'date_updated');

        return emp;
    }

    /**
     * Import client visit/appointment data from Credible
     */
    public static void importClientVisitData(String startDate, String endDate, Date customParam1, Date customParam2, String customParam3) {
        System.debug('CredibleExportsService: Starting Client Visit Data Import');

        // Get connection string from custom metadata
        List<pstar__Credible_Integration_Config__mdt> configRecord = [
            SELECT pstar__ClientVisit_Export_Connection_String__c
            FROM pstar__Credible_Integration_Config__mdt
            WHERE DeveloperName = 'Client_Credible_Connection'
            AND pstar__ClientVisit_Export_Connection_String__c != null
            LIMIT 1
        ];

        if (configRecord.isEmpty()) {
            System.debug('CredibleExportsService: No Credible Integration Config found with a valid Client Visit Export Connection String.');
            logError('Configuration', 'No Credible Integration Config found with a valid Client Visit Export Connection String.', null, 'Service');
            return;
        }

        String exportConnection = configRecord[0].pstar__ClientVisit_Export_Connection_String__c;
        System.debug('CredibleExportsService [APPOINTMENT SYNC]: Using ClientVisit_Export_Connection_String: ' + exportConnection);

        // Build the export URL
        String url = Label.Credible_Export_BaseUrl +
            '?connection=' + EncodingUtil.urlEncode(exportConnection, 'UTF-8') +
            '&start_date=' + EncodingUtil.urlEncode(startDate != null ? startDate : '', 'UTF-8') +
            '&end_date=' + EncodingUtil.urlEncode(endDate != null ? endDate : '', 'UTF-8') +
            '&custom_param1=' + String.valueOf(customParam1) +
            '&custom_param2=' + String.valueOf(customParam2) +
            '&custom_param3=' + EncodingUtil.urlEncode(customParam3 != null ? customParam3 : '', 'UTF-8');

        System.debug('CredibleExportsService [APPOINTMENT SYNC]: Full URL: ' + url);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setTimeout(120000);

        HttpResponse res = new HttpResponse();

        try {
            Http http = new Http();
            res = http.send(req);
            System.debug('CredibleExportsService: HTTP Status Code: ' + res.getStatusCode());

            if (res.getStatusCode() == 200) {
                String responseBody = res.getBody();
                System.debug('CredibleExportsService: Response received, length: ' + (responseBody != null ? responseBody.length() : 0));

                if (String.isBlank(responseBody)) {
                    System.debug('CredibleExportsService: Response body is empty.');
                    return;
                }

                // Parse XML response
                Dom.Document doc = new Dom.Document();
                doc.load(responseBody);
                Dom.XMLNode root = doc.getRootElement();

                if (root == null) {
                    System.debug('CredibleExportsService: No root node found.');
                    return;
                }

                Dom.XMLNode diffgramNode = root.getChildElement('diffgram', 'urn:schemas-microsoft-com:xml-diffgram-v1');

                if (diffgramNode == null) {
                    System.debug('CredibleExportsService: No diffgram node found.');
                    return;
                }

                Dom.XMLNode newDataSetNode = diffgramNode.getChildElements().isEmpty() ? null : diffgramNode.getChildElements().get(0);
                if (newDataSetNode == null) {
                    System.debug('CredibleExportsService: No NewDataSet node found.');
                    return;
                }

                List<Dom.XMLNode> tables = newDataSetNode.getChildElements();
                System.debug('CredibleExportsService: Number of client visit records to process: ' + tables.size());

                // Process client visit records
                processClientVisitRecords(tables);

            } else {
                System.debug('CredibleExportsService: HTTP Request failed with status: ' + res.getStatusCode());
                logError('API', 'Request failed with status: ' + res.getStatusCode(), res.getBody(), 'Service');
            }

        } catch (Exception e) {
            System.debug('CredibleExportsService: Exception - ' + e.getMessage());
            System.debug('CredibleExportsService: Stack Trace - ' + e.getStackTraceString());
            logException(e, 'Service');
        }
    }

    /**
     * Process client visit records from XML and upsert to Appointment__c
     * Links appointments to Opportunity via Credible_ID__c and Employee Profile via emp_id
     */
    private static void processClientVisitRecords(List<Dom.XMLNode> tables) {
        Set<String> clientIds = new Set<String>();
        Set<String> empIds = new Set<String>();
        Map<String, Id> clientIdToOpportunityId = new Map<String, Id>();
        Map<String, Id> empIdToEmployeeProfileId = new Map<String, Id>();
        List<pstar__Appointment__c> appointments = new List<pstar__Appointment__c>();

        // First pass: collect all client and employee IDs
        for (Dom.XMLNode table : tables) {
            String clientId = getXmlNodeText(table, 'client_id');
            String empId = getXmlNodeText(table, 'emp_id');
            if (!String.isBlank(clientId)) {
                clientIds.add(clientId);
            }
            if (!String.isBlank(empId)) {
                empIds.add(empId);
            }
        }

        // Query existing Opportunities for linking (by Credible_ID__c)
        for (Opportunity opp : [
            SELECT Id, pstar__Credible_ID__c
            FROM Opportunity
            WHERE pstar__Credible_ID__c IN :clientIds
        ]) {
            clientIdToOpportunityId.put(opp.pstar__Credible_ID__c, opp.Id);
        }

        // Query existing Employee Profiles for linking
        for (pstar__Employee_Profile__c ep : [
            SELECT Id, Credible_ID__c
            FROM pstar__Employee_Profile__c
            WHERE Credible_ID__c IN :empIds
        ]) {
            empIdToEmployeeProfileId.put(ep.Credible_ID__c, ep.Id);
        }

        // Second pass: process each record
        for (Dom.XMLNode table : tables) {
            pstar__Appointment__c appt = mapXmlToAppointment(table);

            if (String.isBlank(appt.Credible_Clientvisit_Id__c)) {
                continue;
            }

            // Link to Opportunity via Credible client ID
            if (clientIdToOpportunityId.containsKey(appt.Credible_Client_Id__c)) {
                appt.pstar__Referral__c = clientIdToOpportunityId.get(appt.Credible_Client_Id__c);
            }

            // Link to Employee Profile
            if (empIdToEmployeeProfileId.containsKey(appt.Credible_Emp_Id__c)) {
                appt.pstar__Employee__c = empIdToEmployeeProfileId.get(appt.Credible_Emp_Id__c);
            }

            appointments.add(appt);
        }

        // Upsert appointments using Credible_Clientvisit_Id__c as external ID
        if (!appointments.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(appointments, pstar__Appointment__c.Fields.Credible_Clientvisit_Id__c, false);

            List<pstar__Error_Log__c> errorLogs = new List<pstar__Error_Log__c>();

            for (Integer i = 0; i < results.size(); i++) {
                Database.UpsertResult result = results[i];
                pstar__Appointment__c appt = appointments[i];

                if (!result.isSuccess()) {
                    List<String> individualErrors = new List<String>();

                    for (Database.Error err : result.getErrors()) {
                        individualErrors.add(err.getMessage());
                    }

                    String combinedErrors = individualErrors.isEmpty() ? 'Unknown Error' : String.join(individualErrors, ', ');

                    errorLogs.add(new pstar__Error_Log__c(
                        pstar__Error_Type__c = 'Apex',
                        pstar__Error_Message__c = combinedErrors,
                        pstar__Status__c = 'Failed',
                        pstar__Is_Import_Error__c = true,
                        pstar__Source_Name__c = 'Credible',
                        pstar__Source_Table__c = 'Service',
                        pstar__Source_System_Id__c = appt.Credible_Clientvisit_Id__c
                    ));
                }
            }

            if (!errorLogs.isEmpty()) {
                insert errorLogs;
            }

            System.debug('CredibleExportsService: Upserted ' + appointments.size() + ' appointments with ' + errorLogs.size() + ' errors.');
        }
    }

    /**
     * Map XML node to Appointment__c record
     */
    private static pstar__Appointment__c mapXmlToAppointment(Dom.XMLNode table) {
        pstar__Appointment__c appt = new pstar__Appointment__c();

        // Core identification
        appt.Credible_Clientvisit_Id__c = getXmlNodeText(table, 'clientvisit_id');
        appt.Credible_Client_Id__c = getXmlNodeText(table, 'client_id');
        appt.Credible_Emp_Id__c = getXmlNodeText(table, 'emp_id');
        appt.Credible_By_Emp_Id__c = getXmlNodeText(table, 'by_emp_id');

        // Visit type and program
        appt.Credible_Program_Id__c = getXmlNodeText(table, 'program_code');
        appt.Credible_Visittype_Id__c = getXmlNodeText(table, 'visittype_id');
        appt.Credible_Visittype__c = getXmlNodeText(table, 'visittype');
        appt.Credible_CPT_Code__c = getXmlNodeText(table, 'cptcode');
        appt.Credible_Location_Id__c = getXmlNodeText(table, 'location_code');
        appt.Credible_Matrix_Id__c = getXmlNodeText(table, 'matrix_id');

        // Status and timing
        appt.Credible_Status__c = getXmlNodeText(table, 'status');
        appt.Credible_Timein__c = parseDateTime(getXmlNodeText(table, 'timein'));
        appt.Credible_Timeout__c = parseDateTime(getXmlNodeText(table, 'timeout'));
        appt.Credible_Rev_Timein__c = parseDateTime(getXmlNodeText(table, 'rev_timein'));
        appt.Credible_Rev_Timeout__c = parseDateTime(getXmlNodeText(table, 'rev_timeout'));
        appt.Credible_Duration__c = getXmlNodeInteger(table, 'duration');
        appt.Credible_Transfer_Date__c = parseDateTime(getXmlNodeText(table, 'transfer_date'));
        appt.Credible_Non_Billable__c = getXmlNodeBoolean(table, 'non_billable');

        // Client and employee names
        appt.Credible_Client_First_Name__c = getXmlNodeText(table, 'clientfirstname');
        appt.Credible_Client_Last_Name__c = getXmlNodeText(table, 'clientlastname');
        appt.Credible_Emp_Name__c = getXmlNodeText(table, 'emp_name');

        // Billing fields
        appt.Credible_Rate__c = getXmlNodeDecimal(table, 'rate');
        appt.Credible_Contract_Rate__c = getXmlNodeDecimal(table, 'contract_rate');
        appt.Credible_Units_Of_Svc__c = getXmlNodeDecimal(table, 'units_of_svc');
        appt.Credible_Recipient_Id__c = getXmlNodeText(table, 'recipient_code');
        appt.Credible_Auth_Id__c = getXmlNodeText(table, 'auth_id');
        appt.Credible_Billing_Group_Id__c = getXmlNodeText(table, 'billing_group_name');

        // Approval fields
        appt.Credible_Appr__c = getXmlNodeBoolean(table, 'appr');
        appt.Credible_Appr_Date__c = parseDateTime(getXmlNodeText(table, 'appr_date'));
        appt.Credible_Appr_User__c = getXmlNodeText(table, 'appr_user');
        appt.Credible_Appr_Emp_Id__c = getXmlNodeText(table, 'appr_emp_id');

        // Combined visit fields
        appt.Credible_Comb_Primary__c = getXmlNodeBoolean(table, 'comb_primary');
        appt.Credible_Comb_Secondary__c = getXmlNodeBoolean(table, 'comb_secondary');
        appt.Credible_Comb_Parent_Id__c = getXmlNodeText(table, 'comb_parent_id');
        appt.Credible_Comb_Timeout__c = parseDateTime(getXmlNodeText(table, 'comb_timeout'));
        appt.Credible_Comb_Duration__c = getXmlNodeInteger(table, 'comb_duration');
        appt.Credible_Comb_Units__c = getXmlNodeDecimal(table, 'comb_units');
        appt.Credible_Comb_Rate__c = getXmlNodeDecimal(table, 'comb_rate');
        appt.Credible_Multiple_Flag__c = getXmlNodeBoolean(table, 'multiple_flag');

        // Other fields
        appt.Credible_Plan_Id__c = getXmlNodeText(table, 'plan_id');
        appt.Credible_Team_Id__c = getXmlNodeText(table, 'team_name');
        appt.Credible_Visit_Dateday__c = getXmlNodeInteger(table, 'visit_dateday');
        appt.Credible_Visitguid__c = getXmlNodeText(table, 'visitguid');
        appt.Credible_Credentials__c = getXmlNodeText(table, 'credentials');
        appt.Credible_Signature_Datetime__c = parseDateTime(getXmlNodeText(table, 'signature_datetime'));
        appt.Credible_Form_Ver_Id__c = getXmlNodeText(table, 'form_ver_id');

        // CPT Modifiers
        appt.Credible_CPT_Modifier_1__c = getXmlNodeText(table, 'cpt_modifier1');
        appt.Credible_CPT_Modifier_2__c = getXmlNodeText(table, 'cpt_modifier2');
        appt.Credible_CPT_Modifier_3__c = getXmlNodeText(table, 'cpt_modifier3');
        appt.Credible_CPT_Modifier_4__c = getXmlNodeText(table, 'cpt_modifier4');

        // Notes and comments
        appt.Credible_Notes__c = getXmlNodeText(table, 'notes');
        appt.Credible_Reviewer_Comment__c = getXmlNodeText(table, 'reviewer_comment');
        appt.Credible_Summary_Notes__c = getXmlNodeText(table, 'summary_notes');
        appt.Credible_Reason_For_Visit__c = getXmlNodeText(table, 'reason_for_visit');
        appt.Credible_Chief_Complaint__c = getXmlNodeText(table, 'chief_complaint');

        // Flags
        appt.Credible_Unscheduled__c = getXmlNodeBoolean(table, 'unscheduled');
        appt.Credible_Auth_Exceeded__c = getXmlNodeBoolean(table, 'auth_exceeded');
        appt.Credible_Has_Picture__c = getXmlNodeBoolean(table, 'has_picture');
        appt.Credible_Is_Readonly__c = getXmlNodeBoolean(table, 'is_readonly');
        appt.Credible_Is_Emergency__c = getXmlNodeText(table, 'is_emergency');
        appt.Credible_Is_Late__c = getXmlNodeBoolean(table, 'is_late');
        appt.Credible_Non_Release__c = getXmlNodeBoolean(table, 'non_release');

        // ICD10 and other codes
        appt.Credible_ICD10_Code__c = getXmlNodeText(table, 'icd10_code');
        appt.Credible_External_Id__c = getXmlNodeText(table, 'external_id');
        appt.Credible_Title__c = getXmlNodeText(table, 'title');
        appt.Credible_Cotherapist__c = getXmlNodeText(table, 'cotherapist');
        appt.Credible_Source__c = getXmlNodeText(table, 'source');
        appt.Credible_Rem_Address__c = getXmlNodeText(table, 'rem_address');

        // Dates
        appt.Credible_Date_Created__c = parseDateTime(getXmlNodeText(table, 'date_created'));
        appt.Credible_Date_Updated__c = parseDateTime(getXmlNodeText(table, 'date_updated'));

        return appt;
    }

    /**
     * Get integer from XML node
     */
    private static Integer getXmlNodeInteger(Dom.XMLNode table, String elementName) {
        String text = getXmlNodeText(table, elementName);
        if (String.isBlank(text)) {
            return null;
        }

        try {
            return Integer.valueOf(text);
        } catch (Exception e) {
            System.debug('CredibleExportsService: Error parsing integer ' + elementName + ': ' + text);
            return null;
        }
    }

    /**
     * Get decimal from XML node
     */
    private static Decimal getXmlNodeDecimal(Dom.XMLNode table, String elementName) {
        String text = getXmlNodeText(table, elementName);
        if (String.isBlank(text)) {
            return null;
        }

        try {
            return Decimal.valueOf(text);
        } catch (Exception e) {
            System.debug('CredibleExportsService: Error parsing decimal ' + elementName + ': ' + text);
            return null;
        }
    }
}