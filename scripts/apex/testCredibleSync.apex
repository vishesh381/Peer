// Test Credible Sync with detailed logging
// Try a wider date range to see if there's any data

System.debug('=== Testing Credible Client Data Import ===');
Date today = Date.today();
Date thirtyDaysAgo = today.addDays(-30);

System.debug('Testing with date range: ' + thirtyDaysAgo + ' to ' + today);

// Test client sync with 30-day window
System.debug('--- Starting Client Data Test ---');
CredibleExportsService.importClientData(null, null, thirtyDaysAgo, today, null);

System.debug('--- Starting Employee Data Test ---');
CredibleExportsService.importEmployeeData(null, null, thirtyDaysAgo, today, null);

System.debug('--- Starting Client Visit Data Test ---');
CredibleExportsService.importClientVisitData(null, null, thirtyDaysAgo, today, null);

System.debug('=== Credible Sync Test Complete ===');
