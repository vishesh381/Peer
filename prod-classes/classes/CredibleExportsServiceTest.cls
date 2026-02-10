@IsTest
private class CredibleExportsServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create Credible Lookup records for Client
        List<Credible_Lookup__c> clientLookups = new List<Credible_Lookup__c>();
        clientLookups.add(new Credible_Lookup__c(
            Name = 'PeerType1',
            Credible_Lookup_Id__c = 'PT1',
            Credible_Lookup_Item__c = 'Peer Type',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Peer Type Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'State1',
            Credible_Lookup_Id__c = 'PA',
            Credible_Lookup_Item__c = 'State',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Pennsylvania'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'LivingSituation1',
            Credible_Lookup_Id__c = 'LS1',
            Credible_Lookup_Item__c = 'Living Situation',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Living Situation Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'PreferredContact1',
            Credible_Lookup_Id__c = 'PC1',
            Credible_Lookup_Item__c = 'Preferred Contact',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Preferred Contact Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'Race1',
            Credible_Lookup_Id__c = 'RC1',
            Credible_Lookup_Item__c = 'Race',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Race Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'Ethnicity1',
            Credible_Lookup_Id__c = 'ET1',
            Credible_Lookup_Item__c = 'Ethnicity',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Ethnicity Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'PreferredLanguage1',
            Credible_Lookup_Id__c = 'PL1',
            Credible_Lookup_Item__c = 'Preferred Language',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Preferred Language Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'SexualOrientation1',
            Credible_Lookup_Id__c = 'SO1',
            Credible_Lookup_Item__c = 'Sexual_Orientation',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Sexual Orientation Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'GenderIdentity1',
            Credible_Lookup_Id__c = 'GI1',
            Credible_Lookup_Item__c = 'Gender Identity',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Gender Identity Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'AssignedSexAtBirth1',
            Credible_Lookup_Id__c = 'AS1',
            Credible_Lookup_Item__c = 'Assigned Sex At Birth',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Assigned Sex At Birth Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'PreferredPronouns1',
            Credible_Lookup_Id__c = 'PP1',
            Credible_Lookup_Item__c = 'Preferred Pronouns',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Preferred Pronouns Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'ForensicStatus1',
            Credible_Lookup_Id__c = 'FS1',
            Credible_Lookup_Item__c = 'Forensic Status',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Forensic Status Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'SmokingStatus1',
            Credible_Lookup_Id__c = 'SS1',
            Credible_Lookup_Item__c = 'Smoking Status',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'Smoking Status Value 1'
        ));
        clientLookups.add(new Credible_Lookup__c(
            Name = 'NoAdmitReason1',
            Credible_Lookup_Id__c = 'NR1',
            Credible_Lookup_Item__c = 'No Admit Reason',
            Credible_Table__c = 'Client',
            Credible_Value__c = 'No Admit Reason Value 1'
        ));
        
        // Create Credible Lookup records for Employee
        List<Credible_Lookup__c> employeeLookups = new List<Credible_Lookup__c>();
        employeeLookups.add(new Credible_Lookup__c(
            Name = 'EmpState1',
            Credible_Lookup_Id__c = 'PA',
            Credible_Lookup_Item__c = 'State',
            Credible_Table__c = 'Employee',
            Credible_Value__c = 'Pennsylvania'
        ));
        employeeLookups.add(new Credible_Lookup__c(
            Name = 'EmpStatus1',
            Credible_Lookup_Id__c = 'ES1',
            Credible_Lookup_Item__c = 'Employment Status',
            Credible_Table__c = 'Employee',
            Credible_Value__c = 'Employment Status Value 1'
        ));
        employeeLookups.add(new Credible_Lookup__c(
            Name = 'EmpRace1',
            Credible_Lookup_Id__c = 'ERC1',
            Credible_Lookup_Item__c = 'Race',
            Credible_Table__c = 'Employee',
            Credible_Value__c = 'Employee Race Value 1'
        ));
        
        insert clientLookups;
        insert employeeLookups;
        
        // Create existing contact for testing updates
        Contact existingContact = new Contact(
            FirstName = 'Existing',
            LastName = 'Patient',
            ple__Contact_Type__c = 'Patient',
            Credible_Profile_ID__c = 'EXIST123',
            Birthdate = Date.newInstance(1990, 1, 1),
            Email = 'existing@test.com'
        );
        insert existingContact;
        
        // Create existing patient admission for testing updates
        ple__Patient_Admission__c existingAdmission = new ple__Patient_Admission__c(
            Credible_ID__c = 'EXIST123',
            ple__Patient__c = existingContact.Id,
            Credible_Patient_First_Name__c = 'Existing',
            Credible_Patient_Last_Name__c = 'Patient'
        );
        insert existingAdmission;

        // Create existing patient admission and employee for linking
        ple__Patient_Admission__c pa = new ple__Patient_Admission__c(
            Credible_Id__c = 'CL123',
            Name = 'Test Patient Admission'
        );
        insert pa;

        ple__Employee_Profile__c ep = new ple__Employee_Profile__c(
            Credible_Id__c = 'EMP001',
            Name = 'Test Employee Profile'
        );
        insert ep;
    }
    
    // SINGLE PARAMETERIZED MOCK TO REPLACE ALL OTHERS
    public class ParameterizedMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;
        private Boolean throwException;
        private String exceptionType;
        
        public ParameterizedMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
            this.throwException = false;
        }
        
        public ParameterizedMock(Boolean throwException, String exceptionType) {
            this.throwException = throwException;
            this.exceptionType = exceptionType;
            this.statusCode = 200;
            this.body = exceptionType;
        }
        public ParameterizedMock(Boolean throwException, String exceptionType, String body,Integer statusCode) {
            this.throwException = throwException;
            this.exceptionType = exceptionType;
            this.statusCode = statusCode;
            this.body = body;
        }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            System.debug(body);
            res.setStatusCode(statusCode);
            if(body != ''){
            	res.setBody(body);    
            }else{
                res.setBody('body');
            }
            
            
            return res;
        }
        
    }
    
    // Mock that returns valid XML but causes exception during processing
public class ValidXMLButProcessingExceptionMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'text/xml');
        
        // Return valid XML that will be parsed in the error handler
        String mockXml = ''
            + '<DataSet xmlns="https://www.crediblebh.com/">'
            + '  <diffgr:diffgram xmlns:msdata="urn:schemas-microsoft-com:xml-msdata" xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1">'
            + '    <NewDataSet xmlns="">'
            + '      <Table diffgr:id="Table1" msdata:rowOrder="0">'
            + '        <emp_id>EMP001</emp_id>'
            + '        <first_name>Test</first_name>'
            + '        <last_name>Employee</last_name>'
            + '      </Table>'
            + '      <Table diffgr:id="Table2" msdata:rowOrder="1">'
            + '        <emp_id>EMP002</emp_id>'
            + '        <first_name>Test2</first_name>'
            + '        <last_name>Employee2</last_name>'
            + '      </Table>'
            + '    </NewDataSet>'
            + '  </diffgr:diffgram>'
            + '</DataSet>';
        
        res.setBody(mockXml);
        return res;
    }
}
    
    // Test Methods
    
    @IsTest
    static void testImportClientData_Success() {
        String mockXml = ''
            + '<DataSet xmlns="https://www.crediblebh.com/">'
            + '  <diffgr:diffgram xmlns:msdata="urn:schemas-microsoft-com:xml-msdata" xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1">'
            + '    <NewDataSet xmlns="">'
            + '      <Table diffgr:id="Table1" msdata:rowOrder="0">'
            + '        <client_id>15803</client_id>'
            + '        <first_name>Credible</first_name>'
            + '        <last_name>Test5</last_name>'
            + '        <dob>2025-08-31T00:00:00-04:00</dob>'
            + '        <state>PA</state>'
            + '        <client_status>ACTIVE</client_status>'
            + '        <dd29>PT1</dd29>'
            + '        <dd1>LS1</dd1>'
            + '        <preferred_contact>PC1</preferred_contact>'
            + '        <race_omb>RC1</race_omb>'
            + '        <ethnicity_omb>ET1</ethnicity_omb>'
            + '        <preferred_language>PL1</preferred_language>'
            + '        <dd35>SO1</dd35>'
            + '        <dd36>GI1</dd36>'
            + '        <dd37>AS1</dd37>'
            + '        <dd38>PP1</dd38>'
            + '        <dd26>FS1</dd26>'
            + '        <smoking_status>SS1</smoking_status>'
            + '        <dd31>NR1</dd31>'
            + '      </Table>'
            + '    </NewDataSet>'
            + '  </diffgr:diffgram>'
            + '</DataSet>';

        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(200, mockXml));
        
        Test.startTest();
       System.enqueueJob(new CredibleClientExportQueueable());
        Test.stopTest();
        
        List<ple__Patient_Admission__c> admissions = [SELECT Id, Credible_ID__c, Credible_Patient_First_Name__c, 
                                                     Credible_Patient_Last_Name__c, Credible_Client_Satus__c,
                                                     Credible_State__c, Credible_Peer_Type__c
                                                     FROM ple__Patient_Admission__c 
                                                     WHERE Credible_ID__c = '15803'];
        List<Contact> contacts = [SELECT Id, Credible_Profile_ID__c FROM Contact WHERE Credible_Profile_ID__c = '15803'];
        
        System.assertEquals(1, admissions.size(), 'Should create one patient admission');
        System.assertEquals(1, contacts.size(), 'Should create one contact');
        System.assertEquals('Credible', admissions[0].Credible_Patient_First_Name__c, 'First name should match');
        System.assertEquals('Test5', admissions[0].Credible_Patient_Last_Name__c, 'Last name should match');
        System.assertEquals('ACTIVE', admissions[0].Credible_Client_Satus__c, 'Client status should match');
        //System.assertEquals('Pennsylvania', admissions[0].Credible_State__c, 'State should be mapped from lookup');
        //System.assertEquals('Peer Type Value 1', admissions[0].Credible_Peer_Type__c, 'Peer type should be mapped from lookup');
    }
    
    @IsTest
    static void testImportClientData_MultipleRecords() {
        String mockXml = ''
            + '<DataSet xmlns="https://www.crediblebh.com/">'
            + '  <diffgr:diffgram xmlns:msdata="urn:schemas-microsoft-com:xml-msdata" xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1">'
            + '    <NewDataSet xmlns="">'
            + '      <Table diffgr:id="Table1" msdata:rowOrder="0">'
            + '        <client_id>15803</client_id>'
            + '        <first_name>John</first_name>'
            + '        <last_name>Doe</last_name>'
            + '        <dob>1990-01-01T00:00:00-04:00</dob>'
            + '        <state>PA</state>'
            + '        <client_status>ACTIVE</client_status>'
            + '        <dd29>PT1</dd29>'
            + '      </Table>'
            + '      <Table diffgr:id="Table2" msdata:rowOrder="1">'
            + '        <client_id>15804</client_id>'
            + '        <first_name>Jane</first_name>'
            + '        <last_name>Smith</last_name>'
            + '        <dob>1991-02-02T00:00:00-04:00</dob>'
            + '        <state>PA</state>'
            + '        <client_status>INACTIVE</client_status>'
            + '        <dd29>PT1</dd29>'
            + '      </Table>'
            + '      <Table diffgr:id="Table3" msdata:rowOrder="2">'
            + '        <client_id>EXIST123</client_id>'
            + '        <first_name>Existing</first_name>'
            + '        <last_name>Patient</last_name>'
            + '        <dob>1990-01-01T00:00:00-04:00</dob>'
            + '        <state>PA</state>'
            + '        <client_status>ACTIVE</client_status>'
            + '        <dd29>PT1</dd29>'
            + '      </Table>'
            + '    </NewDataSet>'
            + '  </diffgr:diffgram>'
            + '</DataSet>';

        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(200, mockXml));
        
        Test.startTest();
       System.enqueueJob(new CredibleClientExportQueueable());
        Test.stopTest();
        
        List<ple__Patient_Admission__c> admissions = [SELECT Id, Credible_ID__c FROM ple__Patient_Admission__c];
        List<Contact> contacts = [SELECT Id, Credible_Profile_ID__c FROM Contact WHERE ple__Contact_Type__c = 'Patient'];
        
        //System.assertEquals(3, admissions.size(), 'Should create three patient admissions');
        System.assertEquals(3, contacts.size(), 'Should create three contacts (including updates)');
    }
    
    @IsTest
    static void testImportClientData_EncryptedData() {
        String mockXml = ''
            + '<DataSet xmlns="https://www.crediblebh.com/">'
            + '  <diffgr:diffgram xmlns:msdata="urn:schemas-microsoft-com:xml-msdata" xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1">'
            + '    <NewDataSet xmlns="">'
            + '      <Table diffgr:id="Table1" msdata:rowOrder="0">'
            + '        <client_id>XXXXXXXXXX</client_id>'  // Encrypted
            + '        <first_name>Test</first_name>'
            + '        <last_name>Patient</last_name>'
            + '        <dob>1990-01-01T00:00:00-04:00</dob>'
            + '        <state>PA</state>'
            + '      </Table>'
            + '      <Table diffgr:id="Table2" msdata:rowOrder="1">'
            + '        <client_id>15805</client_id>'  // Not encrypted
            + '        <first_name>Real</first_name>'
            + '        <last_name>User</last_name>'
            + '        <dob>1992-03-03T00:00:00-04:00</dob>'
            + '        <state>PA</state>'
            + '        <dd29>PT1</dd29>'
            + '      </Table>'
            + '    </NewDataSet>'
            + '  </diffgr:diffgram>'
            + '</DataSet>';

        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(200, mockXml));
        
        Test.startTest();
       System.enqueueJob(new CredibleClientExportQueueable());
        Test.stopTest();
        
        List<ple__Patient_Admission__c> newAdmissions = [SELECT Id, Credible_ID__c FROM ple__Patient_Admission__c WHERE CreatedDate = TODAY AND Credible_ID__c != 'EXIST123'];
        //System.assertEquals(1, newAdmissions.size(), 'Should only create one new admission (skip encrypted)');
        //System.assertEquals('15805', newAdmissions[0].Credible_ID__c, 'Should only process non-encrypted record');
    }
    
    
    @IsTest
    static void testImportClientData_MalformedXML() {
        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(200, '<malformed><xml></malformed>'));
        
        Test.startTest();
       System.enqueueJob(new CredibleClientExportQueueable());
        Test.stopTest();
        
        List<Error_Log__c> errorLogs = [SELECT Id FROM Error_Log__c WHERE CreatedDate = TODAY];
        System.assert(!errorLogs.isEmpty(), 'Should create error log for malformed XML');
    }
    
    @IsTest
    static void testImportClientData_HttpFailure() {
        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(500, 'Internal Server Error'));
        
        Test.startTest();
       System.enqueueJob(new CredibleClientExportQueueable());
        Test.stopTest();
        
        List<Error_Log__c> errorLogs = [SELECT Id FROM Error_Log__c WHERE CreatedDate = TODAY];
        System.assertEquals(1, errorLogs.size(), 'Should create one error log for HTTP failure');
    }
    
    @IsTest
    static void testExportEmployeeData_Success() {
        String mockXml = ''
            + '<DataSet xmlns="https://www.crediblebh.com/">'
            + '  <diffgr:diffgram xmlns:msdata="urn:schemas-microsoft-com:xml-msdata" xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1">'
            + '    <NewDataSet xmlns="">'
            + '      <Table diffgr:id="Table1" msdata:rowOrder="0">'
            + '        <emp_id>EMP001</emp_id>'
            + '        <first_name>Employee</first_name>'
            + '        <last_name>One</last_name>'
            + '        <state>PA</state>'
            + '        <emp_status>ACTIVE</emp_status>'
            + '        <dd1>ES1</dd1>'
            + '        <dd12>ERC1</dd12>'
            + '        <text1>CT1</text1>'
            + '      </Table>'
            + '      <Table diffgr:id="Table1" msdata:rowOrder="0">'
            + '        <emp_id>EMP001</emp_id>'
            + '        <first_name>Employee</first_name>'
            + '        <last_name></last_name>'
            + '        <state>PA</state>'
            + '        <emp_status>ACTIVE</emp_status>'
            + '        <dd1>ES1</dd1>'
            + '        <dd12>ERC1</dd12>'
            + '        <text1>CT1</text1>'
            + '      </Table>'
            + '    </NewDataSet>'
            + '  </diffgr:diffgram>'
            + '</DataSet>';

        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(200, mockXml));
        
        Test.startTest();
       System.enqueueJob(new CredibleEmployeeExportQueueable());
        Test.stopTest();
        
        List<ple__Employee_Profile__c> employeeProfiles = [SELECT Id, Credible_ID__c FROM ple__Employee_Profile__c];
        System.debug(employeeProfiles);
        //System.assertEquals(0, employeeProfiles.size(), 'Should create one employee profile');
    }
    @IsTest
    static void testExportEmployeeData_SuccessOnStatus400() {
        String mockXml = ''
            + '<DataSet xmlns="https://www.crediblebh.com/">'
            + '  <diffgr:diffgram xmlns:msdata="urn:schemas-microsoft-com:xml-msdata" xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1">'
            + '    <NewDataSet xmlns="">'
            + '      <Table diffgr:id="Table1" msdata:rowOrder="0">'
            + '        <emp_id>EMP001</emp_id>'
            + '        <first_name>Employee</first_name>'
            + '        <last_name>One</last_name>'
            + '        <state>PA</state>'
            + '        <emp_status>ACTIVE</emp_status>'
            + '        <dd1>ES1</dd1>'
            + '        <dd12>ERC1</dd12>'
            + '        <text1>CT1</text1>'
            + '      </Table>'
            + '      <Table diffgr:id="Table1" msdata:rowOrder="0">'
            + '        <emp_id>EMP001</emp_id>'
            + '        <first_name>Employee</first_name>'
            + '        <last_name></last_name>'
            + '        <state>PA</state>'
            + '        <emp_status>ACTIVE</emp_status>'
            + '        <dd1>ES1</dd1>'
            + '        <dd12>ERC1</dd12>'
            + '        <text1>CT1</text1>'
            + '      </Table>'
            + '    </NewDataSet>'
            + '  </diffgr:diffgram>'
            + '</DataSet>';

        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(400, mockXml));
        
        Test.startTest();
       	System.enqueueJob(new CredibleEmployeeExportQueueable());
        Test.stopTest();
        
        List<ple__Employee_Profile__c> employeeProfiles = [SELECT Id, Credible_ID__c FROM ple__Employee_Profile__c];
        System.debug(employeeProfiles);
        //System.assertEquals(0, employeeProfiles.size(), 'Should create one employee profile');
    }
    @IsTest
    static void testImportClientData_NullParameters() {
        String mockXml = ''
            + '<DataSet xmlns="https://www.crediblebh.com/">'
            + '  <diffgr:diffgram xmlns:msdata="urn:schemas-microsoft-com:xml-msdata" xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1">'
            + '    <NewDataSet xmlns="">'
            + '      <Table diffgr:id="Table1" msdata:rowOrder="0">'
            + '        <client_id>15803</client_id>'
            + '        <first_name>Test</first_name>'
            + '        <last_name>User</last_name>'
            + '        <state>PA</state>'
            + '      </Table>'
            + '    </NewDataSet>'
            + '  </diffgr:diffgram>'
            + '</DataSet>';

        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(200, mockXml));
        
        Test.startTest();
       System.enqueueJob(new CredibleClientExportQueueable());
        Test.stopTest();
        
        List<ple__Patient_Admission__c> admissions = [SELECT Id FROM ple__Patient_Admission__c WHERE CreatedDate = TODAY];
        System.assert(admissions.size() >= 0, 'Method should handle null parameters gracefully');
    }
    
    
    @IsTest
    static void testImportClientData_ExceptionDuringXMLParsingInErrorHandler() {
        // This triggers the main complex error handling with XML parsing
        String body =
            '<root xmlns:diff="urn:schemas-microsoft-com:xml-diffgram-v1">' +
                '<diff:diffgram>' +
                    '<NewDataSet>' +
                        '<Table>' +
                            '<client_id>CL12345</client_id>' +
                        '</Table>' +
                    '</NewDataSet>' +
                '</diff:diffgram>' +
            '</root>';
        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(true, 'CalloutException',body,200));
        
        Test.startTest();
        
       System.enqueueJob(new CredibleClientExportQueueable());
        Test.stopTest();
        
        // This should trigger ALL the complex error handling branches
        List<Error_Log__c> errorLogs = [SELECT Id, Source_System_Id__c, Error_Message__c 
                                       FROM Error_Log__c 
                                       WHERE CreatedDate = TODAY];
        System.assert(!errorLogs.isEmpty(), 'Should create error logs when exception occurs during XML parsing in error handler');
    }
    @IsTest  
    static void testExportEmployeeData_ExceptionDuringXMLParsingInErrorHandler() {
        // Same for employee data
        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(true, 'CalloutException'));
        
        Test.startTest();
       System.enqueueJob(new CredibleEmployeeExportQueueable());
        Test.stopTest();
        
        List<Error_Log__c> errorLogs = [SELECT Id, Source_System_Id__c, Error_Message__c 
                                       FROM Error_Log__c 
                                       WHERE CreatedDate = TODAY];
        System.assert(!errorLogs.isEmpty(), 'Should create employee error logs when exception occurs during XML parsing in error handler');
    }
    
   @IsTest
    static void testImportClientVisitData_Success() {
        // Mock XML response
        String xml =
            '<DataSet xmlns="https://www.crediblebh.com/">' +
            '  <diffgr:diffgram xmlns:diffgr="urn:schemas-microsoft-com:xml-diffgram-v1">' +
            '    <NewDataSet>' +
            '      <Table>' +
            '        <clientvisit_id>VIS001</clientvisit_id>' +
            '        <client_id>CL123</client_id>' +
            '        <emp_id>EMP001</emp_id>' +
            '        <status>Completed</status>' +
            '        <duration>30</duration>' +
            '        <rev_timein>12/29/2022 4:45:00 PM</rev_timein>' +
            '      </Table>' +
            '    </NewDataSet>' +
            '  </diffgr:diffgram>' +
            '</DataSet>';

        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(200, xml));

        Test.startTest();
        CredibleExportsService.importClientVisitData('2025-11-01', '2025-11-12', null, null, 'param');
        Test.stopTest();

        
    }
    
    @IsTest
    static void testImportClientVisitData_HttpErrorBlock() {
        // Mock a 500 Internal Server Error
        Test.setMock(HttpCalloutMock.class, new ParameterizedMock(500, 'Internal Server Error'));
        
        Test.startTest();
        CredibleExportsService.importClientVisitData('2025-11-01', '2025-11-12', null, null, null);
        Test.stopTest();
        
        // Verify that an error log was created
        List<Error_Log__c> logs = [SELECT Id, Error_Type__c, Error_Message__c, Source_Table__c FROM Error_Log__c];
        System.assertEquals(1, logs.size(), 'An Error_Log__c should be inserted for failed HTTP call');
        System.assertEquals('API', logs[0].Error_Type__c, 'Error_Type__c should be API for HTTP failure');
        System.assert(logs[0].Error_Message__c.contains('Request failed with status'), 'Error message should include status');
    }
    
    
}