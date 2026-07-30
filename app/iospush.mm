#include "iospush.h"

#ifdef Q_OS_IOS

#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseMessaging/FirebaseMessaging.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

#include <QMetaObject>
#include <QString>

#include "notificationmanager.h"

namespace {

// Forwards a push payload's title/body/data to the shared NotificationManager.
void forwardToNotificationManager(NSDictionary *userInfo)
{
    NSDictionary *aps = userInfo[@"aps"];
    NSDictionary *alert = [aps[@"alert"] isKindOfClass:[NSDictionary class]] ? aps[@"alert"] : nil;

    NSString *title = alert[@"title"] ?: userInfo[@"title"] ?: @"";
    NSString *body = alert[@"body"] ?: userInfo[@"body"] ?: @"";

    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:userInfo options:0 error:nil];
    NSString *payload = jsonData ? [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] : @"";

    if (NotificationManager *manager = NotificationManager::instance()) {
        QMetaObject::invokeMethod(manager, "addMessage", Qt::QueuedConnection,
                                   Q_ARG(QString, QString::fromNSString(title)),
                                   Q_ARG(QString, QString::fromNSString(body)),
                                   Q_ARG(QString, QString::fromNSString(payload)));
    }
}

} // namespace

// Handles FCM token/topic subscription and foreground/tap notification delivery.
@interface Radio65PushDelegate : NSObject <FIRMessagingDelegate, UNUserNotificationCenterDelegate>
@property(nonatomic, copy) NSString *pendingTopic;
@end

@implementation Radio65PushDelegate

- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken
{
    Q_UNUSED(messaging)
    Q_UNUSED(fcmToken)
    if (self.pendingTopic) {
        [[FIRMessaging messaging] subscribeToTopic:self.pendingTopic];
        self.pendingTopic = nil;
    }
}

// Foreground delivery: forward to NotificationManager and still let the banner show.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
        willPresentNotification:(UNNotification *)notification
          withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    Q_UNUSED(center)
    forwardToNotificationManager(notification.request.content.userInfo);
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

// Tap on a background/killed-app notification.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
 didReceiveNotificationResponse:(UNNotificationResponse *)response
          withCompletionHandler:(void (^)(void))completionHandler
{
    Q_UNUSED(center)
    forwardToNotificationManager(response.notification.request.content.userInfo);
    completionHandler();
}

@end

namespace {
Radio65PushDelegate *pushDelegate = nil;
}

void iosPushInit()
{
    if (pushDelegate)
        return;

    if (![FIRApp defaultApp])
        [FIRApp configure];

    pushDelegate = [[Radio65PushDelegate alloc] init];
    [FIRMessaging messaging].delegate = pushDelegate;
    [UNUserNotificationCenter currentNotificationCenter].delegate = pushDelegate;

    UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
    [[UNUserNotificationCenter currentNotificationCenter]
        requestAuthorizationWithOptions:options
                      completionHandler:^(BOOL granted, NSError *error) {
        Q_UNUSED(granted)
        Q_UNUSED(error)
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        });
    }];

    // The category below assumes Qt's iOS app delegate class is named
    // QIOSApplicationDelegate (private Qt implementation detail, not public
    // API). Check this log on first run and adjust the category below if it
    // doesn't match - see Further Considerations in the push notification plan.
    NSLog(@"[iospush] UIApplication.delegate class: %@",
          NSStringFromClass([[UIApplication sharedApplication].delegate class]));
}

void iosPushSubscribeToTopic(const QString &topic)
{
    NSString *nsTopic = topic.toNSString();
    [[FIRMessaging messaging] subscribeToTopic:nsTopic];
    if (pushDelegate)
        pushDelegate.pendingTopic = nsTopic;
}

// Adds a silent/content-available push handler to Qt's internal iOS app
// delegate class via an Objective-C category (no access to its real header).
// A category requires a real @interface (not just @class) to compile, so this
// stub redeclares just enough of the real, runtime-loaded class to satisfy it.
@interface QIOSApplicationDelegate : UIResponder <UIApplicationDelegate>
@end

@interface QIOSApplicationDelegate (Radio65Push)
- (void)application:(UIApplication *)application
        didReceiveRemoteNotification:(NSDictionary *)userInfo
              fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;
@end

@implementation QIOSApplicationDelegate (Radio65Push)

- (void)application:(UIApplication *)application
        didReceiveRemoteNotification:(NSDictionary *)userInfo
              fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    Q_UNUSED(application)
    forwardToNotificationManager(userInfo);
    completionHandler(UIBackgroundFetchResultNewData);
}

@end

#endif // Q_OS_IOS
