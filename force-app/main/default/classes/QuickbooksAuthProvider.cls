global class QuickbooksAuthProvider extends Auth.AuthProviderPluginClass {
    
    global String getCustomMetadataType() {
        return 'Quickbooks_API__mdt';
    } 
        
    global PageReference initiate(Map<string,string> authProviderConfiguration, String stateToPropagate) { 
        string authUrl = authProviderConfiguration.get('Auth_URL__c');
        string key = authProviderConfiguration.get('Consumer_Key__c');
        string scope = authProviderConfiguration.get('Scopes__c');
        string redirectUrl = authProviderConfiguration.get('Redirect_URL__c');
        
        String url = authUrl + '?client_id=' + key + '&scope=' + scope + '&redirect_uri=' + redirectUrl + '&response_type=code&state=' + stateToPropagate;
        return new PageReference(url); 
    } 
        
    global Auth.AuthProviderTokenResponse handleCallback(Map<string,string> authProviderConfiguration, Auth.AuthProviderCallbackState state) {
        string key = authProviderConfiguration.get('Consumer_Key__c');
        string secret = authProviderConfiguration.get('Consumer_Secret__c');
        string accessTokenUrl = authProviderConfiguration.get('Access_Token_URL__c');
        string redirectUrl = authProviderConfiguration.get('Redirect_URL__c');
    
        Map<String,String> queryParams = state.queryParameters; 
        String code = queryParams.get('code'); 
        String sfdcState = queryParams.get('state');
    
        HttpRequest req = new HttpRequest(); 
        String url = accessTokenUrl;

        req.setEndpoint(url);
        req.setHeader('Accept','application/json'); 
        req.setHeader('Content-Type','application/x-www-form-urlencoded');
        req.setBody('grant_type=authorization_code&code=' + code+ '&redirect_uri='+ redirectUrl);
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(key + ':' + secret)));
        req.setMethod('POST'); 
    
        Http http = new Http(); 
        HTTPResponse res = http.send(req); 
        String responseBody = res.getBody(); 
        Map<String, Object> responseObject = (Map<String, Object>)JSON.deserializeUntyped(responseBody);

        return new Auth.AuthProviderTokenResponse('Quickbooks', (String)responseObject.get('access_token'), (String)responseObject.get('refresh_token'), sfdcState); 
    }

    global override Auth.OAuthRefreshResult refresh(Map<String,String> authProviderConfiguration, String refreshToken) {
        string key = authProviderConfiguration.get('Consumer_Key__c'); 
        string secret = authProviderConfiguration.get('Consumer_Secret__c'); 
        string accessTokenUrl = authProviderConfiguration.get('Access_Token_URL__c'); 
    
        HttpRequest req = new HttpRequest(); 
        String url = accessTokenUrl;

        req.setEndpoint(url);
        req.setHeader('Accept','application/json'); 
        req.setHeader('Content-Type','application/x-www-form-urlencoded');
        req.setBody('grant_type=refresh_token&refresh_token=' + refreshToken);
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(key + ':' + secret)));
        req.setMethod('POST'); 
    
        Http http = new Http(); 
        HTTPResponse res = http.send(req); 
        String responseBody = res.getBody(); 
        Map<String, Object> responseObject = (Map<String, Object>)JSON.deserializeUntyped(responseBody);

        return new Auth.OAuthRefreshResult((String)responseObject.get('access_token'), (String)responseObject.get('refresh_token')); 
    }

    global Auth.UserData getUserInfo(Map<string,string> authProviderConfiguration, Auth.AuthProviderTokenResponse response) {
        return new Auth.UserData(UserInfo.getUserId(), 'Quickbooks', 'Integration', 'Quickbooks Integration', 
                            UserInfo.getUserEmail(), null, UserInfo.getUserName(), UserInfo.getLocale(), 
                            'Quickbooks', null, new Map<String,String>());
    }

}