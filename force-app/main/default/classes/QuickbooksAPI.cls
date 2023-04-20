public class QuickbooksAPI {

    private static List<Quickbooks_Call_Log__c> logs = new List<Quickbooks_Call_Log__c>();

    // Load and cache the API settings from custom metadata
    private static Quickbooks_API__mdt settingsPrivate;
    public static Quickbooks_API__mdt Settings { 
        get {
            if (settingsPrivate == null)
                settingsPrivate = [SELECT Named_Credential__c, Realm_Id__c, Save_Logs__c FROM Quickbooks_API__mdt LIMIT 1];
            return settingsPrivate;
        }
    }

    // API Method to test the API connection
    public static Boolean TestConnection() {
        
        String requestUrl = '/companyinfo/' + Settings.Realm_Id__c;
        
        HttpResponse response = MakeAPICall(requestUrl, 'GET', null);
        
        return response.getStatusCode() >= 200 && response.getStatusCode() < 300;
    }

    // API Method to find the Quickbooks customer Id by name
    public static QueryAccountsResponse QueryAccounts(String name) {

        string query = 'select Id from Customer where CompanyName = \'' + name + '\'';

        String requestUrl = '/query?query=' + EncodingUtil.urlEncode(query, 'UTF-8');
        
        HttpResponse response = MakeAPICall(requestUrl, 'GET', null);
        
        if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
            QueryAccountsResponse toReturn = (QueryAccountsResponse)JSON.deserialize(response.getBody(), QueryAccountsResponse.class);
            toReturn.success = true;
            return toReturn;
        } else {
            return new QueryAccountsResponse(false, response.getBody());
        }
    }

    // API Method to create and send a Quickbooks invoice to the customer
    public static SendInvoiceResponse SendInvoice(SendInvoiceRequest req) {
        
        String requestUrl = '/invoice';
        
        HttpResponse response = MakeAPICall(requestUrl, 'POST', JSON.serialize(req));
        
        if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
            SendInvoiceResponse toReturn = (SendInvoiceResponse)JSON.deserialize(response.getBody(), SendInvoiceResponse.class);
            toReturn.success = true;
            return toReturn;
        } else {
            return new SendInvoiceResponse(false, response.getBody());
        }
    }

    // API Method to create a Quickbooks customer
    public static CreateCustomerResponse CreateCustomer(Object req) {
        
        String requestUrl = '/customer';
        
        HttpResponse response = MakeAPICall(requestUrl, 'POST', JSON.serialize(req));
        
        if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
            CreateCustomerResponse toReturn = (CreateCustomerResponse)JSON.deserialize(response.getBody(), CreateCustomerResponse.class);
            toReturn.success = true;
            return toReturn;
        } else {
            return new CreateCustomerResponse(false, response.getBody());
        }
    }

    // General method to make the HTTP request and create a log record, used by all API methods above
    private static HttpResponse MakeAPICall(string url, string method, string body) {
        
        // Make the actual HTTP call
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'application/json');
        req.setEndpoint('callout:' + Settings.Named_Credential__c + '/v3/company/' + Settings.Realm_Id__c + url);
        req.setMethod(method);
        if (body != null)
            req.setBody(body);
        HttpResponse res = h.send(req);

        if (Settings.Save_Logs__c) {
            // If log saving is enabled, create a log record
            Quickbooks_Call_Log__c log = new Quickbooks_Call_Log__c();
            log.Direction__c = 'Outbound';
            log.URL__c = 'callout:' + Settings.Named_Credential__c + '/v3/company/' + Settings.Realm_Id__c + url;
            if (log.URL__c.length() > 255) {
                log.URL__c = log.URL__c.substring(0, 250) + '...';
            }
            log.Method__c = method;
            log.Success__c = res.getStatusCode() >= 200 && res.getStatusCode() < 300;
            if (body != null) {
                log.Request_Body__c = body;
                if (log.Request_Body__c.length() > 131070) {
                    log.Request_Body__c = log.Request_Body__c.substring(0, 131065) + '...';
                }
            }
            log.Response_Body__c = res.getBody();
            if (log.Response_Body__c.length() > 131070) {
                log.Response_Body__c = log.Response_Body__c.substring(0, 131065) + '...';
            }
            logs.add(log);
        }

        return res;
    }

    // Method to create an inbound log record from a HTTP inbound call
    public static void CreateIncomingLog(RestRequest req, RestResponse res) {

        if (Settings.Save_Logs__c) {
            Quickbooks_Call_Log__c log = new Quickbooks_Call_Log__c();
            log.Direction__c = 'Inbound';
            log.URL__c = req.requestURI;
            if (log.URL__c.length() > 255) {
                log.URL__c = log.URL__c.substring(0, 250) + '...';
            }
            log.Method__c = req.httpMethod;
            log.Success__c = res.statusCode >= 200 && res.statusCode < 300;
            if (req.requestBody != null) {
                log.Request_Body__c = req.requestBody.toString();
                if (log.Request_Body__c.length() > 131070) {
                    log.Request_Body__c = log.Request_Body__c.substring(0, 131065) + '...';
                }
            }
            if (res.responseBody != null) {
                log.Response_Body__c = res.responseBody.toString();
                if (log.Response_Body__c.length() > 131070) {
                    log.Response_Body__c = log.Response_Body__c.substring(0, 131065) + '...';
                }
            }
            logs.add(log);
        }
    }

    // Method to save stored logs after all calls are done
    public static void SaveLogs() {
        if (Settings.Save_Logs__c) {
            insert logs;
        }
        logs = new List<Quickbooks_Call_Log__c>();
    }

    // Create Customer Response classes
    public class CreateCustomerResponse {
        public boolean success { get; set; }
        public string error { get; set; }

        public CreateCustomerResponseCustomer Customer { get; set; }

        public CreateCustomerResponse(boolean success, string message) {
            
            this.success = success;
            if (!success) {
                this.error = message;
            }
        }
    }
    public class CreateCustomerResponseCustomer {
        public string Id { get; set; }
    }

    // Query Accounts Response classes
    public class QueryAccountsResponse {
        public boolean success { get; set; }
        public string error { get; set; }

        public QueryAccResponse QueryResponse { get; set; }

        public QueryAccountsResponse(boolean success, string message) {
            
            this.success = success;
            if (!success) {
                this.error = message;
            }
        }
    }
    public class QueryAccResponse {
        public List<QueryAccResponseCustomer> Customer { get; set; }
    }
    public class QueryAccResponseCustomer {
        public string Id { get; set; }
    }

    // Send Invoice Request classes
    public class SendInvoiceRequest {
        public SendInvoiceRequestCustomerRef CustomerRef { get; set; }
        public List<SendInvoiceRequestLine> Line { get; set; }
        public string TxnDate { get; set; }

        public SendInvoiceRequest() {
            CustomerRef = new SendInvoiceRequestCustomerRef();
            Line = new List<SendInvoiceRequestLine>();
        }
    }
    public class SendInvoiceRequestCustomerRef {
        public string value { get; set; }
    }
    public class SendInvoiceRequestLine {
        public string DetailType { get; set; }
        public decimal Amount { get; set; }
        public string Description { get; set; }
        public SendInvoiceRequestSalesItemLineDetail SalesItemLineDetail { get; set; }

        public SendInvoiceRequestLine() {
            DetailType = 'SalesItemLineDetail';
            SalesItemLineDetail = new SendInvoiceRequestSalesItemLineDetail();
        }
    }
    public class SendInvoiceRequestSalesItemLineDetail {
        public SendInvoiceRequestItemRef ItemRef { get; set; }

        public SendInvoiceRequestSalesItemLineDetail() {
            ItemRef = new SendInvoiceRequestItemRef();
        }
    }
    public class SendInvoiceRequestItemRef {
        public string name { get; set; }
        public string value { get; set; }

        public SendInvoiceRequestItemRef() {
        }
    }

    // Send Invoice Response classes
    public class SendInvoiceResponse {
        public boolean success { get; set; }
        public string error { get; set; }

        public SendInvResponseInvoice Invoice { get; set; }

        public SendInvoiceResponse(boolean success, string message) {
            
            this.success = success;
            if (!success) {
                this.error = message;
            }
        }
    }
    public class SendInvResponseInvoice {
        public string Id { get; set; }
    }

    // Webhook Request classes
    public class WebhookRequest {
        public List<WebhookRequestEventNot> eventNotifications { get; set; }
    }
    public class WebhookRequestEventNot {
        public WebhookRequestEvent dataChangeEvent { get; set; }
    }
    public class WebhookRequestEvent {
        public List<WebhookRequestEntity> entities { get; set; }
    }
    public class WebhookRequestEntity {
        public string name { get; set; }
        public string id { get; set; }
        public string operation { get; set; }
    }

}