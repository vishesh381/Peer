public class CredibleClientVisitExportQueueable implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext context) {
        Date today = Date.today();
        Date todayDate = Date.newInstance(today.year(), today.month(), today.day());
        
        
        CredibleExportsService.importClientVisitData(null, null, todayDate, todayDate, null);
    }
}