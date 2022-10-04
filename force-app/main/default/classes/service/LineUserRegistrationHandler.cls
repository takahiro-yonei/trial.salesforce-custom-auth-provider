/**
 * Custom Registration Handler (for LINE)
 */
global class LineUserRegistrationHandler implements Auth.RegistrationHandler {
  private static final String TIME_ZONE = 'Asia/Tokyo';
  private static final String LANGUAGE = 'ja';
  private static final String LOCALE = 'ja_JP';
  private static final String EMAIL_ENCODE = 'UTF-8';


  global LineUserRegistrationHandler() {}


  /**
   *
   */
  global User createUser(Id portalId, Auth.UserData data) {
    List<User> userList = [Select Id From User Where LineId__c =: data.identifier and IsActive = true];
    User u = userList.isEmpty() ? new User() : userList[0];

    u.LastName = data.lastName;
    u.FirstName = data.firstName;
    u.Email = data.email;
    u.Username = data.username;
    u.Alias = data.username.substring(0, 8);
    u.ProfileId = data.attributeMap.get('profileId');
    u.TimeZoneSidKey = TIME_ZONE;
    u.LanguageLocaleKey = LANGUAGE;
    u.LocaleSidKey = LOCALE;
    u.EmailEncodingKey = EMAIL_ENCODE;

    u.LineId__c = data.identifier;
    u.LineUserName__c = data.attributeMap.get('displayName');
    u.LineProfileImageURL__c = data.attributeMap.get('pictureUrl');

    String siteId = System.Site.getSiteId();
    if(String.isEmpty(u.Id) && !String.isEmpty(siteId)) {
      Site site = [Select MasterLabel,UrlPathPrefix
        From Site
        Where Id =: siteId
        Limit 1];

      Network network = [Select SelfRegProfileId,OptionsSelfRegistrationEnabled
        From Network
        Where Name =: site.MasterLabel
        and UrlPathPrefix =:site.UrlPathPrefix
        Limit 1];

      if (!network.OptionsSelfRegistrationEnabled) {
        throw new RegistrationHandlerException('Self registration feature has to be enabled.');
      }

      Account a = new Account();
      a.name = data.fullname;
      insert a;

      Contact c = new Contact();
      c.AccountId = a.Id;
      c.FirstName = data.firstName;
      c.LastName  = data.lastName;
      c.Email = data.email;
      insert(c);

      u.ProfileId = network.SelfRegProfileId;
      u.contactId = c.Id;
      u.CommunityNickname = data.attributeMap.get('displayName');
    }

    return u;
  }

  /**
   *
   */
  global void updateUser(Id userId, Id portalId, Auth.UserData data) {
    User u = [Select ContactId
        ,LineId__c
        ,LineUserName__c
        ,LineProfileImageURL__c
      From User Where Id =: userId];

    u.LineId__c = data.identifier;
    u.LineUserName__c = data.attributeMap.get('displayName');
    u.LineProfileImageURL__c = data.attributeMap.get('pictureUrl');

    update(u);
  }


  private class RegistrationHandlerException extends Exception {}
}
