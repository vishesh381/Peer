/**
 * @description Test class for SchedulingConflictService
 * @author Peerstar Development Team
 */
@IsTest
private class SchedulingConflictServiceTest {

    @TestSetup
    static void setupTestData() {
        // Create test user
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User testUser = new User(
            FirstName = 'Test',
            LastName = 'CPS User',
            Email = 'testcps@peerstar.test',
            Username = 'testcps@peerstar.test.' + System.currentTimeMillis(),
            Alias = 'tcps',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert testUser;

        // Create test Account and Contact
        Account testAccount = new Account(Name = 'Test Peer Account');
        insert testAccount;

        Contact testPeer = new Contact(
            FirstName = 'John',
            LastName = 'Peer',
            AccountId = testAccount.Id
        );
        insert testPeer;

        // Create test Case
        Case testCase = new Case(
            Subject = 'Test Case Management',
            AccountId = testAccount.Id,
            ContactId = testPeer.Id,
            Status = 'New'
        );
        insert testCase;

        // Create working hours for the test user (today and tomorrow)
        Date today = Date.today();
        List<Staff_Availability__c> availabilities = new List<Staff_Availability__c>();

        // Working hours today 8 AM - 5 PM
        availabilities.add(new Staff_Availability__c(
            User__c = testUser.Id,
            Date__c = today,
            Start_Time__c = Time.newInstance(8, 0, 0, 0),
            End_Time__c = Time.newInstance(17, 0, 0, 0),
            Availability_Type__c = 'Working'
        ));

        // Working hours tomorrow
        availabilities.add(new Staff_Availability__c(
            User__c = testUser.Id,
            Date__c = today.addDays(1),
            Start_Time__c = Time.newInstance(8, 0, 0, 0),
            End_Time__c = Time.newInstance(17, 0, 0, 0),
            Availability_Type__c = 'Working'
        ));

        insert availabilities;

        // Create an existing scheduled service (10 AM - 11 AM today)
        Scheduled_Service__c existingService = new Scheduled_Service__c(
            Case__c = testCase.Id,
            Service_Type__c = 'Weekly Meeting',
            Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(10, 0, 0, 0)),
            Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(11, 0, 0, 0)),
            Duration_Minutes__c = 60,
            Assigned_User__c = testUser.Id,
            Status__c = 'Scheduled',
            Location_Type__c = 'Office'
        );
        insert existingService;
    }

    @IsTest
    static void testCheckConflicts_NoConflict() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Date today = Date.today();

        // Try to schedule at 2 PM - 3 PM (no conflict)
        DateTime proposedStart = DateTime.newInstance(today, Time.newInstance(14, 0, 0, 0));
        DateTime proposedEnd = DateTime.newInstance(today, Time.newInstance(15, 0, 0, 0));

        Test.startTest();
        List<SchedulingConflictService.ConflictResult> conflicts =
            SchedulingConflictService.checkConflicts(testUser.Id, proposedStart, proposedEnd);
        Test.stopTest();

        System.assertEquals(0, conflicts.size(), 'Should have no conflicts at 2 PM');
    }

    @IsTest
    static void testCheckConflicts_WithExistingAppointment() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Date today = Date.today();

        // Try to schedule at 10:30 AM - 11:30 AM (overlaps with existing 10-11 AM)
        DateTime proposedStart = DateTime.newInstance(today, Time.newInstance(10, 30, 0, 0));
        DateTime proposedEnd = DateTime.newInstance(today, Time.newInstance(11, 30, 0, 0));

        Test.startTest();
        List<SchedulingConflictService.ConflictResult> conflicts =
            SchedulingConflictService.checkConflicts(testUser.Id, proposedStart, proposedEnd);
        Test.stopTest();

        System.assertEquals(1, conflicts.size(), 'Should detect conflict with existing appointment');
        System.assertEquals('Existing Appointment', conflicts[0].conflictType, 'Conflict type should be Existing Appointment');
        System.assert(conflicts[0].hasConflict, 'hasConflict should be true');
    }

    @IsTest
    static void testCheckConflicts_WithPTO() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Date tomorrow = Date.today().addDays(1);

        // Add PTO for tomorrow afternoon
        Staff_Availability__c pto = new Staff_Availability__c(
            User__c = testUser.Id,
            Date__c = tomorrow,
            Start_Time__c = Time.newInstance(13, 0, 0, 0),
            End_Time__c = Time.newInstance(17, 0, 0, 0),
            Availability_Type__c = 'PTO',
            Notes__c = 'Doctor appointment'
        );
        insert pto;

        // Try to schedule during PTO
        DateTime proposedStart = DateTime.newInstance(tomorrow, Time.newInstance(14, 0, 0, 0));
        DateTime proposedEnd = DateTime.newInstance(tomorrow, Time.newInstance(15, 0, 0, 0));

        Test.startTest();
        List<SchedulingConflictService.ConflictResult> conflicts =
            SchedulingConflictService.checkConflicts(testUser.Id, proposedStart, proposedEnd);
        Test.stopTest();

        System.assertEquals(1, conflicts.size(), 'Should detect PTO conflict');
        System.assertEquals('PTO', conflicts[0].conflictType, 'Conflict type should be PTO');
    }

    @IsTest
    static void testCheckConflicts_ExcludeRecord() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Scheduled_Service__c existingService = [
            SELECT Id, Scheduled_Start__c, Scheduled_End__c
            FROM Scheduled_Service__c
            LIMIT 1
        ];

        // Check for conflicts at the same time but exclude the existing record (simulating an update)
        Test.startTest();
        List<SchedulingConflictService.ConflictResult> conflicts =
            SchedulingConflictService.checkConflicts(
                testUser.Id,
                existingService.Scheduled_Start__c,
                existingService.Scheduled_End__c,
                existingService.Id
            );
        Test.stopTest();

        System.assertEquals(0, conflicts.size(), 'Should not conflict with itself when excluded');
    }

    @IsTest
    static void testIsStaffAvailable_Available() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Date today = Date.today();

        // Check availability at 2 PM - 3 PM (within working hours, no conflicts)
        DateTime proposedStart = DateTime.newInstance(today, Time.newInstance(14, 0, 0, 0));
        DateTime proposedEnd = DateTime.newInstance(today, Time.newInstance(15, 0, 0, 0));

        Test.startTest();
        Boolean isAvailable = SchedulingConflictService.isStaffAvailable(
            testUser.Id, proposedStart, proposedEnd
        );
        Test.stopTest();

        System.assert(isAvailable, 'Staff should be available at 2 PM');
    }

    @IsTest
    static void testIsStaffAvailable_NotAvailable_Conflict() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Date today = Date.today();

        // Check availability during existing appointment
        DateTime proposedStart = DateTime.newInstance(today, Time.newInstance(10, 0, 0, 0));
        DateTime proposedEnd = DateTime.newInstance(today, Time.newInstance(11, 0, 0, 0));

        Test.startTest();
        Boolean isAvailable = SchedulingConflictService.isStaffAvailable(
            testUser.Id, proposedStart, proposedEnd
        );
        Test.stopTest();

        System.assert(!isAvailable, 'Staff should not be available during existing appointment');
    }

    @IsTest
    static void testGetAvailableSlots() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Date today = Date.today();

        Test.startTest();
        List<DateTime> slots = SchedulingConflictService.getAvailableSlots(
            testUser.Id,
            today,
            60 // 60 minute duration
        );
        Test.stopTest();

        // Should have slots but not include 10 AM (existing appointment)
        System.assert(slots.size() > 0, 'Should have available slots');

        DateTime conflictTime = DateTime.newInstance(today, Time.newInstance(10, 0, 0, 0));
        Boolean hasConflictSlot = false;
        for (DateTime slot : slots) {
            if (slot == conflictTime) {
                hasConflictSlot = true;
                break;
            }
        }
        System.assert(!hasConflictSlot, 'Should not include 10 AM slot due to existing appointment');
    }

    @IsTest
    static void testCheckConflictsInvocable() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Date today = Date.today();

        // Test invocable method
        SchedulingConflictService.ConflictCheckRequest request =
            new SchedulingConflictService.ConflictCheckRequest();
        request.userId = testUser.Id;
        request.proposedStart = DateTime.newInstance(today, Time.newInstance(10, 30, 0, 0));
        request.proposedEnd = DateTime.newInstance(today, Time.newInstance(11, 30, 0, 0));

        Test.startTest();
        List<SchedulingConflictService.ConflictCheckResponse> responses =
            SchedulingConflictService.checkConflictsInvocable(
                new List<SchedulingConflictService.ConflictCheckRequest>{ request }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assert(responses[0].hasConflicts, 'Should detect conflict');
        System.assertEquals(1, responses[0].conflictCount, 'Should have one conflict');
        System.assert(String.isNotBlank(responses[0].conflictDetails), 'Should have conflict details');
    }

    @IsTest
    static void testConflictResult_NoConflict() {
        SchedulingConflictService.ConflictResult result = new SchedulingConflictService.ConflictResult();
        System.assert(!result.hasConflict, 'Default constructor should set hasConflict to false');
    }
}