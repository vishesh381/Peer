/**
 * Queueable class to sync Employee data from Credible to Salesforce
 */
public class CredibleEmployeeExportQueueable implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        Date today = Date.today();
        Date todayDate = Date.newInstance(today.year(), today.month(), today.day());
        CredibleExportsService.importEmployeeData(null, null, todayDate, todayDate, null);
    }
}
