/**
 * Custom Auth Provider (for LINE)
 */
global class LineAuthProvider extends Auth.AuthProviderPluginClass {
  global LineAuthProvider() {}

  /**
   *
   */
  global String getCustomMetadataType() {
    return 'LineAuthConfig__mdt';
  }

  /**
   *
   */
  global PageReference initiate(Map<string,string> authProviderConfiguration, String stateToPropagate) {

    //
    String url = String.format('https://access.line.me/oauth2/v2.1/authorize'
      + '?response_type=code'
      + '&client_id={0}'
      + '&redirect_uri={1}'
      + '&state={2}'
      + '&scope=' + EncodingUtil.urlEncode('profile openid', 'UTF-8'),
      new List<String>{
        authProviderConfiguration.get('ChannelId__c'),
        EncodingUtil.urlEncode(authProviderConfiguration.get('RedirectUri__c'), 'UTF-8'),
        stateToPropagate
      }
    );
    return new Pagereference(url);
  }

  /**
   *
   */
  global Auth.AuthProviderTokenResponse handleCallback(Map<string,string> authProviderConfiguration, Auth.AuthProviderCallbackState callbackState) {
    Map<String,String> queryParams = callbackState.queryParameters;
    String code = queryParams.get('code');
    String state = queryParams.get('state');

    HttpRequest req = new HttpRequest();
    req.setEndpoint('https://api.line.me/oauth2/v2.1/token');
    req.setHeader('Content-Type','application/x-www-form-urlencoded');
    req.setMethod('POST');
    req.setBody(
      'grant_type=authorization_code'
      + '&code=' + code
      + '&client_id=' + authProviderConfiguration.get('ChannelId__c')
      + '&client_secret=' + authProviderConfiguration.get('ClientSecret__c')
      + '&redirect_uri=' + EncodingUtil.urlEncode(authProviderConfiguration.get('RedirectUri__c'), 'UTF-8')
    );
    Http http = new Http();

    HttpResponse res = http.send(req);
    String responseBody = res.getBody();
    Map<String, Object> responseData = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
    String accessToken = (String)responseData.get('access_token');
    String refreshToken = (String)responseData.get('refresh_token');
    String idToken = (String)responseData.get('id_token');

    return new Auth.AuthProviderTokenResponse('LINE', idToken, refreshToken, state);
  }

  /**
   *
   */
  global Auth.UserData getUserInfo(Map<string,string> authProviderConfiguration, Auth.AuthProviderTokenResponse response) {
    HttpRequest req = new HttpRequest();

    // verify id token
    req.setEndpoint('https://api.line.me/oauth2/v2.1/verify');
    req.setHeader('Content-Type','application/x-www-form-urlencoded');
    req.setMethod('POST');
    req.setBody(
      'id_token=' + response.oauthToken
      + '&client_id=' + authProviderConfiguration.get('ChannelId__c')
    );

    Http h = new Http();
    HttpResponse res = h.send(req);
    String responseBody = res.getBody();
    System.debug('-------------------------');
    System.debug(responseBody);

    Map<String, Object> responseData = (Map<String, Object>)JSON.deserializeUntyped(responseBody);
    String userId = (String)responseData.get('sub');
    String displayName = (String)responseData.get('name');
    String pictureUrl = (String)responseData.get('picture');

    String email = userId + '@';
    if (String.isEmpty(Site.getSiteId())) {
      email += Url.getSalesforceBaseURL().toExternalForm().substringAfter('//');
    } else {
      email += Site.getDomain();
    }
    String locale = null;


    Map<String,String> attributeMap = new Map<String,String>();
    attributeMap.put('pictureUrl', pictureUrl);
    attributeMap.put('displayName', displayName);
    if (!String.isEmpty(authProviderConfiguration.get('ProfileId__c'))) {
      attributeMap.put('profileId', authProviderConfiguration.get('ProfileId__c'));
    }

    Auth.UserData u = new Auth.UserData(
      userId,
      displayName,
      'LINE',
      displayName + ' (LINE)',
      email,
      null,
      email,
      locale,
      'LINE',
      null,
      attributeMap
    );
    return u;
  }


}
