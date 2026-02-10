// Run all three Credible syncs immediately
System.enqueueJob(new CredibleClientExportQueueable());
System.enqueueJob(new CredibleEmployeeExportQueueable());
System.enqueueJob(new CredibleClientVisitExportQueueable());
System.debug('All Credible sync jobs enqueued!');
