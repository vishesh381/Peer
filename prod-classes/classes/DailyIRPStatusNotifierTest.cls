@IsTest
public class DailyIRPStatusNotifierTest {

    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Alias = 'tuser',
            Email = 'testuser@example.com',
            Username = 'testuser' + DateTime.now().getTime() + '@example.com',
            EmailEncodingKey = 'UTF-8',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert testUser;
		 System.runAs(new User(Id = UserInfo.getUserId())) {
        Group rsmQueue = new Group(
            Name = 'RSM Queue',
            Type = 'Queue',
            Email = 'testqueue@example.com',
            DoesSendEmailToMembers = true
        );
        insert rsmQueue;
        
        GroupMember gm = new GroupMember(GroupId = rsmQueue.Id, UserOrGroupId = testUser.Id);
        insert gm;
    }

        Contact patient = new Contact(FirstName = 'Test' , LastName = 'Patient', 	ple__Contact_Type__c = 'Patient');
        insert patient;
        
        

        ple__Referral__c referral = new ple__Referral__c(
            Name = 'Test Referral',
            ple__Patient__c = patient.Id
        );
        insert referral;

        ple__Action__c irpSchedulingAction = new ple__Action__c(
            ple__Referral__c = referral.Id,
            Name = 'IRP Scheduling'
            
        );
        insert irpSchedulingAction;
        
		List<ple__Service__c> services = new List<ple__Service__c>();
        services.add(new ple__Service__c(Name = 'Service 1'));
        services.add(new ple__Service__c(Name = 'Service 2'));
        insert services;

        List<ple__Referral_Service__c> referralService = new List<ple__Referral_Service__c>();
        
         referralService.add(new ple__Referral_Service__c(
            ple__Referral__c = referral.Id,
            ple__Service__c = services[0].Id
        ));
        referralService.add( new ple__Referral_Service__c(
            ple__Referral__c = referral.Id,
            ple__Service__c = services[1].Id
        ));
        insert referralService;

        // Insert dummy Documents for header/footer
        List<Document> docs = new List<Document>{
            new Document(Name = 'Pulse Email Header', FolderId = UserInfo.getUserId(), Body = Blob.valueOf('Header'), ContentType = 'text/html'),
            new Document(Name = 'Pulse Email Footer', FolderId = UserInfo.getUserId(), Body = Blob.valueOf('Footer'), ContentType = 'text/html')
        };
        insert docs;
    }

    @IsTest
    static void testSendIRPCompletedNotification() {
        List<ple__Action__c> actions = [SELECT Id, IRP_Status__c, IRP_Completion_Date__c FROM ple__Action__c WHERE Name ='IRP Scheduling'];
        actions[0].IRP_Status__c = 'Completed';
        actions[0].IRP_Completion_Date__c =  Date.today().addDays(-1);
       	update actions;
        Test.startTest();
        DailyIRPStatusNotifier.sendIRPCompletedNotification();
        System.assertEquals(1, Limits.getEmailInvocations(), 'One email should have been invoked for IRP Completed notification');
        Test.stopTest();
    }

    @IsTest
    static void testSendIRPScheduledNotification() {
         List<ple__Action__c> actions = [SELECT Id, IRP_Status__c, IRP_Scheduled__c FROM ple__Action__c WHERE Name ='IRP Scheduling'];
        actions[0].IRP_Status__c = 'Scheduled';
        actions[0].IRP_Scheduled__c =  Date.today().addDays(-1);
       	update actions;
        Test.startTest();
        DailyIRPStatusNotifier.sendIRPScheduledNotification();
        System.assertEquals(1, Limits.getEmailInvocations(), 'One email should have been invoked for IRP Scheduled notification');
        Test.stopTest();
 }

    @IsTest
    static void testExecuteSchedulable() {
        Test.startTest();
        String cronExp = '0 0 0 * * ?'; // arbitrary cron
        String jobId =  System.schedule('Test DailyIRPStatusNotifier', cronExp, new DailyIRPStatusNotifier());
        Test.stopTest();
		
        CronTrigger ct = [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE Id = :jobId LIMIT 1];
        System.assertEquals('Test DailyIRPStatusNotifier', ct.CronJobDetail.Name, 'Scheduled job should exist');
    }
}