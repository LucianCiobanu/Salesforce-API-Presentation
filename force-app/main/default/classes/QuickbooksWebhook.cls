@RestResource(urlMapping='/QBOWebhook') 
global class QuickbooksWebhook {
    
    // Method to handle inbound POST requests
    @HttpPost
    global static void handlePOST() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        // First, we need to validate the request is in the correct format
        QuickbooksAPI.WebhookRequest reqObj;
        try {
            reqObj = (QuickbooksAPI.WebhookRequest)JSON.deserialize(req.requestBody.toString(), QuickbooksAPI.WebhookRequest.class);
        } catch (Exception ex) {
            res.statusCode = 400;
            QuickbooksAPI.CreateIncomingLog(req, res);
            QuickbooksAPI.SaveLogs();
            return;
        }

        try {
            // Call the helper method with the logic to handle the event
            QuickbooksHelper.HandleWebhook(reqObj);
            res.statusCode = 200;
            QuickbooksAPI.CreateIncomingLog(req, res);
            QuickbooksAPI.SaveLogs();
        } catch (Exception ex) {
            // If it fails, return 500
            res.statusCode = 500;
            QuickbooksAPI.CreateIncomingLog(req, res);
            QuickbooksAPI.SaveLogs();
        }

    }
}