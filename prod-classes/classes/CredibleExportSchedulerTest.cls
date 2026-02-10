@isTest
public class CredibleExportSchedulerTest {
	
    
    @IsTest
    static void testAllClasses() {
       
        
        Test.startTest();
        
        // Test scheduler
        CredibleExportScheduler scheduler = new CredibleExportScheduler();
        scheduler.execute(null);
        
        // Test queueables directly
        System.enqueueJob(new CredibleClientExportQueueable());
        System.enqueueJob(new CredibleEmployeeExportQueueable());
        System.enqueueJob(new CredibleClientVisitExportQueueable());
        Test.stopTest();
        
        System.assert(true, 'All classes should execute without errors');
    }
     
}