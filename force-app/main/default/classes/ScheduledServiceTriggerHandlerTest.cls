/**
 * @description Test class for ScheduledServiceTriggerHandler
 * @author Peerstar Development Team
 */
@IsTest
private class ScheduledServiceTriggerHandlerTest {

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
            Status = 'New',
            No_Show_Count__c = 0
        );
        insert testCase;

        // Create working hours for the test user
        Date today = Date.today();
        Staff_Availability__c availability = new Staff_Availability__c(
            User__c = testUser.Id,
            Date__c = today,
            Start_Time__c = Time.newInstance(8, 0, 0, 0),
            End_Time__c = Time.newInstance(17, 0, 0, 0),
            Availability_Type__c = 'Working'
        );
        insert availability;
    }

    @IsTest
    static void testInsert_SetsDefaults() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Date today = Date.today();

        Scheduled_Service__c service = new Scheduled_Service__c(
            Case__c = testCase.Id,
            Service_Type__c = 'Weekly Meeting',
            Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(14, 0, 0, 0)),
            Duration_Minutes__c = 60,
            Assigned_User__c = testUser.Id,
            Location_Type__c = 'Office'
        );

        Test.startTest();
        insert service;
        Test.stopTest();

        service = [SELECT Id, Status__c, Scheduled_End__c, Reschedule_Count__c
                   FROM Scheduled_Service__c WHERE Id = :service.Id];

        System.assertEquals('Scheduled', service.Status__c, 'Status should default to Scheduled');
        System.assertNotEquals(null, service.Scheduled_End__c, 'End time should be calculated');
        System.assertEquals(0, service.Reschedule_Count__c, 'Reschedule count should be 0');
    }

    @IsTest
    static void testInsert_CalculatesDuration() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Date today = Date.today();

        Scheduled_Service__c service = new Scheduled_Service__c(
            Case__c = testCase.Id,
            Service_Type__c = 'Weekly Meeting',
            Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(14, 0, 0, 0)),
            Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(15, 30, 0, 0)),
            Assigned_User__c = testUser.Id,
            Location_Type__c = 'Office'
        );

        Test.startTest();
        insert service;
        Test.stopTest();

        service = [SELECT Id, Duration_Minutes__c FROM Scheduled_Service__c WHERE Id = :service.Id];

        System.assertEquals(90, service.Duration_Minutes__c, 'Duration should be calculated as 90 minutes');
    }

    @IsTest
    static void testInsert_ConflictPrevented() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Date today = Date.today();

        // Create first appointment
        Scheduled_Service__c service1 = new Scheduled_Service__c(
            Case__c = testCase.Id,
            Service_Type__c = 'Weekly Meeting',
            Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(14, 0, 0, 0)),
            Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(15, 0, 0, 0)),
            Assigned_User__c = testUser.Id,
            Status__c = 'Scheduled',
            Location_Type__c = 'Office'
        );
        insert service1;

        // Try to create overlapping appointment
        Scheduled_Service__c service2 = new Scheduled_Service__c(
            Case__c = testCase.Id,
            Service_Type__c = 'Initial IRP',
            Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(14, 30, 0, 0)),
            Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(15, 30, 0, 0)),
            Assigned_User__c = testUser.Id,
            Status__c = 'Scheduled',
            Location_Type__c = 'Office'
        );

        Test.startTest();
        try {
            insert service2;
            System.assert(false, 'Should have thrown an exception for conflict');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Scheduling conflict'),
                'Error should mention scheduling conflict');
        }
        Test.stopTest();
    }

    @IsTest
    static void testUpdate_TracksReschedule() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Date today = Date.today();

        Scheduled_Service__c service = new Scheduled_Service__c(
            Case__c = testCase.Id,
            Service_Type__c = 'Weekly Meeting',
            Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(14, 0, 0, 0)),
            Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(15, 0, 0, 0)),
            Assigned_User__c = testUser.Id,
            Status__c = 'Scheduled',
            Location_Type__c = 'Office'
        );
        insert service;

        // Reschedule to a different time
        Test.startTest();
        service.Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(16, 0, 0, 0));
        service.Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(17, 0, 0, 0));
        update service;
        Test.stopTest();

        service = [SELECT Id, Reschedule_Count__c, Original_Scheduled_Start__c
                   FROM Scheduled_Service__c WHERE Id = :service.Id];

        System.assertEquals(1, service.Reschedule_Count__c, 'Reschedule count should be 1');
        System.assertNotEquals(null, service.Original_Scheduled_Start__c,
            'Original scheduled start should be preserved');
    }

    @IsTest
    static void testUpdate_NoShowCreatesTask() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Date today = Date.today();

        Scheduled_Service__c service = new Scheduled_Service__c(
            Case__c = testCase.Id,
            Service_Type__c = 'Weekly Meeting',
            Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(14, 0, 0, 0)),
            Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(15, 0, 0, 0)),
            Assigned_User__c = testUser.Id,
            Status__c = 'Scheduled',
            Location_Type__c = 'Office'
        );
        insert service;

        Test.startTest();
        service.Status__c = 'No Show';
        update service;
        Test.stopTest();

        // Verify task was created
        List<Task> tasks = [SELECT Id, Subject, WhatId FROM Task WHERE WhatId = :testCase.Id];
        System.assert(!tasks.isEmpty(), 'Follow-up task should be created');
        System.assert(tasks[0].Subject.contains('missed appointment'),
            'Task subject should mention missed appointment');

        // Verify case no-show count was updated
        Case updatedCase = [SELECT No_Show_Count__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(1, updatedCase.No_Show_Count__c, 'Case no-show count should be incremented');
    }

    @IsTest
    static void testUpdate_CanceledSkipsConflictCheck() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Date today = Date.today();

        // Create first appointment
        Scheduled_Service__c service1 = new Scheduled_Service__c(
            Case__c = testCase.Id,
            Service_Type__c = 'Weekly Meeting',
            Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(14, 0, 0, 0)),
            Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(15, 0, 0, 0)),
            Assigned_User__c = testUser.Id,
            Status__c = 'Scheduled',
            Location_Type__c = 'Office'
        );
        insert service1;

        // Create second appointment at different time
        Scheduled_Service__c service2 = new Scheduled_Service__c(
            Case__c = testCase.Id,
            Service_Type__c = 'Initial IRP',
            Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(16, 0, 0, 0)),
            Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(17, 0, 0, 0)),
            Assigned_User__c = testUser.Id,
            Status__c = 'Scheduled',
            Location_Type__c = 'Office'
        );
        insert service2;

        // Cancel first appointment and move it to second appointment's time
        // This should be allowed since we're canceling
        Test.startTest();
        service1.Status__c = 'Canceled';
        service1.Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(16, 0, 0, 0));
        service1.Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(17, 0, 0, 0));
        service1.Cancellation_Reason__c = 'Peer Request';
        update service1; // Should not throw error because it's being canceled
        Test.stopTest();

        service1 = [SELECT Status__c FROM Scheduled_Service__c WHERE Id = :service1.Id];
        System.assertEquals('Canceled', service1.Status__c, 'Service should be canceled');
    }

    @IsTest
    static void testMultipleReschedules_CreatesSupervisorAlert() {
        User testUser = [SELECT Id FROM User WHERE Email = 'testcps@peerstar.test' LIMIT 1];
        Case testCase = [SELECT Id FROM Case LIMIT 1];
        Date today = Date.today();

        Scheduled_Service__c service = new Scheduled_Service__c(
            Case__c = testCase.Id,
            Service_Type__c = 'Weekly Meeting',
            Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(9, 0, 0, 0)),
            Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(10, 0, 0, 0)),
            Assigned_User__c = testUser.Id,
            Status__c = 'Scheduled',
            Reschedule_Count__c = 2, // Already rescheduled twice
            Location_Type__c = 'Office'
        );
        insert service;

        // Reschedule again (third time)
        Test.startTest();
        service.Scheduled_Start__c = DateTime.newInstance(today, Time.newInstance(11, 0, 0, 0));
        service.Scheduled_End__c = DateTime.newInstance(today, Time.newInstance(12, 0, 0, 0));
        update service;
        Test.stopTest();

        // Verify supervisor alert task was created
        List<Task> tasks = [SELECT Id, Subject FROM Task
                           WHERE WhatId = :testCase.Id AND Subject LIKE '%Reschedule%'];
        System.assert(!tasks.isEmpty(), 'Supervisor alert task should be created after 3 reschedules');
    }
}