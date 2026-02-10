@IsTest
public class CredibleWebServiceIntegrationTest {
    @TestSetup
    static void setupTestData() {
        // Create a patient (Contact)
        Contact testPatient = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            ple__Contact_Type__c = 'Patient',
            Birthdate = Date.newInstance(1990, 1, 1),
            Email = 'john.doe@example.com'
        );
        insert testPatient;

        // Create Referral
        ple__Referral__c referral = new ple__Referral__c(
            ple__Patient__c = testPatient.Id
        );
        insert referral;

        // Create Patient Admission
        ple__Patient_Admission__c admission = new ple__Patient_Admission__c(
            ple__Patient__c = testPatient.Id,
            Credible_DOB__c = Date.newInstance(1990, 1, 1),
            Credible_address1__c = '123 Main St',
            Credible_City__c = 'Austin',
            Credible_State__c = 'Texas',
            Credible_Zip__c = '73301',
            Credible_County__c = 'Armstrong',
            Credible_Mobile_Phone__c = '1234567890',
            Credible_Email__c = 'john.doe@example.com'
        );
        insert admission;

        List<ple__Preference__c> preferences = new List<ple__Preference__c>{
        new ple__Preference__c( ple__Field_Label_Patient__c='Need Interpreter?',ple__Display_As__c = 'Single-Select'),
        new ple__Preference__c( ple__Field_Label_Patient__c='Type of Service Delivery',ple__Display_As__c ='Multi-Select'),
        new ple__Preference__c(ple__Field_Label_Patient__c='Pets in Home',ple__Display_As__c ='Multi-Select' ),
        new ple__Preference__c( ple__Field_Label_Patient__c='Agrees to Staff with Criminal History',ple__Display_As__c = 'Single-Select'),
        new ple__Preference__c( ple__Field_Label_Patient__c='Preferred Language',ple__Display_As__c = 'Single-Select'),
        new ple__Preference__c( ple__Field_Label_Patient__c='Smoking Status',ple__Display_As__c = 'Single-Select'),
        new ple__Preference__c( ple__Field_Label_Patient__c='Primary Written Language',ple__Display_As__c = 'Single-Select'),
        new ple__Preference__c( ple__Field_Label_Patient__c='Living Situation',ple__Display_As__c ='Single-Select' ),
        new ple__Preference__c( ple__Field_Label_Patient__c='Available Times Sunday',ple__Display_As__c ='Single-Select' ),
        new ple__Preference__c( ple__Field_Label_Patient__c='Available Times Tuesday',ple__Display_As__c ='Single-Select' ),
        new ple__Preference__c( ple__Field_Label_Patient__c='Available Times Monday',ple__Display_As__c ='Single-Select' ),
        new ple__Preference__c( ple__Field_Label_Patient__c='Available Times Wednesday',ple__Display_As__c ='Single-Select' ),
        new ple__Preference__c( ple__Field_Label_Patient__c='Available Times Thursday',ple__Display_As__c ='Single-Select' ),
        new ple__Preference__c( ple__Field_Label_Patient__c='Available Times Friday',ple__Display_As__c ='Single-Select' ),
        new ple__Preference__c( ple__Field_Label_Patient__c='Available Times Saturday',ple__Display_As__c ='Single-Select' )
    };
    insert preferences;
        List<ple__Preference_Option__c> prefOptions1 = new List<ple__Preference_Option__c>();
        prefOptions1.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[0].Id,
        ple__Value__c = 'Yes'
    ));
        
         // Type of Service Delivery → Virtual (Telehealth)
         prefOptions1.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[1].Id,
        ple__Value__c = 'Virtual'
    ));
        
         // Type of Service Delivery → In Person (F2F)
        prefOptions1.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[1].Id,
        ple__Value__c = 'In Person'
    ));

    // Pets in Home → Dog
    prefOptions1.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[2].Id,
        ple__Value__c = 'Dog'
    ));

    // Agrees to Staff with Criminal History → Yes
    prefOptions1.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[3].Id,
        ple__Value__c = 'Yes'
    ));

    // Preferred Language → English
    prefOptions1.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[4].Id,
        ple__Value__c = 'English'
    ));

    // Smoking Status → Non-smoker
    prefOptions1.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[5].Id,
        ple__Value__c = 'Non-smoker'
    ));

    // Living Situation → Alone
    prefOptions1.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[7].Id,
        ple__Value__c = 'Family Setting'
    ));

    insert prefOptions1;
        
        

         List<ple__Preference_Option__c> prefOptions = new List<ple__Preference_Option__c>();

    // Need Interpreter? → Yes
    prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[0].Id,
        ple__Value__c = 'Yes',
        ple__Preference_Option__c = prefOptions1[0].Id
    ));
        
         // Type of Service Delivery → Virtual (Telehealth)
         prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[1].Id,
        ple__Value__c = 'Virtual',
        ple__Preference_Option__c = prefOptions1[1].Id
    ));
        
         // Type of Service Delivery → In Person (F2F)
        prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[1].Id,
        ple__Value__c = 'In Person',
        ple__Preference_Option__c = prefOptions1[2].Id
    ));

    // Pets in Home → Dog
    prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[2].Id,
        ple__Value__c = 'Dog',
        ple__Preference_Option__c = prefOptions1[3].Id
    ));

    // Agrees to Staff with Criminal History → Yes
    prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[3].Id,
        ple__Value__c = 'Yes',
        ple__Preference_Option__c = prefOptions1[4].Id
    ));

    // Preferred Language → English
    prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[4].Id,
        ple__Value__c = 'English',
        ple__Preference_Option__c = prefOptions1[5].Id
    ));

    // Smoking Status → Non-smoker
    prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[5].Id,
        ple__Value__c = 'Non-smoker',
        ple__Preference_Option__c = prefOptions1[6].Id
    ));

    // Living Situation → Alone
    prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[7].Id,
        ple__Value__c = 'Family Setting',
        ple__Preference_Option__c = prefOptions1[7].Id
    ));
        
     prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[8].Id,
        ple__Value__c = 'English'
    ));
    
        prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[9].Id,
        ple__Value__c = 'English'
    ));
         prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[10].Id,
        ple__Value__c = 'English'
    ));
         prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[11].Id,
        ple__Value__c = 'English'
    ));
         prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[12].Id,
        ple__Value__c = 'English'
    ));
         prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[13].Id,
        ple__Value__c = 'English'
    ));
         prefOptions.add(new ple__Preference_Option__c(
        ple__Contact__c = testPatient.Id,
        ple__Preference__c = preferences[14].Id,
        ple__Value__c = 'English'
    ));

    insert prefOptions;
        
          List<Credible_Lookup__c> credLookups = new List<Credible_Lookup__c>{
        new Credible_Lookup__c(Credible_Lookup_Category__c='Preferred Language', Credible_Value__c='English', Credible_Lookup_Id__c='111'),
        new Credible_Lookup__c(Credible_Lookup_Category__c='Smoking Status', Credible_Value__c='Non-smoker', Credible_Lookup_Id__c='222'),
        new Credible_Lookup__c(Credible_Lookup_Category__c='Living Situation', Credible_Value__c='Alone', Credible_Lookup_Id__c='333'),
        new Credible_Lookup__c(Credible_Lookup_Category__c='Peer Type', Credible_Value__c='Peer A', Credible_Lookup_Id__c='444')
    };
    insert credLookups;
       
    }

    @IsTest
    static void testPushDataToCredible_SuccessWithPeerId() {
        ple__Referral__c ref = [SELECT Id FROM ple__Referral__c LIMIT 1];
        ple__Patient_Admission__c adm = [SELECT Id FROM ple__Patient_Admission__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SuccessMockWithPeerId());
        Test.startTest();
        String result = CredibleWebServiceIntegration.pushDataToCredible(adm.Id, ref.Id);
        Test.stopTest();
        System.assertEquals('success', result, 'Expected success');
    }

    @IsTest
    static void testPushDataToCredible_SuccessWithoutPeerId() {
        ple__Referral__c ref = [SELECT Id FROM ple__Referral__c LIMIT 1];
        ple__Patient_Admission__c adm = [SELECT Id FROM ple__Patient_Admission__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SuccessMockWithoutPeerId());
        Test.startTest();
        String result = CredibleWebServiceIntegration.pushDataToCredible(adm.Id, ref.Id);
        System.debug('result' +result);
        Test.stopTest();
        System.assert(result.contains(' Peer ID could not be retrieved'));
    }

    @IsTest
    static void testPushDataToCredible_ApiError() {
        ple__Referral__c ref = [SELECT Id FROM ple__Referral__c LIMIT 1];
        ple__Patient_Admission__c adm = [SELECT Id FROM ple__Patient_Admission__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new SuccessMockWithError());
        Test.startTest();
        String result = CredibleWebServiceIntegration.pushDataToCredible(adm.Id, ref.Id);
        Test.stopTest();
        System.assert(result.contains('Error'));
    }

    @IsTest
    static void testPushDataToCredible_Failure() {
        ple__Referral__c ref = [SELECT Id FROM ple__Referral__c LIMIT 1];
        ple__Patient_Admission__c adm = [SELECT Id FROM ple__Patient_Admission__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Test.startTest();
        String result = CredibleWebServiceIntegration.pushDataToCredible(adm.Id, ref.Id);
        Test.stopTest();
        System.assert(result.contains('An error occurred'));
    }

    @IsTest
    static void testPushDataToCredible_ExceptionCatch() {
        ple__Referral__c ref = [SELECT Id FROM ple__Referral__c LIMIT 1];
        ple__Patient_Admission__c adm = [SELECT Id FROM ple__Patient_Admission__c LIMIT 1];

        //Test.setMock(HttpCalloutMock.class, new ExceptionThrowingMock());
        Test.startTest();
        String result = CredibleWebServiceIntegration.pushDataToCredible(adm.Id, ref.Id);
        Test.stopTest();
        System.assert(result.contains('An error occurred'));
    }

    // ---------------- MOCKS ----------------
    private class ExceptionThrowingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Forced Exception');
        }
    }
   private class SuccessMockWithPeerId implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();

        if (req.getMethod() == 'POST') {
            // Simulate pushDataToCredible POST success
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0"?><string>success</string>');
        } else if (req.getMethod() == 'GET') {
            // Simulate getPeerId GET returning peerId
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<DataSet xmlns="">' +
                '<diffgram xmlns="urn:schemas-microsoft-com:xml-diffgram-v1">' +
                '<NewDataSet xmlns="">' +
                '<Table><client_id>11111111111</client_id></Table>' +
                '</NewDataSet>' +
                '</diffgram>' +
                '</DataSet>'
            );
        } else {
            res.setStatusCode(400);
            res.setBody('Unexpected Method');
        }
        return res;
    }
}

    private class SuccessMockWithoutPeerId implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0"?><string>success</string>');
            return res;
        }
    }
    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
    private class SuccessMockWithError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0"?><string>Error: Invalid Data</string>');
            return res;
        }
    }
}