public class CredibleIntegrationService {

    /**
     * Get Opportunity's Credible info - used by wizard to check if profile exists.
     * Returns credibleId (if any) so the LWC can show "Create" vs "Update" language.
     */
    @AuraEnabled
    public static Map<String, String> getOpportunityCredibleInfo(Id opportunityId) {
        Map<String, String> result = new Map<String, String>();

        List<Opportunity> oppList = [
            SELECT Id, pstar__Credible_ID__c, pstar__Patient__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (oppList.isEmpty()) {
            throw new AuraHandledException('Opportunity not found.');
        }

        Opportunity opp = oppList[0];
        result.put('opportunityId', opp.Id);
        result.put('credibleId', opp.pstar__Credible_ID__c);
        result.put('hasCredibleProfile', String.isNotBlank(opp.pstar__Credible_ID__c) ? 'true' : 'false');
        return result;
    }

    @AuraEnabled
    public static String pushToCredible(Id opportunityId) {
        try {
            // Query Opportunity with all required fields
            List<Opportunity> oppList = [
                SELECT
                    Id,
                    pstar__Patient__c,
                    pstar__Patient__r.FirstName,
                    pstar__Patient__r.LastName,
                    pstar__Patient__r.pstar__Credible_Profile_ID__c,
                    pstar__Patient_First_Name__c,
                    pstar__Patient_Last_Name__c,
                    pstar__Middle_Initial__c,
                    pstar__Peer_Preferred_Name__c,
                    pstar__DOB__c,
                    pstar__Peer_ssn__c,
                    pstar__Street_Address__c,
                    pstar__Street_Address2__c,
                    pstar__Address_City__c,
                    pstar__State__c,
                    pstar__Zip_Code__c,
                    pstar__County__c,
                    pstar__Home_Phone__c,
                    pstar__Mobile_Phone__c,
                    pstar__Email__c,
                    pstar__Preferred_Contact__c,
                    pstar__Credible_ID__c,
                    pstar__Gender__c,
                    pstar__Race__c,
                    pstar__Ethnicity__c,
                    pstar__Marital_Status__c,
                    pstar__Sexual_Orientation__c,
                    pstar__Gender_Identity__c,
                    pstar__Assigned_sex_at_birth__c,
                    pstar__Preferred_Pronouns__c,
                    pstar__Status__c,
                    pstar__Status_Reason__c,
                    pstar__MAID__c,
                    pstar__Peer_Type__c,
                    pstar__Preferred_Language__c,
                    pstar__Primary_Written_Language__c,
                    pstar__Need_Interpreter__c,
                    pstar__Living_Situation__c,
                    pstar__CPS_Preference__c,
                    pstar__Smoking_Status__c,
                    pstar__Are_there_pets_in_home__c,
                    pstar__Hx_of_pet_aggression__c,
                    pstar__May_we_call_as_Peerstar__c,
                    pstar__Agrees_to_staff_w_Crim_Hx__c,
                    pstar__Type_of_srvc_F2F__c,
                    pstar__Type_of_srvc_Telehealth__c,
                    pstar__Type_of_srvc_Telephone__c,
                    pstar__Facility_Name__c,
                    pstar__Forensic_Status__c,
                    pstar__Client_Signature_Source__c,
                    pstar__Release_Of_Information__c,
                    pstar__Diagnosis_Intake__c,
                    pstar__Primary_Care_Physician__c,
                    pstar__Psychiatrist__c,
                    pstar__Last_Psych_Eval__c,
                    pstar__IDD__c,
                    pstar__Is_There_a_Hx_of_DA_Use__c,
                    pstar__Legal_Involve_in_Past_Yr__c,
                    pstar__Megan_s_Law__c,
                    pstar__Reason_Seeking_Services__c,
                    pstar__No_Admit_Reason__c,
                    pstar__Referred_By__c,
                    pstar__Referral_Type__c,
                    pstar__Referral_Phone__c,
                    pstar__Referral_Date__c,
                    pstar__Web_Referral__c,
                    pstar__How_did_you_hear_of_us__c,
                    pstar__Admission_Date__c,
                    pstar__Referring_Provider__c,
                    pstar__Referring_NPI__c,
                    pstar__Available_Days__c,
                    pstar__Available_Times__c
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];

            if (oppList.isEmpty()) {
                return 'Error: Opportunity not found.';
            }

            Opportunity opp = oppList[0];

            // Get Credible Lookup values (using Opp field values for matching)
            Map<String, String> credLookupMap = getCredibleLookups(opp);

            // Get county code
            String countyCode = getCountyCode(opp.pstar__County__c);

            // Build full JSON preferences string from Opp fields
            String fullJson = buildFullJsonPreferences(opp);
            // Build CSV with correct field order (matching production)
            String csvData = buildCredibleCSV(opp, countyCode, credLookupMap, fullJson);
            System.debug('CSV Data: ' + csvData);

            // Encode to base64
            String base64EncodedData = EncodingUtil.base64Encode(Blob.valueOf(csvData));

            // Get connection string
            String connectionString = getConnectionString();
            System.debug('CredibleIntegrationService [PUSH TO CREDIBLE]: Using Import_Connection_String: ' + connectionString);
            if (String.isBlank(connectionString)) {
                return 'Error: Credible connection not configured. Please contact your administrator.';
            }

            // Build request body
            String body =
                'connection=' + EncodingUtil.urlEncode(connectionString, 'UTF-8') +
                '&encodedfile=' + EncodingUtil.urlEncode(base64EncodedData, 'UTF-8');

            // Make HTTP callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint(Label.Credible_Import_URL);
            System.debug('CredibleIntegrationService [PUSH TO CREDIBLE]: Import URL: ' + Label.Credible_Import_URL);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(body);
            req.setTimeout(120000);
            //checking the commit
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                String responseBody = res.getBody();
                System.debug('Credible Response: ' + responseBody);

                // Check for errors in response
                if (hasErrorInResponse(responseBody)) {
                    logError('API', res.getStatusCode(), responseBody, 'Error in Credible response');
                    return 'Error: ' + extractErrorMessage(responseBody);
                }

                // Get Peer ID from Credible
                // If Credible_ID already exists (update), use it; otherwise use SF Opp ID (new create)
                // String lookupId = String.isNotBlank(opp.pstar__Credible_ID__c)
                //     ? opp.pstar__Credible_ID__c
                //     : String.valueOf(opp.Id);
                String lookupId = String.valueOf(opp.Id); 
                System.debug('========== PEER ID RETRIEVAL DEBUG START ==========');
                System.debug('Opportunity ID: ' + opp.Id);
                System.debug('Existing Credible ID: ' + opp.pstar__Credible_ID__c);
                System.debug('Lookup ID being used: ' + lookupId);
                System.debug('Is this an UPDATE? ' + String.isNotBlank(opp.pstar__Credible_ID__c));
                System.debug('========== CALLING getPeerIdFromCredible ==========');
                
                String peerId = getPeerIdFromCredible(lookupId);
                
                System.debug('========== PEER ID RETRIEVAL RESULT ==========');
                System.debug('Returned Peer ID: ' + peerId);
                System.debug('Is Peer ID blank? ' + String.isBlank(peerId));
                System.debug('========== PEER ID RETRIEVAL DEBUG END ==========');

                if (String.isBlank(peerId)) {
                    logError('API', res.getStatusCode(), responseBody, 'Peer ID not returned');
                    sendNotification(opportunityId, 'Profile created but Peer ID not returned');
                    return 'Warning: Profile created but Peer ID could not be retrieved.';
                }

                // Update records with Peer ID
                updateRecordsWithPeerId(opp, peerId);

                logSuccess(res.getStatusCode(), responseBody);

                return 'success';

            } else {
                logError('API', res.getStatusCode(), res.getBody(), 'HTTP error');
                return 'Error: Failed to connect to Credible. Please try again.';
            }

        } catch (Exception e) {
            logError('Apex', null, e.getStackTraceString(), e.getMessage());
            return 'Error: An unexpected error occurred. Please contact support.';
        }
    }

    /**
     * Get Credible lookup mappings using Credible_Lookup__c custom object.
     * Matches Salesforce field value -> Credible Lookup ID for push to Credible.
     */
    private static Map<String, String> getCredibleLookups(Opportunity opp) {
        Map<String, String> credLookupMap = new Map<String, String>();

        // Map category -> Opp field value for matching
        Map<String, String> fieldValuesByCategory = new Map<String, String>();
        fieldValuesByCategory.put('Status', opp.pstar__Status__c);
        fieldValuesByCategory.put('Preferred Language', opp.pstar__Preferred_Language__c);
        fieldValuesByCategory.put('Smoking Status', opp.pstar__Smoking_Status__c);
        // fieldValuesByCategory.put('Living Situation', opp.pstar__Living_Situation__c); // Commented out - causing Credible import failure
        fieldValuesByCategory.put('Peer Type', opp.pstar__Peer_Type__c);
        fieldValuesByCategory.put('Gender', opp.pstar__Gender__c);
        fieldValuesByCategory.put('Marital Status', opp.pstar__Marital_Status__c);
        fieldValuesByCategory.put('Sexual Orientation', opp.pstar__Sexual_Orientation__c);
        fieldValuesByCategory.put('Gender Identity', opp.pstar__Gender_Identity__c);
        fieldValuesByCategory.put('Assigned Sex at Birth', opp.pstar__Assigned_sex_at_birth__c);
        fieldValuesByCategory.put('Preferred Pronouns', opp.pstar__Preferred_Pronouns__c);
        fieldValuesByCategory.put('Forensic Status', opp.pstar__Forensic_Status__c);
        fieldValuesByCategory.put('No Admit Reason', opp.pstar__No_Admit_Reason__c);

        try {
            for (pstar__Credible_Lookup__c credLookupObj : [
                SELECT Id, pstar__Credible_Value__c, pstar__Credible_Lookup_Category__c, pstar__Credible_Lookup_Id__c
                FROM pstar__Credible_Lookup__c
                WHERE pstar__Credible_Lookup_Category__c IN (
                    'Status', 'Preferred Language', 'Smoking Status',
                    'Peer Type', 'Gender',
                    'Marital Status', 'Sexual Orientation', 'Gender Identity',
                    'Assigned Sex at Birth', 'Preferred Pronouns',
                    'Forensic Status', 'No Admit Reason'
                )
            ]) {
                String cat = credLookupObj.pstar__Credible_Lookup_Category__c;
                String credValue = credLookupObj.pstar__Credible_Value__c;
                String credId = credLookupObj.pstar__Credible_Lookup_Id__c;

                // Match standard categories (skip if already matched)
                if (fieldValuesByCategory.containsKey(cat)
                    && fieldValuesByCategory.get(cat) != null
                    && !credLookupMap.containsKey(cat)) {
                    String fieldVal = fieldValuesByCategory.get(cat);
                    // Direct match or match after stripping numeric prefix (e.g., "0-Non-smoker" -> "Non-smoker")
                    if (credValue == fieldVal ||
                        (fieldVal.contains('-') && credValue == fieldVal.substringAfter('-'))) {
                        credLookupMap.put(cat, credId);
                    }
                }

                // Primary Written Language uses same 'Preferred Language' category in Credible
                if (cat == 'Preferred Language'
                    && opp.pstar__Primary_Written_Language__c != null
                    && credValue == opp.pstar__Primary_Written_Language__c
                    && !credLookupMap.containsKey('Primary Written Language')) {
                    credLookupMap.put('Primary Written Language', credId);
                }
            }
        } catch (Exception e) {
            System.debug('Credible lookup error: ' + e.getMessage());
        }

        return credLookupMap;
    }

    /**
     * Build full JSON preferences string from Opportunity fields
     */
    private static String buildFullJsonPreferences(Opportunity opp) {
        return
            'Are there pets in home?: ' + nvl(String.valueOf(opp.pstar__Are_there_pets_in_home__c)) +
            '; Smoking Status: ' + nvl(opp.pstar__Smoking_Status__c) +
            '; Available Days (Su - Sa): ' + nvl(opp.pstar__Available_Days__c) +
            '; Available Times (am, pm): ' + nvl(opp.pstar__Available_Times__c) +
            '; Preferred Language: ' + nvl(opp.pstar__Preferred_Language__c) +
            '; Primary Written Language: ' + nvl(opp.pstar__Primary_Written_Language__c) +
            '; Need Interpreter?: ' + nvl(String.valueOf(opp.pstar__Need_Interpreter__c)) +
            // '; Living Situation: ' + nvl(opp.pstar__Living_Situation__c) + // Commented out - causing Credible import failure
            '; CPS Preference: ' + nvl(opp.pstar__CPS_Preference__c) +
            '; Type of srvc (Telehealth): ' + nvl(String.valueOf(opp.pstar__Type_of_srvc_Telehealth__c)) +
            '; Type of srvc (Telephone): ' + nvl(String.valueOf(opp.pstar__Type_of_srvc_Telephone__c)) +
            '; Type of srvc (F2F): ' + nvl(String.valueOf(opp.pstar__Type_of_srvc_F2F__c)) +
            '; Agrees to staff w/Crim Hx: ' + nvl(String.valueOf(opp.pstar__Agrees_to_staff_w_Crim_Hx__c)) + ';';
    }

    /**
     * Build CSV data matching Credible import column order (68 columns).
     * Column order MUST match the Credible Import Web Service configuration.
     */
    private static String buildCredibleCSV(
        Opportunity opp,
        String countyCode,
        Map<String, String> credLookupMap,
        String fullJson
    ) {
        return
            // 1. external_id (no quotes - Credible parser stores them literally)
            String.valueOf(opp.Id) + ',' +
            // 2. Middle Initial
            '"' + nvl(opp.pstar__Middle_Initial__c) + '",' +
            // 3. Preferred Name
            '"' + nvl(opp.pstar__Peer_Preferred_Name__c) + '",' +
            // 4. Status (Credible lookup ID - required, cannot be NULL, defaults to 001)
            '"' + (credLookupMap.containsKey('Status') ? credLookupMap.get('Status') : '001') + '",' +
            // 5. Status Reason
            '"' + nvl(opp.pstar__Status_Reason__c) + '",' +
            // 6. Program Type (removed - was causing Credible parser error)
            '"",' +
            // 7. Peer Type (Credible lookup ID, fallback to raw text)
            '"' + nvl(credLookupMap.containsKey('Peer Type') ? credLookupMap.get('Peer Type') : opp.pstar__Peer_Type__c) + '",' +
            // 8. DOB
            '"' + nvl(String.valueOf(opp.pstar__DOB__c)) + '",' +
            // 9. Address 1
            '"' + nvl(opp.pstar__Street_Address__c) + '",' +
            // 10. Address 2
            '"' + nvl(opp.pstar__Street_Address2__c) + '",' +
            // 11. City
            '"' + nvl(opp.pstar__Address_City__c) + '",' +
            // 12. County (code from metadata)
            '"' + nvl(countyCode) + '",' +
            // 13. Zip Code
            '"' + nvl(opp.pstar__Zip_Code__c) + '",' +
            // 14. State
            '"' + nvl(opp.pstar__State__c) + '",' +
            // 15. Home Phone
            '"' + cleanPhone(opp.pstar__Home_Phone__c) + '",' +
            // 16. Mobile Phone
            '"' + cleanPhone(opp.pstar__Mobile_Phone__c) + '",' +
            // 17. Admission Date
            '"' + nvl(String.valueOf(opp.pstar__Admission_Date__c)) + '",' +
            // 18. SSN
            '"' + nvl(opp.pstar__Peer_ssn__c) + '",' +
            // 19. MAID#
            '"' + nvl(opp.pstar__MAID__c) + '",' +
            // 20. May we call as Peerstar?
            '"' + nvl(String.valueOf(opp.pstar__May_we_call_as_Peerstar__c)) + '",' +
            // 21. Living Situation (commented out - causing Credible import failure)
            '"",' +
            // 22. Facility Name
            '"' + nvl(opp.pstar__Facility_Name__c) + '",' +
            // 23. Preferred Contact (removed - was causing Credible parser error)
            '"",' +
            // 24. Ethnicity
            '"' + nvl(opp.pstar__Ethnicity__c) + '",' +
            // 25. Preferred Language (Credible value from CMT)
            '"' + nvl(credLookupMap.containsKey('Preferred Language') ? credLookupMap.get('Preferred Language') : opp.pstar__Preferred_Language__c) + '",' +
            // 26. Is Restricted (Megan's Law)
            '"' + nvl(String.valueOf(opp.pstar__Megan_s_Law__c)) + '",' +
            // 27. Gender (Credible lookup ID, fallback to M/F mapping)
            '"' + nvl(credLookupMap.containsKey('Gender') ? credLookupMap.get('Gender') : (opp.pstar__Gender__c == 'Male' ? 'M' : opp.pstar__Gender__c == 'Female' ? 'F' : opp.pstar__Gender__c)) + '",' +
            // 28. Primary Written Language (Credible value from CMT)
            '"' + nvl(credLookupMap.containsKey('Primary Written Language') ? credLookupMap.get('Primary Written Language') : opp.pstar__Primary_Written_Language__c) + '",' +
            // 29. Client Signature Source
            '"' + nvl(opp.pstar__Client_Signature_Source__c) + '",' +
            // 30. Release Of Information
            '"' + nvl(opp.pstar__Release_Of_Information__c) + '",' +
            // 31. Reason Seeking Services
            '"' + csvSafe(opp.pstar__Reason_Seeking_Services__c) + '",' +
            // 32. Diagnosis - Intake
            '"' + csvSafe(opp.pstar__Diagnosis_Intake__c) + '",' +
            // 33. Primary Care Physician
            '"' + nvl(opp.pstar__Primary_Care_Physician__c) + '",' +
            // 34. IDD
            '"' + nvl(String.valueOf(opp.pstar__IDD__c)) + '",' +
            // 35. Psychiatrist
            '"' + nvl(opp.pstar__Psychiatrist__c) + '",' +
            // 36. Last Psych Eval (Text(255), not Date)
            '"' + nvl(opp.pstar__Last_Psych_Eval__c) + '",' +
            // 37. Is There a Hx of D&A Use?
            '"' + nvl(String.valueOf(opp.pstar__Is_There_a_Hx_of_DA_Use__c)) + '",' +
            // 38. Legal Involve in Past Yr?
            '"' + nvl(String.valueOf(opp.pstar__Legal_Involve_in_Past_Yr__c)) + '",' +
            // 39. Forensic Status (Credible lookup ID, fallback to raw text)
            '"' + nvl(credLookupMap.containsKey('Forensic Status') ? credLookupMap.get('Forensic Status') : opp.pstar__Forensic_Status__c) + '",' +
            // 40. Are there pets in home?
            '"' + nvl(String.valueOf(opp.pstar__Are_there_pets_in_home__c)) + '",' +
            // 41. Hx of pet aggression
            '"' + nvl(String.valueOf(opp.pstar__Hx_of_pet_aggression__c)) + '",' +
            // 42. Smoking Status (Credible value from CMT)
            '"' + nvl(credLookupMap.containsKey('Smoking Status') ? credLookupMap.get('Smoking Status') : opp.pstar__Smoking_Status__c) + '",' +
            // 43. Agrees to staff w/Crim Hx
            '"' + nvl(String.valueOf(opp.pstar__Agrees_to_staff_w_Crim_Hx__c)) + '",' +
            // 44. CPS Preference
            '"' + nvl(opp.pstar__CPS_Preference__c) + '",' +
            // 45. Need Interpreter?
            '"' + nvl(String.valueOf(opp.pstar__Need_Interpreter__c)) + '",' +
            // 46. Available Days (Su - Sa)
            '"' + nvl(opp.pstar__Available_Days__c) + '",' +
            // 47. Available Times (am, pm)
            '"' + nvl(opp.pstar__Available_Times__c) + '",' +
            // 48. How did you hear of us?
            '"' + nvl(opp.pstar__How_did_you_hear_of_us__c) + '",' +
            // 49. Referred By
            '"' + nvl(opp.pstar__Referred_By__c) + '",' +
            // 50. Web Referral
            '"' + nvl(String.valueOf(opp.pstar__Web_Referral__c)) + '",' +
            // 51. Referral Date
            '"' + nvl(String.valueOf(opp.pstar__Referral_Date__c)) + '",' +
            // 52. Referral Type
            '"' + nvl(opp.pstar__Referral_Type__c) + '",' +
            // 53. Referral Phone
            '"' + cleanPhone(opp.pstar__Referral_Phone__c) + '",' +
            // 54. Referring Provider
            '"' + nvl(opp.pstar__Referring_Provider__c) + '",' +
            // 55. No Admit Reason (Credible lookup ID, fallback to raw text)
            '"' + (credLookupMap.containsKey('No Admit Reason') ? credLookupMap.get('No Admit Reason') : csvSafe(opp.pstar__No_Admit_Reason__c)) + '",' +
            // 56. Type of srvc (Telehealth)
            '"' + nvl(String.valueOf(opp.pstar__Type_of_srvc_Telehealth__c)) + '",' +
            // 57. Type of srvc (Telephone)
            '"' + nvl(String.valueOf(opp.pstar__Type_of_srvc_Telephone__c)) + '",' +
            // 58. Type of srvc (F2F)
            '"' + nvl(String.valueOf(opp.pstar__Type_of_srvc_F2F__c)) + '",' +
            // 59. Pulse Preferences (full JSON string - commas removed for CSV safety)
            '"' + fullJson.replace(',', ';') + '",' +
            // 60. Peer ID (Credible ID - blank for new, populated for updates)
            '"' + nvl(opp.pstar__Credible_ID__c) + '",' +
            // 61. First Name
            '"' + nvl(String.isNotBlank(opp.pstar__Patient_First_Name__c) ? opp.pstar__Patient_First_Name__c : opp.pstar__Patient__r.FirstName) + '",' +
            // 62. Last Name
            '"' + nvl(String.isNotBlank(opp.pstar__Patient_Last_Name__c) ? opp.pstar__Patient_Last_Name__c : opp.pstar__Patient__r.LastName) + '",' +
            // 63. Race
            '"' + nvl(opp.pstar__Race__c) + '"\n';
    }

    /**
     * Get county code from custom metadata
     */
    private static String getCountyCode(String county) {
        if (String.isBlank(county)) return '';

        List<pstar__Credible_County_Config__mdt> configs = [
            SELECT pstar__County_Code__c
            FROM pstar__Credible_County_Config__mdt
            WHERE Label = :county
            LIMIT 1
        ];

        return configs.isEmpty() ? '' : configs[0].pstar__County_Code__c;
    }

    /**
     * Get connection string from custom metadata
     */
    private static String getConnectionString() {
        List<pstar__Credible_Integration_Config__mdt> configs = [
            SELECT pstar__Import_Connection_String__c
            FROM pstar__Credible_Integration_Config__mdt
            WHERE DeveloperName = 'Client_Credible_Connection'
            LIMIT 1
        ];

        return configs.isEmpty() ? null : configs[0].pstar__Import_Connection_String__c;
    }

    /**
     * Check if response contains error
     */
    private static Boolean hasErrorInResponse(String responseBody) {
        if (String.isBlank(responseBody) || !responseBody.startsWith('<?xml')) {
            return false;
        }

        // Check for <Error> tag in response (handles concatenated XML documents)
        if (responseBody.contains('<Error>')) {
            return true;
        }

        try {
            Dom.Document doc = new Dom.Document();
            doc.load(responseBody);
            Dom.XmlNode root = doc.getRootElement();

            if (root != null && root.getName() == 'string') {
                String errorText = root.getText();
                return !String.isBlank(errorText) &&
                       (errorText.containsIgnoreCase('Error') || errorText.containsIgnoreCase('error'));
            }
        } catch (Exception e) {
            System.debug('Error parsing response: ' + e.getMessage());
        }

        return false;
    }

    /**
     * Extract error message from XML response
     */
    private static String extractErrorMessage(String responseBody) {
        // Handle concatenated XML: extract <Desc> content from <Error> block
        if (responseBody != null && responseBody.contains('<Desc>') && responseBody.contains('</Desc>')) {
            Integer startIdx = responseBody.indexOf('<Desc>') + 6;
            Integer endIdx = responseBody.indexOf('</Desc>');
            if (startIdx < endIdx) {
                return responseBody.substring(startIdx, endIdx);
            }
        }

        try {
            Dom.Document doc = new Dom.Document();
            doc.load(responseBody);
            Dom.XmlNode root = doc.getRootElement();

            if (root != null && root.getName() == 'string') {
                return root.getText();
            }
        } catch (Exception e) {
            System.debug('Error extracting message: ' + e.getMessage());
        }

        return 'Unknown error occurred';
    }

    /**
     * Get Peer ID from Credible export API
     */
    private static String getPeerIdFromCredible(String externalId) {
        System.debug('========== getPeerIdFromCredible METHOD START ==========');
        System.debug('Input externalId: ' + externalId);
        
        try {
            List<pstar__Credible_Integration_Config__mdt> configs = [
                SELECT pstar__PeerId_Export_Connection_String__c
                FROM pstar__Credible_Integration_Config__mdt
                WHERE DeveloperName = 'Client_Credible_Connection'
                LIMIT 1
            ];

            if (configs.isEmpty()) {
                System.debug('ERROR: No Credible Integration Config found!');
                return null;
            }

            System.debug('Connection String: ' + configs[0].pstar__PeerId_Export_Connection_String__c);

            String exportUrl =
                'https://reportservices.crediblebh.com/reports/ExportService.asmx/ExportDataSet' +
                '?connection=' + EncodingUtil.urlEncode(configs[0].pstar__PeerId_Export_Connection_String__c, 'UTF-8') +
                '&start_date=' +
                '&end_date=' +
                '&custom_param1=' + externalId +
                '&custom_param2=' +
                '&custom_param3=';

            System.debug('Full Export URL: ' + exportUrl);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(exportUrl);
            req.setMethod('GET');
            req.setTimeout(120000);

            Http http = new Http();

            // Retry up to 5 times with delay
            for (Integer i = 0; i < 5; i++) {
                System.debug('---------- Attempt #' + (i + 1) + ' ----------');
                
                HttpResponse res = http.send(req);
                
                System.debug('HTTP Status Code: ' + res.getStatusCode());
                System.debug('HTTP Status: ' + res.getStatus());
                
                String responseBody = res.getBody();
                System.debug('Response Body Length: ' + (responseBody != null ? responseBody.length() : 0));
                System.debug('Response Body (first 500 chars): ' + (responseBody != null && responseBody.length() > 500 ? responseBody.substring(0, 500) : responseBody));
                
                if (responseBody != null && responseBody.length() > 500) {
                    System.debug('Response Body (last 500 chars): ' + responseBody.substring(responseBody.length() - 500));
                }

                if (res.getStatusCode() == 200) {
                    System.debug('Calling extractPeerIdFromXML...');
                    String peerId = extractPeerIdFromXML(responseBody);
                    System.debug('extractPeerIdFromXML returned: ' + peerId);
                    
                    if (!String.isBlank(peerId)) {
                        System.debug('SUCCESS: Peer ID retrieved: ' + peerId);
                        System.debug('========== getPeerIdFromCredible METHOD END ==========');
                        return peerId;
                    } else {
                        System.debug('WARNING: extractPeerIdFromXML returned blank/null');
                    }
                } else {
                    System.debug('ERROR: Non-200 status code received');
                }

                System.debug('Retry needed. Waiting before next attempt...');
            }
            
            System.debug('ERROR: All 5 retry attempts failed');
        } catch (Exception e) {
            System.debug('EXCEPTION in getPeerIdFromCredible: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }

        System.debug('========== getPeerIdFromCredible METHOD END (FAILED) ==========');
        return null;
    }

    /**
     * Extract Peer ID from XML response
     */
    private static String extractPeerIdFromXML(String xmlBody) {
        System.debug('========== extractPeerIdFromXML METHOD START ==========');
        System.debug('XML Body length: ' + (xmlBody != null ? xmlBody.length() : 0));
        
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xmlBody);
            System.debug('XML loaded successfully into Dom.Document');

            Dom.XmlNode root = doc.getRootElement();
            System.debug('Root element name: ' + (root != null ? root.getName() : 'NULL'));
            System.debug('Root element namespace: ' + (root != null ? root.getNamespace() : 'NULL'));
            
            if (root == null) {
                System.debug('ERROR: Root element is null!');
                return null;
            }

            // Get diffgram
            Dom.XmlNode diffgram = root.getChildElement('diffgram', 'urn:schemas-microsoft-com:xml-diffgram-v1');
            System.debug('Diffgram node found: ' + (diffgram != null));
            
            if (diffgram == null) {
                System.debug('ERROR: diffgram node not found!');
                System.debug('Root children count: ' + root.getChildElements().size());
                for (Dom.XmlNode child : root.getChildElements()) {
                    System.debug('  Child: ' + child.getName() + ' (namespace: ' + child.getNamespace() + ')');
                }
                return null;
            }

            List<Dom.XmlNode> diffgramChildren = diffgram.getChildElements();
            System.debug('Diffgram children count: ' + diffgramChildren.size());
            
            if (diffgramChildren.isEmpty()) {
                System.debug('ERROR: diffgram has no children!');
                return null;
            }

            Dom.XmlNode newDataSet = diffgramChildren.get(0);
            System.debug('NewDataSet node name: ' + (newDataSet != null ? newDataSet.getName() : 'NULL'));
            
            if (newDataSet == null) {
                System.debug('ERROR: NewDataSet is null!');
                return null;
            }

            List<Dom.XmlNode> dataSetChildren = newDataSet.getChildElements();
            System.debug('NewDataSet children count: ' + dataSetChildren.size());
            
            if (dataSetChildren.isEmpty()) {
                System.debug('WARNING: NewDataSet has no children - likely no matching records found in Credible!');
                System.debug('This means the external_id did not match any records.');
                return null;
            }

            Dom.XmlNode tableNode = dataSetChildren.get(0);
            System.debug('Table node name: ' + (tableNode != null ? tableNode.getName() : 'NULL'));
            
            // Debug all children of the table node
            System.debug('Table node children:');
            for (Dom.XmlNode child : tableNode.getChildElements()) {
                System.debug('  Field: ' + child.getName() + ' = ' + child.getText());
            }

            Dom.XmlNode clientNode = tableNode.getChildElement('client_id', null);
            System.debug('client_id node found: ' + (clientNode != null));
            
            if (clientNode != null) {
                String peerId = clientNode.getText();
                System.debug('SUCCESS: Peer ID extracted: ' + peerId);
                System.debug('========== extractPeerIdFromXML METHOD END ==========');
                return peerId;
            } else {
                System.debug('ERROR: client_id node not found in table!');
            }
        } catch (Exception e) {
            System.debug('EXCEPTION in extractPeerIdFromXML: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
        }

        System.debug('========== extractPeerIdFromXML METHOD END (FAILED) ==========');
        return null;
    }

    /**
     * Update Opportunity, Contact, and Action records with Peer ID
     */
    private static void updateRecordsWithPeerId(Opportunity opp, String peerId) {
        // Update Opportunity with Credible ID
        Opportunity oppUpdate = new Opportunity(Id = opp.Id);
        oppUpdate.pstar__Credible_ID__c = peerId;
        update oppUpdate;

        // Update Contact with Credible Profile ID
        if (opp.pstar__Patient__c != null) {
            Contact patient = new Contact(
                Id = opp.pstar__Patient__c,
                pstar__Credible_Profile_ID__c = peerId
            );
            update patient;
        }

        // Update Action record if exists
        List<pstar__Action__c> actionList = [
            SELECT Id, pstar__Credible_Profile_ID__c
            FROM pstar__Action__c
            WHERE Name = 'Create Peer Profile'
            AND pstar__Referral__r.Id = :opp.Id
            LIMIT 1
        ];

        if (!actionList.isEmpty()) {
            actionList[0].pstar__Credible_Profile_ID__c = peerId;
            update actionList;
        }
    }

    /**
     * Send notification to user
     */
    private static void sendNotification(Id recordId, String message) {
        try {
            List<CustomNotificationType> notifTypes = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = 'Credible_Notification'
                LIMIT 1
            ];

            if (!notifTypes.isEmpty()) {
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle('Credible Profile Created');
                notification.setBody(message);
                notification.setNotificationTypeId(notifTypes[0].Id);
                notification.setTargetId(recordId);
                notification.send(new Set<String>{UserInfo.getUserId()});
            }
        } catch (Exception e) {
            System.debug('Error sending notification: ' + e.getMessage());
        }
    }

    /**
     * Log error to Error_Log__c
     */
    private static void logError(String errorType, Integer statusCode, String details, String message) {
        try {
            pstar__Error_Log__c log = new pstar__Error_Log__c(
                pstar__Source_Name__c = 'Credible',
                pstar__Error_Type__c = errorType,
                pstar__Error_Message__c = message,
                pstar__Status_Code__c = statusCode != null ? String.valueOf(statusCode) : null,
                pstar__Status__c = 'Failed',
                pstar__Error_Details__c = details
            );
            insert log;
        } catch (Exception e) {
            System.debug('Failed to log error: ' + e.getMessage());
        }
    }

    /**
     * Log success to Error_Log__c
     */
    private static void logSuccess(Integer statusCode, String details) {
        try {
            pstar__Error_Log__c log = new pstar__Error_Log__c(
                pstar__Source_Name__c = 'Credible',
                pstar__Error_Type__c = 'API',
                pstar__Error_Message__c = 'Success',
                pstar__Status_Code__c = String.valueOf(statusCode),
                pstar__Status__c = 'Success',
                pstar__Error_Details__c = details
            );
            insert log;
        } catch (Exception e) {
            System.debug('Failed to log success: ' + e.getMessage());
        }
    }

    /**
     * Helper: Null value replacement
     */
    private static String nvl(String value) {
        return String.isBlank(value) ? '' : value;
    }

    /**
     * Helper: Clean phone number
     */
    private static String cleanPhone(String phone) {
        return String.isBlank(phone) ? '' : phone.replaceAll('[^0-9]', '');
    }

    private static String csvSafe(String value) {
        if (String.isBlank(value)) return '';
        return value.replaceAll('"', '""').replaceAll('\r?\n', ' ');
    }

}