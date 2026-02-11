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
     * Uses inline table.getChildElement pattern matching production code.
     * Only updates existing Opportunities that have a matching Credible_ID__c.
     * Also creates/links Contact records for new clients.
     */
    private static void processClientRecords(List<Dom.XMLNode> tables) {
        Set<String> clientProfileIds = new Set<String>();
        Map<String, Contact> existingContactsMap = new Map<String, Contact>();
        Map<String, Contact> contactsToInsert = new Map<String, Contact>();
        List<Contact> contactsToUpdate = new List<Contact>();

        // First pass: collect all client IDs
        for (Dom.XMLNode table : tables) {
            String clientId = table.getChildElement('client_id', null) != null && !isDataEncrypted(table.getChildElement('client_id', null).getText()) ? table.getChildElement('client_id', null).getText() : null;
            if (clientId != null) {
                clientProfileIds.add(clientId);
            }
        }

        // Query existing contacts with Credible Profile IDs (expanded field list for updates)
        for (Contact c : [SELECT Id, pstar__Contact_Type__c, pstar__Credible_Profile_ID__c, FirstName, LastName, Birthdate, Email, Phone, MailingStreet, MailingCity, MailingState, MailingPostalCode FROM Contact WHERE pstar__Contact_Type__c = 'Patient' AND pstar__Credible_Profile_ID__c IN :clientProfileIds]) {
            existingContactsMap.put(c.pstar__Credible_Profile_ID__c, c);
        }

        // Query existing Opportunities with matching Credible IDs
        Map<String, Opportunity> existingOppsMap = new Map<String, Opportunity>();
        for (Opportunity opp : [SELECT Id, pstar__Credible_ID__c, pstar__Patient__c FROM Opportunity WHERE pstar__Credible_ID__c IN :clientProfileIds]) {
            existingOppsMap.put(opp.pstar__Credible_ID__c, opp);
        }

        // Load field mappings for translateValue
        Map<String, Map<String, String>> fieldMappings = loadFieldMappings();

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        // Second pass: process each record with inline XML parsing
        for (Dom.XMLNode table : tables) {
            String clientId = table.getChildElement('client_id', null) != null && !isDataEncrypted(table.getChildElement('client_id', null).getText()) ? table.getChildElement('client_id', null).getText() : null;
            if (clientId == null) continue;

            // Parse common fields needed for contact creation/update
            String firstName = table.getChildElement('first_name', null) != null && !isDataEncrypted(table.getChildElement('first_name', null).getText()) ? table.getChildElement('first_name', null).getText() : null;
            String lastName = table.getChildElement('last_name', null) != null && !isDataEncrypted(table.getChildElement('last_name', null).getText()) ? table.getChildElement('last_name', null).getText() : null;
            Date dob = table.getChildElement('dob', null) != null && !isDataEncrypted(table.getChildElement('dob', null).getText()) ? Date.valueOf(table.getChildElement('dob', null).getText()) : null;
            String email = table.getChildElement('client_email', null) != null && !isDataEncrypted(table.getChildElement('client_email', null).getText()) ? table.getChildElement('client_email', null).getText() : null;
            String mobilePhone = table.getChildElement('mobile_phone', null) != null && !isDataEncrypted(table.getChildElement('mobile_phone', null).getText()) ? table.getChildElement('mobile_phone', null).getText() : null;
            String address1 = table.getChildElement('address1', null) != null && !isDataEncrypted(table.getChildElement('address1', null).getText()) ? table.getChildElement('address1', null).getText() : null;
            String city = table.getChildElement('city', null) != null && !isDataEncrypted(table.getChildElement('city', null).getText()) ? table.getChildElement('city', null).getText() : null;
            String state = table.getChildElement('state', null) != null && !isDataEncrypted(table.getChildElement('state', null).getText()) ? table.getChildElement('state', null).getText() : null;
            String stateTranslated = translateValue(fieldMappings, 'State', state);
            String zip = table.getChildElement('zip', null) != null && !isDataEncrypted(table.getChildElement('zip', null).getText()) ? table.getChildElement('zip', null).getText() : null;

            // Handle contact creation for new clients or update for existing contacts
            if (existingContactsMap.containsKey(clientId)) {
                // Update existing contact with latest data from Credible
                Contact existingContact = existingContactsMap.get(clientId);
                Contact updContact = new Contact(Id = existingContact.Id);
                String emailVal = email;
                if (String.isBlank(emailVal) || emailVal.contains('N/A') || !isValidEmail(emailVal)) {
                    emailVal = null;
                }
                updContact.FirstName = firstName;
                updContact.LastName = String.isBlank(lastName) ? 'Unknown' : lastName;
                updContact.Birthdate = dob;
                updContact.Email = emailVal;
                updContact.Phone = mobilePhone;
                updContact.MailingStreet = address1;
                updContact.MailingCity = city;
                updContact.MailingState = stateTranslated;
                updContact.MailingPostalCode = zip;
                contactsToUpdate.add(updContact);
            } else if (!contactsToInsert.containsKey(clientId)) {
                String emailVal = email;
                if (String.isBlank(emailVal) || emailVal.contains('N/A') || !isValidEmail(emailVal)) {
                    emailVal = null;
                }
                Contact patient = new Contact(
                    pstar__Contact_Type__c = 'Patient',
                    pstar__Credible_Profile_ID__c = clientId,
                    FirstName = firstName,
                    LastName = String.isBlank(lastName) ? 'Unknown' : lastName,
                    Birthdate = dob,
                    Email = emailVal
                );
                contactsToInsert.put(clientId, patient);
            }

            // Skip if no matching Opportunity exists
            if (!existingOppsMap.containsKey(clientId)) continue;

            Opportunity existingOpp = existingOppsMap.get(clientId);
            Opportunity opp = new Opportunity(Id = existingOpp.Id);
            opp.pstar__Credible_ID__c = clientId;

            // ===== Name fields =====
            setField(opp, 'pstar__Patient_First_Name__c', firstName);
            setField(opp, 'pstar__Patient_Last_Name__c', lastName);

            String middleInitial = table.getChildElement('mi', null) != null && !isDataEncrypted(table.getChildElement('mi', null).getText()) ? table.getChildElement('mi', null).getText() : null;
            setField(opp, 'pstar__Middle_Initial__c', middleInitial);

            String preferredName = table.getChildElement('text21', null) != null && !isDataEncrypted(table.getChildElement('text21', null).getText()) ? table.getChildElement('text21', null).getText() : null;
            setField(opp, 'pstar__Peer_Preferred_Name__c', preferredName);

            // ===== Date fields =====
            setField(opp, 'pstar__DOB__c', dob);

            Date admissionDate = table.getChildElement('admission_date', null) != null && !isDataEncrypted(table.getChildElement('admission_date', null).getText()) ? Date.valueOf(table.getChildElement('admission_date', null).getText()) : null;
            setField(opp, 'pstar__Admission_Date__c', admissionDate);

            Date referralDate = table.getChildElement('referral_date', null) != null && !isDataEncrypted(table.getChildElement('referral_date', null).getText()) ? Date.valueOf(table.getChildElement('referral_date', null).getText()) : null;
            setField(opp, 'pstar__Referral_Date__c', referralDate);

            Date revisionDueDate = table.getChildElement('date1', null) != null && !isDataEncrypted(table.getChildElement('date1', null).getText()) ? Date.valueOf(table.getChildElement('date1', null).getText()) : null;
            setField(opp, 'pstar__Revision_Due_Date__c', revisionDueDate);

            Date dischargeDate = table.getChildElement('date14', null) != null && !isDataEncrypted(table.getChildElement('date14', null).getText()) ? Date.valueOf(table.getChildElement('date14', null).getText()) : null;
            setField(opp, 'pstar__Discharge_Date__c', dischargeDate);

            Date firstSvcDate = table.getChildElement('first_svc_date', null) != null && !isDataEncrypted(table.getChildElement('first_svc_date', null).getText()) ? Date.valueOf(table.getChildElement('first_svc_date', null).getText()) : null;
            setField(opp, 'pstar__First_Service_Date__c', firstSvcDate);

            Date lastSvcDate = table.getChildElement('last_svc_date', null) != null && !isDataEncrypted(table.getChildElement('last_svc_date', null).getText()) ? Date.valueOf(table.getChildElement('last_svc_date', null).getText()) : null;
            setField(opp, 'pstar__Last_Service_Date__c', lastSvcDate);

            Date dateAllergyLastUpdated = table.getChildElement('date_allergy_last_updated', null) != null && !isDataEncrypted(table.getChildElement('date_allergy_last_updated', null).getText()) ? Date.valueOf(table.getChildElement('date_allergy_last_updated', null).getText()) : null;
            setField(opp, 'pstar__Allergy_Last_Updated__c', dateAllergyLastUpdated);

            Date dateMedicationLastUpdated = table.getChildElement('date_medication_last_updated', null) != null && !isDataEncrypted(table.getChildElement('date_medication_last_updated', null).getText()) ? Date.valueOf(table.getChildElement('date_medication_last_updated', null).getText()) : null;
            setField(opp, 'pstar__Medications_Last_Updated__c', dateMedicationLastUpdated);

            Date firstBillSvcDate = table.getChildElement('first_bill_svc_date', null) != null && !isDataEncrypted(table.getChildElement('first_bill_svc_date', null).getText()) ? Date.valueOf(table.getChildElement('first_bill_svc_date', null).getText()) : null;
            setField(opp, 'pstar__First_Bill_Service_Date__c', firstBillSvcDate);

            Date lastBillSvcDate = table.getChildElement('last_bill_svc_date', null) != null && !isDataEncrypted(table.getChildElement('last_bill_svc_date', null).getText()) ? Date.valueOf(table.getChildElement('last_bill_svc_date', null).getText()) : null;
            setField(opp, 'pstar__Last_Bill_Service_Date__c', lastBillSvcDate);

            Date dateCreated = table.getChildElement('date_created', null) != null && !isDataEncrypted(table.getChildElement('date_created', null).getText()) ? Date.valueOf(table.getChildElement('date_created', null).getText()) : null;
            setField(opp, 'pstar__Date_Created__c', dateCreated);

            Date dateUpdated = table.getChildElement('date_updated', null) != null && !isDataEncrypted(table.getChildElement('date_updated', null).getText()) ? Date.valueOf(table.getChildElement('date_updated', null).getText()) : null;
            setField(opp, 'pstar__Date_Updated__c', dateUpdated);

            Date clientStatusDate = table.getChildElement('client_status_date', null) != null && !isDataEncrypted(table.getChildElement('client_status_date', null).getText()) ? Date.valueOf(table.getChildElement('client_status_date', null).getText()) : null;
            setField(opp, 'pstar__Last_Client_Status_Update__c', clientStatusDate);

            Date dateDiagnosisLastUpdated = table.getChildElement('date_diagnosis_last_updated', null) != null && !isDataEncrypted(table.getChildElement('date_diagnosis_last_updated', null).getText()) ? Date.valueOf(table.getChildElement('date_diagnosis_last_updated', null).getText()) : null;
            setField(opp, 'pstar__Date_Dx_Last_Updated__c', dateDiagnosisLastUpdated);

            Date dateOfDeath = table.getChildElement('date_of_death', null) != null && !isDataEncrypted(table.getChildElement('date_of_death', null).getText()) ? Date.valueOf(table.getChildElement('date_of_death', null).getText()) : null;
            setField(opp, 'pstar__Date_of_Death__c', dateOfDeath);

            Date authorizationDueDate = table.getChildElement('date10', null) != null && !isDataEncrypted(table.getChildElement('date10', null).getText()) ? Date.valueOf(table.getChildElement('date10', null).getText()) : null;
            setField(opp, 'pstar__Authorization_Due_Date__c', authorizationDueDate);

            Date smokingEndDate = table.getChildElement('smoking_end_date', null) != null && !isDataEncrypted(table.getChildElement('smoking_end_date', null).getText()) ? Date.valueOf(table.getChildElement('smoking_end_date', null).getText()) : null;
            setField(opp, 'pstar__Smoking_End_Date__c', smokingEndDate);

            String lastPsychEval = table.getChildElement('text5', null) != null && !isDataEncrypted(table.getChildElement('text5', null).getText()) ? table.getChildElement('text5', null).getText() : null;
            setField(opp, 'pstar__Last_Psych_Eval__c', lastPsychEval);

            // ===== Address fields =====
            setField(opp, 'pstar__Street_Address__c', address1);

            String address2 = table.getChildElement('address2', null) != null && !isDataEncrypted(table.getChildElement('address2', null).getText()) ? table.getChildElement('address2', null).getText() : null;
            setField(opp, 'pstar__Street_Address2__c', address2);

            setField(opp, 'pstar__Address_City__c', city);

            String county = table.getChildElement('county', null) != null && !isDataEncrypted(table.getChildElement('county', null).getText()) ? table.getChildElement('county', null).getText() : null;
            setField(opp, 'pstar__County__c', county);

            setField(opp, 'pstar__State__c', stateTranslated);

            setField(opp, 'pstar__Zip_Code__c', zip);

            // ===== Contact fields =====
            String homePhone = table.getChildElement('home_phone', null) != null && !isDataEncrypted(table.getChildElement('home_phone', null).getText()) ? table.getChildElement('home_phone', null).getText() : null;
            setField(opp, 'pstar__Home_Phone__c', homePhone);

            setField(opp, 'pstar__Mobile_Phone__c', mobilePhone);

            setField(opp, 'pstar__Email__c', email);

            String preferredContact = table.getChildElement('preferredcontactmethod', null) != null && !isDataEncrypted(table.getChildElement('preferredcontactmethod', null).getText()) ? table.getChildElement('preferredcontactmethod', null).getText() : null;
            setField(opp, 'pstar__Preferred_Contact__c', translateValue(fieldMappings, 'Preferred Contact', preferredContact));

            // ===== Demographics =====
            String gender = table.getChildElement('gender', null) != null && !isDataEncrypted(table.getChildElement('gender', null).getText()) ? table.getChildElement('gender', null).getText() : null;
            setField(opp, 'pstar__Gender__c', translateValue(fieldMappings, 'Gender', gender));

            String race = table.getChildElement('raceomb', null) != null && !isDataEncrypted(table.getChildElement('raceomb', null).getText()) ? table.getChildElement('raceomb', null).getText() : null;
            setField(opp, 'pstar__Race__c', translateValue(fieldMappings, 'Race', race));

            String ethnicity = table.getChildElement('ethnicityomb', null) != null && !isDataEncrypted(table.getChildElement('ethnicityomb', null).getText()) ? table.getChildElement('ethnicityomb', null).getText() : null;
            setField(opp, 'pstar__Ethnicity__c', translateValue(fieldMappings, 'Ethnicity', ethnicity));

            String maritalStatus = table.getChildElement('maritalstatus', null) != null && !isDataEncrypted(table.getChildElement('maritalstatus', null).getText()) ? table.getChildElement('maritalstatus', null).getText() : null;
            setField(opp, 'pstar__Marital_Status__c', translateValue(fieldMappings, 'Marital Status', maritalStatus));

            String sexualOrientation = table.getChildElement('sexualorientation', null) != null && !isDataEncrypted(table.getChildElement('sexualorientation', null).getText()) ? table.getChildElement('sexualorientation', null).getText() : null;
            setField(opp, 'pstar__Sexual_Orientation__c', translateValue(fieldMappings, 'Sexual Orientation', sexualOrientation));

            String genderIdentity = table.getChildElement('genderidentity', null) != null && !isDataEncrypted(table.getChildElement('genderidentity', null).getText()) ? table.getChildElement('genderidentity', null).getText() : null;
            setField(opp, 'pstar__Gender_Identity__c', translateValue(fieldMappings, 'Gender Identity', genderIdentity));

            String assignedSexAtBirth = table.getChildElement('assignedsexatbirth', null) != null && !isDataEncrypted(table.getChildElement('assignedsexatbirth', null).getText()) ? table.getChildElement('assignedsexatbirth', null).getText() : null;
            setField(opp, 'pstar__Assigned_sex_at_birth__c', translateValue(fieldMappings, 'Assigned Sex At Birth', assignedSexAtBirth));

            String preferredPronouns = table.getChildElement('preferredpronouns', null) != null && !isDataEncrypted(table.getChildElement('preferredpronouns', null).getText()) ? table.getChildElement('preferredpronouns', null).getText() : null;
            setField(opp, 'pstar__Preferred_Pronouns__c', translateValue(fieldMappings, 'Preferred Pronouns', preferredPronouns));

            Decimal age = table.getChildElement('age', null) != null && !isDataEncrypted(table.getChildElement('age', null).getText()) ? Decimal.valueOf(table.getChildElement('age', null).getText()) : null;
            setField(opp, 'pstar__Age__c', age);

            // ===== Encrypted fields =====
            String ssn = table.getChildElement('ssn', null) != null && !isDataEncrypted(table.getChildElement('ssn', null).getText()) ? table.getChildElement('ssn', null).getText() : null;
            setField(opp, 'pstar__Peer_ssn__c', ssn);

            String maid = table.getChildElement('text29', null) != null && !isDataEncrypted(table.getChildElement('text29', null).getText()) ? table.getChildElement('text29', null).getText() : null;
            setField(opp, 'pstar__MAID__c', maid);

            // ===== Status fields =====
            String clientStatus = table.getChildElement('client_status', null) != null && !isDataEncrypted(table.getChildElement('client_status', null).getText()) ? table.getChildElement('client_status', null).getText() : null;
            setField(opp, 'pstar__Status__c', clientStatus);

            String statusReason = table.getChildElement('status_reason', null) != null && !isDataEncrypted(table.getChildElement('status_reason', null).getText()) ? table.getChildElement('status_reason', null).getText() : null;
            setField(opp, 'pstar__Status_Reason__c', translateValue(fieldMappings, 'Status Reason', statusReason));

            String programType = table.getChildElement('program_type', null) != null && !isDataEncrypted(table.getChildElement('program_type', null).getText()) ? table.getChildElement('program_type', null).getText() : null;
            setField(opp, 'pstar__Program_Type__c', programType);

            String peerType = table.getChildElement('peertype', null) != null && !isDataEncrypted(table.getChildElement('peertype', null).getText()) ? table.getChildElement('peertype', null).getText() : null;
            setField(opp, 'pstar__Peer_Type__c', translateValue(fieldMappings, 'Peer Type', peerType));

            String functionalStatus = table.getChildElement('functional_status', null) != null && !isDataEncrypted(table.getChildElement('functional_status', null).getText()) ? table.getChildElement('functional_status', null).getText() : null;
            setField(opp, 'pstar__Referral_Notes__c', functionalStatus);

            // ===== Language =====
            String preferredLanguage = table.getChildElement('preferredlanguage', null) != null && !isDataEncrypted(table.getChildElement('preferredlanguage', null).getText()) ? table.getChildElement('preferredlanguage', null).getText() : null;
            setField(opp, 'pstar__Preferred_Language__c', translateValue(fieldMappings, 'Preferred Language', preferredLanguage));

            String primaryWrittenLanguage = table.getChildElement('primarywrittenlanguage', null) != null && !isDataEncrypted(table.getChildElement('primarywrittenlanguage', null).getText()) ? table.getChildElement('primarywrittenlanguage', null).getText() : null;
            setField(opp, 'pstar__Primary_Written_Language__c', translateValue(fieldMappings, 'Preferred Language', primaryWrittenLanguage));

            Boolean needInterpreter = table.getChildElement('deaf', null) != null && !isDataEncrypted(table.getChildElement('deaf', null).getText()) ? Boolean.valueOf(table.getChildElement('deaf', null).getText()) : null;
            setField(opp, 'pstar__Need_Interpreter__c', needInterpreter);

            // ===== Living/Lifestyle =====
            String livingSituation = table.getChildElement('livingsituation', null) != null && !isDataEncrypted(table.getChildElement('livingsituation', null).getText()) ? table.getChildElement('livingsituation', null).getText() : null;
            setField(opp, 'pstar__Living_Situation__c', translateValue(fieldMappings, 'Living Situation', livingSituation));

            String cpsPreference = table.getChildElement('text28', null) != null && !isDataEncrypted(table.getChildElement('text28', null).getText()) ? table.getChildElement('text28', null).getText() : null;
            setField(opp, 'pstar__CPS_Preference__c', cpsPreference);

            String smokingStatus = table.getChildElement('smokingstatus', null) != null && !isDataEncrypted(table.getChildElement('smokingstatus', null).getText()) ? table.getChildElement('smokingstatus', null).getText() : null;
            setField(opp, 'pstar__Smoking_Status__c', translateValue(fieldMappings, 'Smoking Status', smokingStatus));

            Boolean petsInHome = table.getChildElement('bool12', null) != null && !isDataEncrypted(table.getChildElement('bool12', null).getText()) ? Boolean.valueOf(table.getChildElement('bool12', null).getText()) : null;
            setField(opp, 'pstar__Are_there_pets_in_home__c', petsInHome);

            String ifPetsWhatKind = table.getChildElement('text20', null) != null && !isDataEncrypted(table.getChildElement('text20', null).getText()) ? table.getChildElement('text20', null).getText() : null;
            setField(opp, 'pstar__If_pets_Yes_what_kind__c', ifPetsWhatKind);

            Boolean petAggression = table.getChildElement('bool29', null) != null && !isDataEncrypted(table.getChildElement('bool29', null).getText()) ? Boolean.valueOf(table.getChildElement('bool29', null).getText()) : null;
            setField(opp, 'pstar__Hx_of_pet_aggression__c', petAggression);

            Boolean agreesCrimHx = table.getChildElement('bool6', null) != null && !isDataEncrypted(table.getChildElement('bool6', null).getText()) ? Boolean.valueOf(table.getChildElement('bool6', null).getText()) : null;
            setField(opp, 'pstar__Agrees_to_staff_w_Crim_Hx__c', agreesCrimHx);

            Boolean callAsPeerstar = table.getChildElement('donotcall', null) != null && !isDataEncrypted(table.getChildElement('donotcall', null).getText()) ? Boolean.valueOf(table.getChildElement('donotcall', null).getText()) : null;
            setField(opp, 'pstar__May_we_call_as_Peerstar__c', callAsPeerstar);

            Boolean deniedTransportation = table.getChildElement('bool22', null) != null && !isDataEncrypted(table.getChildElement('bool22', null).getText()) ? Boolean.valueOf(table.getChildElement('bool22', null).getText()) : null;
            setField(opp, 'pstar__Denied_Transportation__c', deniedTransportation);

            Boolean doNotBillMail = table.getChildElement('do_not_bill_direct', null) != null && !isDataEncrypted(table.getChildElement('do_not_bill_direct', null).getText()) ? Boolean.valueOf(table.getChildElement('do_not_bill_direct', null).getText()) : null;
            setField(opp, 'pstar__Do_Not_Bill_Mail__c', doNotBillMail);

            Boolean isRestricted = table.getChildElement('is_restricted', null) != null && !isDataEncrypted(table.getChildElement('is_restricted', null).getText()) ? Boolean.valueOf(table.getChildElement('is_restricted', null).getText()) : null;
            setField(opp, 'pstar__Is_Restricted__c', isRestricted);

            Boolean peerAssigned = table.getChildElement('bool17', null) != null && !isDataEncrypted(table.getChildElement('bool17', null).getText()) ? Boolean.valueOf(table.getChildElement('bool17', null).getText()) : null;
            setField(opp, 'pstar__Peer_Assigned__c', peerAssigned);

            String nextApptDate = table.getChildElement('next_appt_date', null) != null && !isDataEncrypted(table.getChildElement('next_appt_date', null).getText()) ? table.getChildElement('next_appt_date', null).getText() : null;
            setField(opp, 'pstar__Next_Appt_Date__c', nextApptDate);

            Boolean anyAllergies = table.getChildElement('no_allergy_flag', null) != null && !isDataEncrypted(table.getChildElement('no_allergy_flag', null).getText()) ? Boolean.valueOf(table.getChildElement('no_allergy_flag', null).getText()) : null;
            setField(opp, 'pstar__Any_Allergies__c', anyAllergies);

            Boolean noMedications = table.getChildElement('no_med_flag', null) != null && !isDataEncrypted(table.getChildElement('no_med_flag', null).getText()) ? Boolean.valueOf(table.getChildElement('no_med_flag', null).getText()) : null;
            setField(opp, 'pstar__No_Medications__c', noMedications);

            Boolean highNoShow = table.getChildElement('high_no_show', null) != null && !isDataEncrypted(table.getChildElement('high_no_show', null).getText()) ? Boolean.valueOf(table.getChildElement('high_no_show', null).getText()) : null;
            setField(opp, 'pstar__Is_High_No_Show__c', highNoShow);

            Boolean communicateViaEmail = table.getChildElement('bool30', null) != null && !isDataEncrypted(table.getChildElement('bool30', null).getText()) ? Boolean.valueOf(table.getChildElement('bool30', null).getText()) : null;
            setField(opp, 'pstar__Communicate_via_email__c', communicateViaEmail);

            Boolean communicateViaText = table.getChildElement('bool31', null) != null && !isDataEncrypted(table.getChildElement('bool31', null).getText()) ? Boolean.valueOf(table.getChildElement('bool31', null).getText()) : null;
            setField(opp, 'pstar__Communicate_via_text__c', communicateViaText);

            // ===== Service delivery =====
            Boolean srvcTelehealth = table.getChildElement('bool23', null) != null && !isDataEncrypted(table.getChildElement('bool23', null).getText()) ? Boolean.valueOf(table.getChildElement('bool23', null).getText()) : null;
            setField(opp, 'pstar__Type_of_srvc_Telehealth__c', srvcTelehealth);

            Boolean srvcTelephone = table.getChildElement('bool24', null) != null && !isDataEncrypted(table.getChildElement('bool24', null).getText()) ? Boolean.valueOf(table.getChildElement('bool24', null).getText()) : null;
            setField(opp, 'pstar__Type_of_srvc_Telephone__c', srvcTelephone);

            Boolean srvcF2f = table.getChildElement('bool25', null) != null && !isDataEncrypted(table.getChildElement('bool25', null).getText()) ? Boolean.valueOf(table.getChildElement('bool25', null).getText()) : null;
            setField(opp, 'pstar__Type_of_srvc_F2F__c', srvcF2f);

            // ===== Medical/Clinical =====
            String facilityName = table.getChildElement('text3', null) != null && !isDataEncrypted(table.getChildElement('text3', null).getText()) ? table.getChildElement('text3', null).getText() : null;
            setField(opp, 'pstar__Facility_Name__c', facilityName);

            String pcp = table.getChildElement('text24', null) != null && !isDataEncrypted(table.getChildElement('text24', null).getText()) ? table.getChildElement('text24', null).getText() : null;
            setField(opp, 'pstar__Primary_Care_Physician__c', pcp);

            String psychiatrist = table.getChildElement('text25', null) != null && !isDataEncrypted(table.getChildElement('text25', null).getText()) ? table.getChildElement('text25', null).getText() : null;
            setField(opp, 'pstar__Psychiatrist__c', psychiatrist);

            String diagnosisIntake = table.getChildElement('text26', null) != null && !isDataEncrypted(table.getChildElement('text26', null).getText()) ? table.getChildElement('text26', null).getText() : null;
            setField(opp, 'pstar__Diagnosis_Intake__c', diagnosisIntake);

            String diagnosisPrimary = table.getChildElement('axis_1', null) != null && !isDataEncrypted(table.getChildElement('axis_1', null).getText()) ? table.getChildElement('axis_1', null).getText() : null;
            setField(opp, 'pstar__Diagnosis_Primary__c', diagnosisPrimary);

            String reasonSeeking = table.getChildElement('textlong1', null) != null && !isDataEncrypted(table.getChildElement('textlong1', null).getText()) ? table.getChildElement('textlong1', null).getText() : null;
            setField(opp, 'pstar__Reason_Seeking_Services__c', reasonSeeking);

            String medicalProblems = table.getChildElement('textlong2', null) != null && !isDataEncrypted(table.getChildElement('textlong2', null).getText()) ? table.getChildElement('textlong2', null).getText() : null;
            setField(opp, 'pstar__Medical_Problems__c', medicalProblems);

            String noAdmitReason = table.getChildElement('noadmitreason', null) != null && !isDataEncrypted(table.getChildElement('noadmitreason', null).getText()) ? table.getChildElement('noadmitreason', null).getText() : null;
            setField(opp, 'pstar__No_Admit_Reason__c', translateValue(fieldMappings, 'No Admit Reason', noAdmitReason));

            String forensicStatus = table.getChildElement('forensicstatus', null) != null && !isDataEncrypted(table.getChildElement('forensicstatus', null).getText()) ? table.getChildElement('forensicstatus', null).getText() : null;
            setField(opp, 'pstar__Forensic_Status__c', translateValue(fieldMappings, 'Forensic Status', forensicStatus));

            String signatureSource = table.getChildElement('clientsignaturesource', null) != null && !isDataEncrypted(table.getChildElement('clientsignaturesource', null).getText()) ? table.getChildElement('clientsignaturesource', null).getText() : null;
            setField(opp, 'pstar__Client_Signature_Source__c', translateValue(fieldMappings, 'Client Signature Source', signatureSource));

            String releaseOfInfo = table.getChildElement('releaseofinformation', null) != null && !isDataEncrypted(table.getChildElement('releaseofinformation', null).getText()) ? table.getChildElement('releaseofinformation', null).getText() : null;
            setField(opp, 'pstar__Release_Of_Information__c', translateValue(fieldMappings, 'Release Of Information', releaseOfInfo));

            String howHeard = table.getChildElement('text2', null) != null && !isDataEncrypted(table.getChildElement('text2', null).getText()) ? table.getChildElement('text2', null).getText() : null;
            setField(opp, 'pstar__How_did_you_hear_of_us__c', howHeard);

            Boolean idd = table.getChildElement('bool40', null) != null && !isDataEncrypted(table.getChildElement('bool40', null).getText()) ? Boolean.valueOf(table.getChildElement('bool40', null).getText()) : null;
            setField(opp, 'pstar__IDD__c', idd);

            // ===== Trauma/Behavioral History =====
            Boolean traumaHx = table.getChildElement('bool1', null) != null && !isDataEncrypted(table.getChildElement('bool1', null).getText()) ? Boolean.valueOf(table.getChildElement('bool1', null).getText()) : null;
            setField(opp, 'pstar__Is_There_a_Hx_of_Trauma__c', traumaHx);

            String ifYesActionTaken = table.getChildElement('text10', null) != null && !isDataEncrypted(table.getChildElement('text10', null).getText()) ? table.getChildElement('text10', null).getText() : null;
            setField(opp, 'pstar__If_Yes_Action_Taken__c', ifYesActionTaken);

            Boolean victimOfBullying = table.getChildElement('bool27', null) != null && !isDataEncrypted(table.getChildElement('bool27', null).getText()) ? Boolean.valueOf(table.getChildElement('bool27', null).getText()) : null;
            setField(opp, 'pstar__Been_victim_of_bullying__c', victimOfBullying);

            String dd33HowLongAgo = table.getChildElement('ifyeshowlongago_dd33', null) != null && !isDataEncrypted(table.getChildElement('ifyeshowlongago_dd33', null).getText()) ? table.getChildElement('ifyeshowlongago_dd33', null).getText() : null;
            setField(opp, 'pstar__dd33_If_yes_How_long_ago__c', dd33HowLongAgo);

            Boolean bulliedOthers = table.getChildElement('bool28', null) != null && !isDataEncrypted(table.getChildElement('bool28', null).getText()) ? Boolean.valueOf(table.getChildElement('bool28', null).getText()) : null;
            setField(opp, 'pstar__Have_you_bullied_others__c', bulliedOthers);

            String dd34HowLongAgo = table.getChildElement('ifyeshowlongago_dd34', null) != null && !isDataEncrypted(table.getChildElement('ifyeshowlongago_dd34', null).getText()) ? table.getChildElement('ifyeshowlongago_dd34', null).getText() : null;
            setField(opp, 'pstar__dd34_If_yes_How_long_ago__c', dd34HowLongAgo);

            // ===== Drug/Alcohol History =====
            Boolean daHx = table.getChildElement('bool3', null) != null && !isDataEncrypted(table.getChildElement('bool3', null).getText()) ? Boolean.valueOf(table.getChildElement('bool3', null).getText()) : null;
            setField(opp, 'pstar__Is_There_a_Hx_of_DA_Use__c', daHx);

            String daIfYesSpecify = table.getChildElement('text11', null) != null && !isDataEncrypted(table.getChildElement('text11', null).getText()) ? table.getChildElement('text11', null).getText() : null;
            setField(opp, 'pstar__DA_If_Yes_Specify__c', daIfYesSpecify);

            Boolean participatedDATx = table.getChildElement('bool2', null) != null && !isDataEncrypted(table.getChildElement('bool2', null).getText()) ? Boolean.valueOf(table.getChildElement('bool2', null).getText()) : null;
            setField(opp, 'pstar__Participated_in_DA_Tx__c', participatedDATx);

            String daTxIfYesSpecify = table.getChildElement('text6', null) != null && !isDataEncrypted(table.getChildElement('text6', null).getText()) ? table.getChildElement('text6', null).getText() : null;
            setField(opp, 'pstar__DA_Tx_If_Yes_Specify__c', daTxIfYesSpecify);

            // ===== Treatment History =====
            Boolean inpatientTrtmntHx = table.getChildElement('bool8', null) != null && !isDataEncrypted(table.getChildElement('bool8', null).getText()) ? Boolean.valueOf(table.getChildElement('bool8', null).getText()) : null;
            setField(opp, 'pstar__Inpatient_Trtmnt_Hx__c', inpatientTrtmntHx);

            String inptTxLocationDates = table.getChildElement('text15', null) != null && !isDataEncrypted(table.getChildElement('text15', null).getText()) ? table.getChildElement('text15', null).getText() : null;
            setField(opp, 'pstar__Inpt_Tx_Location_Dates__c', inptTxLocationDates);

            Boolean daInptTrtmntHx = table.getChildElement('bool9', null) != null && !isDataEncrypted(table.getChildElement('bool9', null).getText()) ? Boolean.valueOf(table.getChildElement('bool9', null).getText()) : null;
            setField(opp, 'pstar__DA_Inpt_Trtmnt_Hx__c', daInptTrtmntHx);

            String daInptTxLocationDates = table.getChildElement('text16', null) != null && !isDataEncrypted(table.getChildElement('text16', null).getText()) ? table.getChildElement('text16', null).getText() : null;
            setField(opp, 'pstar__DA_Inpt_TxLocation_Dates__c', daInptTxLocationDates);

            Boolean outptTherapyTrtmntHx = table.getChildElement('bool10', null) != null && !isDataEncrypted(table.getChildElement('bool10', null).getText()) ? Boolean.valueOf(table.getChildElement('bool10', null).getText()) : null;
            setField(opp, 'pstar__Outpt_Therapy_Trtmnt_Hx__c', outptTherapyTrtmntHx);

            String outptTxLocationDates = table.getChildElement('text17', null) != null && !isDataEncrypted(table.getChildElement('text17', null).getText()) ? table.getChildElement('text17', null).getText() : null;
            setField(opp, 'pstar__Outpt_Tx_Location_Dates__c', outptTxLocationDates);

            Boolean residentialTrtmntHx = table.getChildElement('bool11', null) != null && !isDataEncrypted(table.getChildElement('bool11', null).getText()) ? Boolean.valueOf(table.getChildElement('bool11', null).getText()) : null;
            setField(opp, 'pstar__Residential_Trtmnt_Hx__c', residentialTrtmntHx);

            String residentialLocationDates = table.getChildElement('text18', null) != null && !isDataEncrypted(table.getChildElement('text18', null).getText()) ? table.getChildElement('text18', null).getText() : null;
            setField(opp, 'pstar__ResidentialLocation_Dates__c', residentialLocationDates);

            String otherServiceInvolvement = table.getChildElement('text8', null) != null && !isDataEncrypted(table.getChildElement('text8', null).getText()) ? table.getChildElement('text8', null).getText() : null;
            setField(opp, 'pstar__Other_Service_Involvement__c', otherServiceInvolvement);

            // ===== Legal =====
            Boolean legalInvolve = table.getChildElement('bool4', null) != null && !isDataEncrypted(table.getChildElement('bool4', null).getText()) ? Boolean.valueOf(table.getChildElement('bool4', null).getText()) : null;
            setField(opp, 'pstar__Legal_Involve_in_Past_Yr__c', legalInvolve);

            String ifYesSpecifyOnForm = table.getChildElement('text7', null) != null && !isDataEncrypted(table.getChildElement('text7', null).getText()) ? table.getChildElement('text7', null).getText() : null;
            setField(opp, 'pstar__If_Yes_Specify_on_Form__c', ifYesSpecifyOnForm);

            // ===== Military =====
            Boolean servedInMilitary = table.getChildElement('bool5', null) != null && !isDataEncrypted(table.getChildElement('bool5', null).getText()) ? Boolean.valueOf(table.getChildElement('bool5', null).getText()) : null;
            setField(opp, 'pstar__Served_In_Military__c', servedInMilitary);

            String ifYesWhenBranch = table.getChildElement('text9', null) != null && !isDataEncrypted(table.getChildElement('text9', null).getText()) ? table.getChildElement('text9', null).getText() : null;
            setField(opp, 'pstar__If_Yes_When_Branch__c', ifYesWhenBranch);

            // ===== Employment =====
            Boolean employed = table.getChildElement('bool7', null) != null && !isDataEncrypted(table.getChildElement('bool7', null).getText()) ? Boolean.valueOf(table.getChildElement('bool7', null).getText()) : null;
            setField(opp, 'pstar__Employed__c', employed);

            String placeOfEmployment = table.getChildElement('text12', null) != null && !isDataEncrypted(table.getChildElement('text12', null).getText()) ? table.getChildElement('text12', null).getText() : null;
            setField(opp, 'pstar__Place_of_Employment__c', placeOfEmployment);

            // ===== Referral =====
            String referralSource = table.getChildElement('text33', null) != null && !isDataEncrypted(table.getChildElement('text33', null).getText()) ? table.getChildElement('text33', null).getText() : null;
            setField(opp, 'pstar__Referred_By__c', translateValue(fieldMappings, 'Referral Source', referralSource));

            String referralType = table.getChildElement('referralsource', null) != null && !isDataEncrypted(table.getChildElement('referralsource', null).getText()) ? table.getChildElement('referralsource', null).getText() : null;
            setField(opp, 'pstar__Referral_Type__c', translateValue(fieldMappings, 'Referral Type', referralType));

            String referralPhone = table.getChildElement('text1', null) != null && !isDataEncrypted(table.getChildElement('text1', null).getText()) ? table.getChildElement('text1', null).getText() : null;
            setField(opp, 'pstar__Referral_Phone__c', referralPhone);

            Boolean webReferral = table.getChildElement('bool26', null) != null && !isDataEncrypted(table.getChildElement('bool26', null).getText()) ? Boolean.valueOf(table.getChildElement('bool26', null).getText()) : null;
            setField(opp, 'pstar__Web_Referral__c', webReferral);

            // ===== Referring Provider =====
            String referringProvider = table.getChildElement('providerdetails', null) != null && !isDataEncrypted(table.getChildElement('providerdetails', null).getText()) ? table.getChildElement('providerdetails', null).getText() : null;
            setField(opp, 'pstar__Referring_Provider__c', referringProvider);

            String referringProvider2 = table.getChildElement('referred_by', null) != null && !isDataEncrypted(table.getChildElement('referred_by', null).getText()) ? table.getChildElement('referred_by', null).getText() : null;
            setField(opp, 'pstar__Referring_Provider_2__c', referringProvider2);

            String referringNpi = table.getChildElement('referred_npi', null) != null && !isDataEncrypted(table.getChildElement('referred_npi', null).getText()) ? table.getChildElement('referred_npi', null).getText() : null;
            setField(opp, 'pstar__Referring_NPI__c', referringNpi);

            String referringMa = table.getChildElement('referred_id', null) != null && !isDataEncrypted(table.getChildElement('referred_id', null).getText()) ? table.getChildElement('referred_id', null).getText() : null;
            setField(opp, 'pstar__Referring_MA__c', referringMa);

            String referringQualifier = table.getChildElement('referred_id_qualifier', null) != null && !isDataEncrypted(table.getChildElement('referred_id_qualifier', null).getText()) ? table.getChildElement('referred_id_qualifier', null).getText() : null;
            setField(opp, 'pstar__Referring_Qualifier__c', referringQualifier);

            // ===== Availability =====
            String availableDays = table.getChildElement('text13', null) != null && !isDataEncrypted(table.getChildElement('text13', null).getText()) ? table.getChildElement('text13', null).getText() : null;
            setField(opp, 'pstar__Available_Days__c', availableDays);

            String availableTimes = table.getChildElement('text14', null) != null && !isDataEncrypted(table.getChildElement('text14', null).getText()) ? table.getChildElement('text14', null).getText() : null;
            setField(opp, 'pstar__Available_Times__c', availableTimes);

            // ===== Authorization =====
            String auth6or12Month = table.getChildElement('num1', null) != null && !isDataEncrypted(table.getChildElement('num1', null).getText()) ? table.getChildElement('num1', null).getText() : null;
            setField(opp, 'pstar__Auth_6_or_12_Month__c', auth6or12Month);

            // ===== DOC/IDs =====
            String docNumber = table.getChildElement('text35', null) != null && !isDataEncrypted(table.getChildElement('text35', null).getText()) ? table.getChildElement('text35', null).getText() : null;
            setField(opp, 'pstar__DOC_Number__c', docNumber);

            String bsu = table.getChildElement('text40', null) != null && !isDataEncrypted(table.getChildElement('text40', null).getText()) ? table.getChildElement('text40', null).getText() : null;
            setField(opp, 'pstar__BSU__c', bsu);

            String philadelphiaId = table.getChildElement('text36', null) != null && !isDataEncrypted(table.getChildElement('text36', null).getText()) ? table.getChildElement('text36', null).getText() : null;
            setField(opp, 'pstar__Philadelphia_ID__c', philadelphiaId);

            // ===== Continued Stay =====
            String continuedStayRequire = table.getChildElement('textlong5', null) != null && !isDataEncrypted(table.getChildElement('textlong5', null).getText()) ? table.getChildElement('textlong5', null).getText() : null;
            setField(opp, 'pstar__Continued_Stay_Require__c', continuedStayRequire);

            // ===== Activity fields (text32-text50) =====
            String activityVf1 = table.getChildElement('text31', null) != null && !isDataEncrypted(table.getChildElement('text31', null).getText()) ? table.getChildElement('text31', null).getText() : null;
            setField(opp, 'pstar__Activity_VF1__c', activityVf1);

            String activityVid1 = table.getChildElement('text43', null) != null && !isDataEncrypted(table.getChildElement('text43', null).getText()) ? table.getChildElement('text43', null).getText() : null;
            setField(opp, 'pstar__Activity_VID1__c', activityVid1);

            String activityIiic1 = table.getChildElement('text37', null) != null && !isDataEncrypted(table.getChildElement('text37', null).getText()) ? table.getChildElement('text37', null).getText() : null;
            setField(opp, 'pstar__Activity_IIIC1__c', activityIiic1);

            String activityIiid1 = table.getChildElement('text38', null) != null && !isDataEncrypted(table.getChildElement('text38', null).getText()) ? table.getChildElement('text38', null).getText() : null;
            setField(opp, 'pstar__Activity_IIID1__c', activityIiid1);

            String activitiesResponse = table.getChildElement('textlong4', null) != null && !isDataEncrypted(table.getChildElement('textlong4', null).getText()) ? table.getChildElement('textlong4', null).getText() : null;
            setField(opp, 'pstar__Activities_Response__c', activitiesResponse);

            String activity36 = table.getChildElement('text32', null) != null && !isDataEncrypted(table.getChildElement('text32', null).getText()) ? table.getChildElement('text32', null).getText() : null;
            setField(opp, 'pstar__Activity_36__c', activity36);

            String activity37 = table.getChildElement('text39', null) != null && !isDataEncrypted(table.getChildElement('text39', null).getText()) ? table.getChildElement('text39', null).getText() : null;
            setField(opp, 'pstar__Activity_37__c', activity37);

            String activity38 = table.getChildElement('text41', null) != null && !isDataEncrypted(table.getChildElement('text41', null).getText()) ? table.getChildElement('text41', null).getText() : null;
            setField(opp, 'pstar__Activity_38__c', activity38);

            String activity39 = table.getChildElement('text42', null) != null && !isDataEncrypted(table.getChildElement('text42', null).getText()) ? table.getChildElement('text42', null).getText() : null;
            setField(opp, 'pstar__Activity_39__c', activity39);

            String activity40 = table.getChildElement('text44', null) != null && !isDataEncrypted(table.getChildElement('text44', null).getText()) ? table.getChildElement('text44', null).getText() : null;
            setField(opp, 'pstar__Activity_40__c', activity40);

            String activity41 = table.getChildElement('text45', null) != null && !isDataEncrypted(table.getChildElement('text45', null).getText()) ? table.getChildElement('text45', null).getText() : null;
            setField(opp, 'pstar__Activity_41__c', activity41);

            String activity42 = table.getChildElement('text46', null) != null && !isDataEncrypted(table.getChildElement('text46', null).getText()) ? table.getChildElement('text46', null).getText() : null;
            setField(opp, 'pstar__Activity_42__c', activity42);

            String activity43 = table.getChildElement('text47', null) != null && !isDataEncrypted(table.getChildElement('text47', null).getText()) ? table.getChildElement('text47', null).getText() : null;
            setField(opp, 'pstar__Activity_43__c', activity43);

            String activity44 = table.getChildElement('text48', null) != null && !isDataEncrypted(table.getChildElement('text48', null).getText()) ? table.getChildElement('text48', null).getText() : null;
            setField(opp, 'pstar__Activity_44__c', activity44);

            String activity45 = table.getChildElement('text49', null) != null && !isDataEncrypted(table.getChildElement('text49', null).getText()) ? table.getChildElement('text49', null).getText() : null;
            setField(opp, 'pstar__Activity_45__c', activity45);

            String activity46 = table.getChildElement('text50', null) != null && !isDataEncrypted(table.getChildElement('text50', null).getText()) ? table.getChildElement('text50', null).getText() : null;
            setField(opp, 'pstar__Activity_46__c', activity46);

            // ===== SDoH fields =====
            Boolean sdoh = table.getChildElement('bool39', null) != null && !isDataEncrypted(table.getChildElement('bool39', null).getText()) ? Boolean.valueOf(table.getChildElement('bool39', null).getText()) : null;
            setField(opp, 'pstar__SDoH__c', sdoh);

            Decimal sdohAnsaTotal = table.getChildElement('num12', null) != null && !isDataEncrypted(table.getChildElement('num12', null).getText()) ? Decimal.valueOf(table.getChildElement('num12', null).getText()) : null;
            setField(opp, 'pstar__SDoH_ANSA_Total__c', sdohAnsaTotal);

            String sdohBase = table.getChildElement('num13', null) != null && !isDataEncrypted(table.getChildElement('num13', null).getText()) ? table.getChildElement('num13', null).getText() : null;
            setField(opp, 'pstar__SDoH_Base__c', sdohBase);

            Decimal sdohGoal = table.getChildElement('num15', null) != null && !isDataEncrypted(table.getChildElement('num15', null).getText()) ? Decimal.valueOf(table.getChildElement('num15', null).getText()) : null;
            setField(opp, 'pstar__SDoH_Goal__c', sdohGoal);

            String sdohCurrentRating = table.getChildElement('sdohcurrentrating', null) != null && !isDataEncrypted(table.getChildElement('sdohcurrentrating', null).getText()) ? table.getChildElement('sdohcurrentrating', null).getText() : null;
            setField(opp, 'pstar__SDoH_Current_Rating__c', sdohCurrentRating);

            Decimal sdohSuggestedHrs = table.getChildElement('num17', null) != null && !isDataEncrypted(table.getChildElement('num17', null).getText()) ? Decimal.valueOf(table.getChildElement('num17', null).getText()) : null;
            setField(opp, 'pstar__SDoH_Suggested_Hrs__c', sdohSuggestedHrs);

            Decimal sdohRequestedHrs = table.getChildElement('num16', null) != null && !isDataEncrypted(table.getChildElement('num16', null).getText()) ? Decimal.valueOf(table.getChildElement('num16', null).getText()) : null;
            setField(opp, 'pstar__SDoH_Requested_Hrs__c', sdohRequestedHrs);

            String mgSdoh = table.getChildElement('textlong6', null) != null && !isDataEncrypted(table.getChildElement('textlong6', null).getText()) ? table.getChildElement('textlong6', null).getText() : null;
            setField(opp, 'pstar__MG_SDoH__c', mgSdoh);

            // ===== Goal fields =====
            String goalA = table.getChildElement('spouse_name', null) != null && !isDataEncrypted(table.getChildElement('spouse_name', null).getText()) ? table.getChildElement('spouse_name', null).getText() : null;
            setField(opp, 'pstar__Goal_A__c', goalA);

            String goalB = table.getChildElement('company', null) != null && !isDataEncrypted(table.getChildElement('company', null).getText()) ? table.getChildElement('company', null).getText() : null;
            setField(opp, 'pstar__Goal_B__c', goalB);

            String goalC = table.getChildElement('granular_ethnicity', null) != null && !isDataEncrypted(table.getChildElement('granular_ethnicity', null).getText()) ? table.getChildElement('granular_ethnicity', null).getText() : null;
            setField(opp, 'pstar__Goal_C__c', goalC);

            String goalD = table.getChildElement('immunization_publicity_code', null) != null && !isDataEncrypted(table.getChildElement('immunization_publicity_code', null).getText()) ? table.getChildElement('immunization_publicity_code', null).getText() : null;
            setField(opp, 'pstar__Goal_D__c', goalD);

            String goalE = table.getChildElement('granular_race', null) != null && !isDataEncrypted(table.getChildElement('granular_race', null).getText()) ? table.getChildElement('granular_race', null).getText() : null;
            setField(opp, 'pstar__Goal_E__c', goalE);

            String goalF = table.getChildElement('gender_identity', null) != null && !isDataEncrypted(table.getChildElement('gender_identity', null).getText()) ? table.getChildElement('gender_identity', null).getText() : null;
            setField(opp, 'pstar__Goal_F__c', goalF);

            String goalG = table.getChildElement('referred_upin', null) != null && !isDataEncrypted(table.getChildElement('referred_upin', null).getText()) ? table.getChildElement('referred_upin', null).getText() : null;
            setField(opp, 'pstar__Goal_G__c', goalG);

            String goalH = table.getChildElement('previous_name', null) != null && !isDataEncrypted(table.getChildElement('previous_name', null).getText()) ? table.getChildElement('previous_name', null).getText() : null;
            setField(opp, 'pstar__Goal_H__c', goalH);

            String goalI = table.getChildElement('emergency_contact', null) != null && !isDataEncrypted(table.getChildElement('emergency_contact', null).getText()) ? table.getChildElement('emergency_contact', null).getText() : null;
            setField(opp, 'pstar__Goal_I__c', goalI);

            String goalIih = table.getChildElement('text22', null) != null && !isDataEncrypted(table.getChildElement('text22', null).getText()) ? table.getChildElement('text22', null).getText() : null;
            setField(opp, 'pstar__Goal_IIH__c', goalIih);

            // ===== Activity A-I fields =====
            String activityA = table.getChildElement('sexual_orientation', null) != null && !isDataEncrypted(table.getChildElement('sexual_orientation', null).getText()) ? table.getChildElement('sexual_orientation', null).getText() : null;
            setField(opp, 'pstar__Activity_A__c', activityA);

            String activityB = table.getChildElement('text23', null) != null && !isDataEncrypted(table.getChildElement('text23', null).getText()) ? table.getChildElement('text23', null).getText() : null;
            setField(opp, 'pstar__Activity_B__c', activityB);

            String activityC = table.getChildElement('cognitive_status', null) != null && !isDataEncrypted(table.getChildElement('cognitive_status', null).getText()) ? table.getChildElement('cognitive_status', null).getText() : null;
            setField(opp, 'pstar__Activity_C__c', activityC);

            String activityD = table.getChildElement('text19', null) != null && !isDataEncrypted(table.getChildElement('text19', null).getText()) ? table.getChildElement('text19', null).getText() : null;
            setField(opp, 'pstar__Activity_D__c', activityD);

            String activityE = table.getChildElement('mother_maiden_name', null) != null && !isDataEncrypted(table.getChildElement('mother_maiden_name', null).getText()) ? table.getChildElement('mother_maiden_name', null).getText() : null;
            setField(opp, 'pstar__Activity_E__c', activityE);

            String activityF = table.getChildElement('suffix', null) != null && !isDataEncrypted(table.getChildElement('suffix', null).getText()) ? table.getChildElement('suffix', null).getText() : null;
            setField(opp, 'pstar__Activity_F__c', activityF);

            String activityG = table.getChildElement('text27', null) != null && !isDataEncrypted(table.getChildElement('text27', null).getText()) ? table.getChildElement('text27', null).getText() : null;
            setField(opp, 'pstar__Activity_G__c', activityG);

            String activityH = table.getChildElement('textlong3', null) != null && !isDataEncrypted(table.getChildElement('textlong3', null).getText()) ? table.getChildElement('textlong3', null).getText() : null;
            setField(opp, 'pstar__Activity_H__c', activityH);

            String activityI = table.getChildElement('text30', null) != null && !isDataEncrypted(table.getChildElement('text30', null).getText()) ? table.getChildElement('text30', null).getText() : null;
            setField(opp, 'pstar__Activity_I__c', activityI);

            String activityIih = table.getChildElement('textlong7', null) != null && !isDataEncrypted(table.getChildElement('textlong7', null).getText()) ? table.getChildElement('textlong7', null).getText() : null;
            setField(opp, 'pstar__Activity_IIH__c', activityIih);

            // ===== IRP/CRS =====
            String irpInvolvement = table.getChildElement('irpinvolvement', null) != null && !isDataEncrypted(table.getChildElement('irpinvolvement', null).getText()) ? table.getChildElement('irpinvolvement', null).getText() : null;
            setField(opp, 'pstar__IRP_involvement__c', irpInvolvement);

            Boolean crsReceivingCoe = table.getChildElement('bool21', null) != null && !isDataEncrypted(table.getChildElement('bool21', null).getText()) ? Boolean.valueOf(table.getChildElement('bool21', null).getText()) : null;
            setField(opp, 'pstar__CRS_receiving_COE_services__c', crsReceivingCoe);

            // Link contact if not already linked
            if (existingOpp.pstar__Patient__c == null) {
                if (existingContactsMap.containsKey(clientId)) {
                    opp.pstar__Patient__c = existingContactsMap.get(clientId).Id;
                }
            }

            oppsToUpdate.add(opp);
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

        // Update existing contacts with latest data from Credible
        if (!contactsToUpdate.isEmpty()) {
            Database.SaveResult[] contactUpdateResults = Database.update(contactsToUpdate, false);
            for (Integer i = 0; i < contactUpdateResults.size(); i++) {
                if (!contactUpdateResults[i].isSuccess()) {
                    System.debug('CredibleExportsService: Failed to update contact: ' + contactUpdateResults[i].getErrors());
                }
            }
        }

        // Link newly inserted contacts to Opportunities
        for (Opportunity opp : oppsToUpdate) {
            if (opp.pstar__Patient__c == null && contactsToInsert.containsKey(opp.pstar__Credible_ID__c)) {
                Contact insertedContact = contactsToInsert.get(opp.pstar__Credible_ID__c);
                if (insertedContact.Id != null) {
                    opp.pstar__Patient__c = insertedContact.Id;
                }
            }
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
     * Only set a field on the SObject if the value is not null.
     * Prevents overwriting existing Salesforce data when Credible has no value.
     */
    private static void setField(SObject record, String fieldName, Object value) {
        if (value == null) return;
        if (value instanceof String && String.isBlank((String) value)) return;
        record.put(fieldName, value);
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
     * If no mapping exists, returns null to prevent restricted picklist errors.
     */
    private static String translateValue(Map<String, Map<String, String>> mappings, String category, String credibleCode) {
        if (String.isBlank(credibleCode)) {
            return null;
        }
        if (!mappings.containsKey(category)) {
            System.debug('CredibleExportsService: No mapping category found for "' + category + '" with code "' + credibleCode + '"');
            return null;
        }
        Map<String, String> categoryMap = mappings.get(category);
        if (categoryMap.containsKey(credibleCode)) {
            return categoryMap.get(credibleCode);
        }
        System.debug('CredibleExportsService: No mapping found for category "' + category + '" code "' + credibleCode + '"');
        return null;
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
            return null;
        }

        return Boolean.valueOf(text);
    }

    /**
     * Check if data is encrypted (masked with X characters in Credible)
     */
    private static Boolean isDataEncrypted(String data) {
        if (String.isBlank(data)) return true;
        return Pattern.matches('(?i)^x+$', data);
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
        // County config
        Map<String, String> countyConfigMap = new Map<String, String>();
        for (pstar__Credible_County_Config__mdt cfg : [SELECT Id, DeveloperName, MasterLabel, pstar__County_Code__c FROM pstar__Credible_County_Config__mdt]) {
            countyConfigMap.put(cfg.pstar__County_Code__c, cfg.MasterLabel);
        }

        // Employee lookup wrapper
        EmployeeLookupWrapper el = new EmployeeLookupWrapper();
        for(pstar__Credible_Lookup__c lookupRecord: [SELECT Id, pstar__Credible_Lookup_Id__c, pstar__Credible_Table__c, pstar__Credible_Value__c, pstar__Credible_Lookup_Category__c FROM pstar__Credible_Lookup__c WHERE pstar__Credible_Table__c INCLUDES ('Employee')]){
            if(lookupRecord.pstar__Credible_Lookup_Category__c == 'State'){
                el.stateCodeMap.put(lookupRecord.pstar__Credible_Lookup_Id__c, lookupRecord.pstar__Credible_Value__c);
            } else if(lookupRecord.pstar__Credible_Lookup_Category__c == 'Gender'){
                el.genderCodeMap.put(lookupRecord.pstar__Credible_Lookup_Id__c, lookupRecord.pstar__Credible_Value__c);
            } else if(lookupRecord.pstar__Credible_Lookup_Category__c == 'Employment Status'){
                el.employmentstatusCodeMap.put(lookupRecord.pstar__Credible_Lookup_Id__c, lookupRecord.pstar__Credible_Value__c);
            } else if(lookupRecord.pstar__Credible_Lookup_Category__c == 'Regional Director'){
                el.regionalDirectorCodeMap.put(lookupRecord.pstar__Credible_Lookup_Id__c, lookupRecord.pstar__Credible_Value__c);
            } else if(lookupRecord.pstar__Credible_Lookup_Category__c == 'Race OMB'){
                el.raceCodeMap.put(lookupRecord.pstar__Credible_Lookup_Id__c, lookupRecord.pstar__Credible_Value__c);
            }
        }

        // First pass: Contact creation
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
                pstar__Contact_Type__c = 'Certified Peer Specialist'
            );
            conMap.put(newContact.Credible_ID__c,newContact);
            crediableIds.add(newContact.Credible_ID__c);
        }
        // Upsert contacts
        if(!conMap.isEmpty()){
            Database.UpsertResult[] results = Database.upsert(conMap.values(), Contact.Fields.Credible_ID__c, false);
            List<pstar__Error_Log__c> errorLogs = new List<pstar__Error_Log__c>();
            for (Integer i = 0; i < results.size(); i++) {
                Database.UpsertResult result = results[i];
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
                        pstar__Source_Table__c = 'Employee Contact',
                        pstar__Source_System_Id__c = conMap.values()[i].Credible_ID__c
                    ));
                }
            }
            if (!errorLogs.isEmpty()) {
                insert errorLogs;
            }
        }
        // Re-query contacts
        for(Contact conObj : [SELECT Id,Credible_ID__c FROM Contact WHERE Credible_ID__c IN: crediableIds]){
            conMap.put(conObj.Credible_ID__c,conObj);
        }

        // Second pass: Employee profiles with inline XML
        List<pstar__Employee_Profile__c> employeeProfiles = new List<pstar__Employee_Profile__c>();
        for (Dom.XMLNode table : tables) {
            String gender = table.getChildElement('gender', null) != null ? table.getChildElement('gender', null).getText() : '';
            String regionalSupportManager = table.getChildElement('dd6', null) != null ? table.getChildElement('dd6', null).getText() : '';
            String mainCountyWorkedIn = table.getChildElement('dd7', null) != null ? table.getChildElement('dd7', null).getText() : '';
            String county = table.getChildElement('text1', null) != null ? table.getChildElement('text1', null).getText() : '';
            String state = table.getChildElement('state', null) != null ? table.getChildElement('state', null).getText() : '';
            String employmentStatus = table.getChildElement('dd1', null) != null ? table.getChildElement('dd1', null).getText() : '';
            String race = table.getChildElement('dd12', null) != null ? table.getChildElement('dd12', null).getText() : '';
            pstar__Employee_Profile__c employeeProfile = new pstar__Employee_Profile__c();
            employeeProfile.Credible_ID__c = table.getChildElement('emp_id', null) != null ? table.getChildElement('emp_id', null).getText() : '';
            employeeProfile.pstar__Employee__c = conMap.containskey(employeeProfile.Credible_ID__c) ? conMap.get(employeeProfile.Credible_ID__c).Id : null;
            employeeProfile.Credible_Employee_First_Name__c = table.getChildElement('first_name', null) != null ? table.getChildElement('first_name', null).getText() : '';
            employeeProfile.Credible_Employee_Middle_Name__c = table.getChildElement('middle_name', null) != null ? table.getChildElement('middle_name', null).getText() : '';
            employeeProfile.Credible_Employee_Last_Name__c = table.getChildElement('last_name', null) != null ? table.getChildElement('last_name', null).getText() : '';
            employeeProfile.Credible_Employee_Preferred_Name__c = table.getChildElement('text24', null) != null ? table.getChildElement('text24', null).getText() : '';
            employeeProfile.Credible_Gender__c = !String.isBlank(gender) && el.genderCodeMap.containsKey(gender) ? el.genderCodeMap.get(gender) : '';
            employeeProfile.Credible_SSN__c = table.getChildElement('ssn', null) != null ? table.getChildElement('ssn', null).getText() : '';
            employeeProfile.Credible_DOB__c = table.getChildElement('dob', null) != null ? Date.valueOf(table.getChildElement('dob', null).getText()) : null;
            employeeProfile.Credible_Title__c = table.getChildElement('title', null) != null ? table.getChildElement('title', null).getText() : '';
            employeeProfile.Credible_address1__c = table.getChildElement('address1', null) != null ? table.getChildElement('address1', null).getText() : '';
            employeeProfile.Credible_address2__c = table.getChildElement('address2', null) != null ? table.getChildElement('address2', null).getText() : '';
            employeeProfile.Credible_City__c = table.getChildElement('city', null) != null ? table.getChildElement('city', null).getText() : '';
            employeeProfile.Credible_State__c = !String.isBlank(state) && el.stateCodeMap.containsKey(state) ? el.stateCodeMap.get(state) : '';
            employeeProfile.Credible_Zip_Code__c = table.getChildElement('zip', null) != null ? table.getChildElement('zip', null).getText() : '';
            employeeProfile.Credible_County__c = !String.isBlank(county) && countyConfigMap.containsKey(county) ? countyConfigMap.get(county) : '';
            employeeProfile.Credible_Home_Phone__c = table.getChildElement('home_phone', null) != null ? table.getChildElement('home_phone', null).getText() : '';
            employeeProfile.Credible_Mobile_Phone__c = table.getChildElement('mobile_phone', null) != null ? table.getChildElement('mobile_phone', null).getText() : '';
            employeeProfile.Credible_Work_Phone__c = table.getChildElement('work_phone', null) != null ? table.getChildElement('work_phone', null).getText() : '';
            employeeProfile.Credible_Email__c = table.getChildElement('email', null) != null ? table.getChildElement('email', null).getText() : '';
            employeeProfile.Credible_Status__c = table.getChildElement('emp_status', null) != null ? table.getChildElement('emp_status', null).getText() : '';
            employeeProfile.Credible_Personal_Email__c = table.getChildElement('text5', null) != null ? table.getChildElement('text5', null).getText() : '';
            employeeProfile.Credible_Employment_Status__c = !String.isBlank(employmentStatus) && el.employmentstatusCodeMap.containsKey(employmentStatus) ? el.employmentstatusCodeMap.get(employmentStatus) : '';
            employeeProfile.Credible_Emergency_Phone__c = table.getChildElement('emergency_phone', null) != null ? table.getChildElement('emergency_phone', null).getText() : '';
            employeeProfile.Credible_Emergency_Contact__c = table.getChildElement('emergency_contact', null) != null ? table.getChildElement('emergency_contact', null).getText() : '';
            employeeProfile.Credible_Can_Supervise__c = table.getChildElement('is_supervisor_flag', null) != null ? Boolean.valueOf(table.getChildElement('is_supervisor_flag', null).getText()) : false;
            employeeProfile.Credible_Part_Time__c = table.getChildElement('part_time', null) != null ? Boolean.valueOf(table.getChildElement('part_time', null).getText()) : false;
            employeeProfile.Credible_Date_Full_Time__c = table.getChildElement('date6', null) != null ? Date.valueOf(table.getChildElement('date6', null).getText()) : null;
            employeeProfile.Credible_Notes__c = table.getChildElement('notes', null) != null ? table.getChildElement('notes', null).getText() : '';
            employeeProfile.Credible_Profile_Code__c = table.getChildElement('profile_code', null) != null ? table.getChildElement('profile_code', null).getText() : '';
            employeeProfile.Credible_Id__c = table.getChildElement('emp_id', null) != null ? table.getChildElement('emp_id', null).getText() : '';
            employeeProfile.Credible_External_ID__c = table.getChildElement('external_id', null) != null ? table.getChildElement('external_id', null).getText() : '';
            employeeProfile.Credible_Username__c = table.getChildElement('username', null) != null ? table.getChildElement('username', null).getText() : '';
            employeeProfile.Credible_Date_Last_TimeSheet_Appr__c = table.getChildElement('date14', null) != null ? Date.valueOf(table.getChildElement('date14', null).getText()) : null;
            employeeProfile.Credible_FBI_Clearance_Date__c = table.getChildElement('date4', null) != null ? Date.valueOf(table.getChildElement('date4', null).getText()) : null;
            employeeProfile.Credible_Previous_Supervision__c = table.getChildElement('date17', null) != null ? Date.valueOf(table.getChildElement('date17', null).getText()) : null;
            employeeProfile.Credible_Date_of_Last_Supervision__c = table.getChildElement('date11', null) != null ? Date.valueOf(table.getChildElement('date11', null).getText()) : null;
            employeeProfile.Credible_Last_Supervised_By__c = table.getChildElement('text22', null) != null ? table.getChildElement('text22', null).getText() : '';
            employeeProfile.Credible_ANSA_Expiration_Date__c = table.getChildElement('date1', null) != null ? Date.valueOf(table.getChildElement('date1', null).getText()) : null;
            employeeProfile.Credible_CPS_Certificate_Date__c = table.getChildElement('date2', null) != null ? Date.valueOf(table.getChildElement('date2', null).getText()) : null;
            employeeProfile.Credible_CPSS_Certification_Date__c = table.getChildElement('date12', null) != null ? Date.valueOf(table.getChildElement('date12', null).getText()) : null;
            employeeProfile.Credible_CPS_CRS_training_hrs_due__c = table.getChildElement('date3', null) != null ? Date.valueOf(table.getChildElement('date3', null).getText()) : null;
            employeeProfile.Credible_CPS_PCB_Exp__c = table.getChildElement('date9', null) != null ? Date.valueOf(table.getChildElement('date9', null).getText()) : null;
            employeeProfile.Credible_CRS_Certificate_Date__c = table.getChildElement('date19', null) != null ? Date.valueOf(table.getChildElement('date19', null).getText()) : null;
            employeeProfile.Credible_CRS_PCB_Train_Expiration__c = table.getChildElement('date16', null) != null ? Date.valueOf(table.getChildElement('date16', null).getText()) : null;
            employeeProfile.Credible_Hire_Date__c = table.getChildElement('hire_date', null) != null ? Date.valueOf(table.getChildElement('hire_date', null).getText()) : null;
            employeeProfile.Credible_Child_Abuse_Clr_Date__c = table.getChildElement('date10', null) != null ? Date.valueOf(table.getChildElement('date10', null).getText()) : null;
            employeeProfile.Credible_Child_Abuse_Training__c = table.getChildElement('bool13', null) != null ? Boolean.valueOf(table.getChildElement('bool13', null).getText()) : false;
            employeeProfile.Credible_Suicide_Screening_Trnging__c = table.getChildElement('bool4', null) != null ? Boolean.valueOf(table.getChildElement('bool4', null).getText()) : false;
            employeeProfile.Credible_Credentials__c = table.getChildElement('credentials', null) != null ? table.getChildElement('credentials', null).getText() : '';
            employeeProfile.Credible_Veteran_Status__c = table.getChildElement('bool1', null) != null ? Boolean.valueOf(table.getChildElement('bool1', null).getText()) : false;
            employeeProfile.Credible_Criminal_EPATCH__c = table.getChildElement('text10', null) != null ? table.getChildElement('text10', null).getText() : '';
            employeeProfile.Credible_Comments__c = table.getChildElement('textlong1', null) != null ? table.getChildElement('textlong1', null).getText() : '';
            employeeProfile.Credible_Term_Date__c = table.getChildElement('term_date', null) != null ? Date.valueOf(table.getChildElement('term_date', null).getText()) : null;
            employeeProfile.Credible_Is_HR__c = table.getChildElement('is_hr', null) != null ? Boolean.valueOf(table.getChildElement('is_hr', null).getText()) : false;
            employeeProfile.Credible_Is_Clinical__c = table.getChildElement('is_clinical', null) != null ? Boolean.valueOf(table.getChildElement('is_clinical', null).getText()) : false;
            employeeProfile.Credible_Issued_iPad__c = table.getChildElement('text23', null) != null ? table.getChildElement('text23', null).getText() : '';
            employeeProfile.Credible_iPad_Returned__c = table.getChildElement('bool15', null) != null ? Boolean.valueOf(table.getChildElement('bool15', null).getText()) : false;
            employeeProfile.Credible_Criminal_History__c = table.getChildElement('bool5', null) != null ? Boolean.valueOf(table.getChildElement('bool5', null).getText()) : false;
            employeeProfile.Credible_Regional_Support_Manager__c = !String.isBlank(regionalSupportManager) && el.regionalDirectorCodeMap.containsKey(regionalSupportManager) ? el.regionalDirectorCodeMap.get(regionalSupportManager) : '';
            employeeProfile.Credible_HR_Packet_Complete__c = table.getChildElement('bool10', null) != null ? Boolean.valueOf(table.getChildElement('bool10', null).getText()) : false;
            employeeProfile.Credible_Main_County_Worked_In__c = !String.isBlank(mainCountyWorkedIn) && countyConfigMap.containsKey(mainCountyWorkedIn) ? countyConfigMap.get(mainCountyWorkedIn) : '';
            employeeProfile.Credible_LOA_Suspension_Date__c = table.getChildElement('date5', null) != null ? Date.valueOf(table.getChildElement('date5', null).getText()) : null;
            employeeProfile.Credible_LOA_FMLA_Return_Date__c = table.getChildElement('date20', null) != null ? Date.valueOf(table.getChildElement('date20', null).getText()) : null;
            employeeProfile.Credible_CPS_Initial_6_Hours_Appro__c = table.getChildElement('date15', null) != null ? Date.valueOf(table.getChildElement('date15', null).getText()) : null;
            employeeProfile.Credible_CRS_Initial_6_Hours_Appro__c = table.getChildElement('date8', null) != null ? Date.valueOf(table.getChildElement('date8', null).getText()) : null;
            employeeProfile.Credible_Initial_PCB_App_sent__c = table.getChildElement('bool7', null) != null ? Boolean.valueOf(table.getChildElement('bool7', null).getText()) : false;
            employeeProfile.Credible_Driver_license_expiration__c = table.getChildElement('date13', null) != null ? Date.valueOf(table.getChildElement('date13', null).getText()) : null;
            employeeProfile.Credible_Race__c = !String.isBlank(race) && el.raceCodeMap.containsKey(race) ? el.raceCodeMap.get(race) : '';
            employeeProfile.Credible_3_hour_CPSL__c = table.getChildElement('bool11', null) != null ? Boolean.valueOf(table.getChildElement('bool11', null).getText()) : false;
            employeeProfile.Credible_401k_Eligible__c = table.getChildElement('bool9', null) != null ? Boolean.valueOf(table.getChildElement('bool9', null).getText()) : false;
            employeeProfile.Credible_Date_Created__c = table.getChildElement('date_created', null) != null ? Date.valueOf(table.getChildElement('date_created', null).getText()) : null;
            employeeProfile.Credible_Date_Updated__c = table.getChildElement('date_updated', null) != null ? Date.valueOf(table.getChildElement('date_updated', null).getText()) : null;
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
        Map<String,Id> mapToStoreClientIdToOpp = new Map<String,Id>();
        Map<String,Id> mapToStoreEmpIdToEP = new Map<String,Id>();
        Set<String> setToStoreClientId = new Set<String>();
        Set<String> setToStoreEmpId = new Set<String>();

        List<pstar__Appointment__c> credibleVisits = new List<pstar__Appointment__c>();

        for (Dom.XMLNode table : tables) {
            pstar__Appointment__c visit = new pstar__Appointment__c();

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

        for(pstar__Employee_Profile__c ep : [Select Id,Credible_Id__c From pstar__Employee_Profile__c Where Credible_Id__c In :setToStoreEmpId]){
            mapToStoreEmpIdToEP.put(ep.Credible_Id__c,ep.Id);
        }

        for (Opportunity opp : [SELECT Id, pstar__Credible_ID__c FROM Opportunity WHERE pstar__Credible_ID__c IN :setToStoreClientId]) {
            mapToStoreClientIdToOpp.put(opp.pstar__Credible_ID__c, opp.Id);
        }

        if(!credibleVisits.isEmpty()) {
            for(pstar__Appointment__c app : credibleVisits){
                if(mapToStoreClientIdToOpp.containsKey(app.Credible_Client_Id__c)){
                    app.pstar__Referral__c = mapToStoreClientIdToOpp.get(app.Credible_Client_Id__c);
                }
                if(mapToStoreEmpIdToEP.containsKey(app.Credible_Emp_Id__c)){
                    app.pstar__Employee__c = mapToStoreEmpIdToEP.get(app.Credible_Emp_Id__c);
                }
            }
        }

        // Upsert records using Credible_Clientvisit_Id__c as external ID
        if(!credibleVisits.isEmpty()) {
            Database.UpsertResult[] results = Database.upsert(credibleVisits, pstar__Appointment__c.Fields.Credible_Clientvisit_Id__c, false);

            List<pstar__Error_Log__c> errorLogs = new List<pstar__Error_Log__c>();

            for(Integer i = 0; i < results.size(); i++) {

                Database.UpsertResult result = results[i];
                System.debug('result['+i+']=>'+results[i]);
                pstar__Appointment__c visit = credibleVisits[i];

                if(!result.isSuccess()) {
                    List<String> individualErrors = new List<String>();

                    for(Database.Error err : result.getErrors()) {
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
                        pstar__Source_System_Id__c = visit.Credible_Clientvisit_Id__c
                    ));
                }
            }

            if(!errorLogs.isEmpty()) {
                insert errorLogs;
            }
        }
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

    public class EmployeeLookupWrapper {
        public Map<String, String> genderCodeMap = new Map<String, String>();
        public Map<String, String> stateCodeMap = new Map<String, String>();
        public Map<String, String> employmentstatusCodeMap = new Map<String, String>();
        public Map<String, String> raceCodeMap = new Map<String, String>();
        public Map<String, String> regionalDirectorCodeMap = new Map<String, String>();
    }
}
