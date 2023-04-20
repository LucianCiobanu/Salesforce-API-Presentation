public with sharing class QuickbooksHelper {

    // Method to send the invoices to Quickbooks, receives the invoices salesforce id
    // It can be called from triggers, so it's future
    @future(callout=true)
    public static void SendInvoices(Set<Id> invoiceIds) {

        // First, load the invoices from the database
        List<Invoice__c> invs = [SELECT Id, Date__c, Client__r.Name, QBO_Sync_Status__c, QBO_Sync_Message__c, QBO_ID__c,
                                        (SELECT Id, Total_Amount__c, Description__c, QBO_Category_Text__c, QBO_Category_Id__c FROM Invoice_Line_Items__r)
                                    FROM Invoice__c WHERE Id IN :invoiceIds];

        for (Invoice__c inv : invs) {

            // For each invoice, we first call the API method to find the quickbooks customer id
            QuickbooksAPI.QueryAccountsResponse resp = QuickbooksAPI.QueryAccounts(inv.Client__r.Name);

            if (resp.success == false) {
                // If it failed, store the error onto the Invoice record
                inv.QBO_Sync_Status__c = 'Error';
                inv.QBO_Sync_Message__c = resp.error;
                if (inv.QBO_Sync_Message__c.length() > 32767) {
                    inv.QBO_Sync_Message__c = inv.QBO_Sync_Message__c.substring(0, 32760) + '...';
                }
            } else {
                if (resp.QueryResponse.Customer != null && resp.QueryResponse.Customer.size() > 0) {

                    // If the call returned a customer id, we build the request to send the invoice with line items
                    QuickbooksAPI.SendInvoiceRequest req = new QuickbooksAPI.SendInvoiceRequest();
                    req.CustomerRef.value = resp.QueryResponse.Customer[0].Id;
                    req.TxnDate = String.valueOf(inv.Date__c);
        
                    for (Invoice_Line_Item__c ili : inv.Invoice_Line_Items__r) {
                        QuickbooksAPI.SendInvoiceRequestLine line = new QuickbooksAPI.SendInvoiceRequestLine();
                        line.Amount = ili.Total_Amount__c;
                        line.Description = ili.Description__c;

                        if (ili.QBO_Category_Id__c != null) {
                            line.SalesItemLineDetail.ItemRef.name = ili.QBO_Category_Text__c;
                            line.SalesItemLineDetail.ItemRef.value = ili.QBO_Category_Id__c;
                        }

                        req.Line.add(line);
                    }
        
                    // Then we call the API method to make the call
                    QuickbooksAPI.SendInvoiceResponse res = QuickbooksAPI.SendInvoice(req);
                    if (res.success) {
                        // If it's successful, we store the quickbooks id of the invoice
                        inv.QBO_Sync_Status__c = 'Success';
                        inv.QBO_Sync_Message__c = null;
                        inv.QBO_ID__c = res.Invoice.Id;
                    } else {
                        // If it's not successful, we store the error
                        inv.QBO_Sync_Status__c = 'Error';
                        inv.QBO_Sync_Message__c = res.error;
                    }
                } else {
                    // In case we can't find the customer by name
                    inv.QBO_Sync_Status__c = 'Error';
                    inv.QBO_Sync_Message__c = 'Customer with name "' + inv.Client__r.Name + '" not found in Quickbooks.';
                }
            }

        }

        // After all calls are made, we update the invoices
        update invs;

        // Finally, we save the logs
        QuickbooksAPI.SaveLogs();
    }

    // Method to create a new Customer in Quickbooks based on account ids
    public static void CreateCustomers(Set<Id> accountIds, boolean isRetry) {

        // First, let's extract the data from the database. Since we're using the mapping from custom metadata, we build the query dynamically
        Set<String> fields = new Set<String>();
        for (Quickbooks_Mapping__mdt mapMdt : Quickbooks_Mapping__mdt.getAll().values()) {
            if (mapMdt.Field__c != null) {
                if (mapMdt.Field__c.toLowerCase() != 'id') {
                    fields.add(mapMdt.Field__c);
                }
            }
        }

        string query = 'SELECT Id';
        for (String field : fields) {
            query += ', ' + field;
        }
        query += ' FROM Account WHERE Id IN :accountIds';

        List<Account> accounts = Database.query(query);

        Set<Id> failedIds = new Set<Id>();

        for (Account acc : accounts) {

            // For each account, we build the request body dynamically from custom metadata
            Map<String, Object> reqObj = new Map<String, Object>();

            for (Quickbooks_Mapping__mdt mapMdt : Quickbooks_Mapping__mdt.getAll().values()) {
                if (mapMdt.Field__c != null) {
                    reqObj.put(mapMdt.JSON_Node__c, acc.get(mapMdt.Field__c));
                } else if (mapMdt.Static_Value__c != null) {
                    reqObj.put(mapMdt.JSON_Node__c, mapMdt.Static_Value__c);
                }
            }

            // Then we call the API method that makes the actual call
            QuickbooksAPI.CreateCustomerResponse res = QuickbooksAPI.CreateCustomer(reqObj);
            if (res.success) {
                // And saves the customer id
                acc.QBO_Sync_Status__c = 'Success';
                acc.QBO_Sync_Message__c = null;
                acc.QBO_ID__c = res.Customer.Id;
            } else {
                // Or stores the error in case it fails
                acc.QBO_Sync_Status__c = 'Error';
                acc.QBO_Sync_Message__c = res.error;
                failedIds.add(acc.Id);
            }
        }

        // We update the accounts after all calls are finished
        update accounts;

        // Finally, we save logs
        QuickbooksAPI.SaveLogs();

        if (!isRetry && failedIds.size() > 0) {
            // In case it failed, schedule a retry 5 minutes later
            DateTime nextRetryTime = DateTime.now().addMinutes(5);
            QuickbooksRetryScheduled m = new QuickbooksRetryScheduled(failedIds);
            String sch = nextRetryTime.second() + ' ' + nextRetryTime.minute() + ' ' + nextRetryTime.hour() + ' ' + nextRetryTime.day() + ' ' + nextRetryTime.month() + ' ? ' + nextRetryTime.year();
            String schName = 'Retry_' + nextRetryTime.year() + '_' + nextRetryTime.month() + '_' + nextRetryTime.day() + '_' + nextRetryTime.hour() + '_' + nextRetryTime.minute() + '_' + nextRetryTime.second();
            System.Schedule(schName, sch, m);
        }
    }

    // Method called by the inbound webhook class to handle Quickbooks events
    public static void HandleWebhook(QuickbooksAPI.WebhookRequest reqObj) {

        // Do Stuff here
    }

}