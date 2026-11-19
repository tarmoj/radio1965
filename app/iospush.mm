#include "qglobal.h"
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
    // autorelease: no ARC in this file (see Radio65strongPushDelegate init).
    NSString *payload = jsonData ? [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] autorelease] : @"";
    
    NSLog(@"[iospush] Message title: %@ body: %@", title, body);
    
    if (NotificationManager *manager = NotificationManager::instance()) {
        QMetaObject::invokeMethod(manager, "addMessage", Qt::QueuedConnection,
                                   Q_ARG(QString, QString::fromNSString(title)),
                                   Q_ARG(QString, QString::fromNSString(body)),
                                   Q_ARG(QString, QString::fromNSString(payload)));
    }
}

} // namespace



// Handles FCM token/topic subscription and foreground/tap notification delivery.
@interface Radio65strongPushDelegate : NSObject <FIRMessagingDelegate, UNUserNotificationCenterDelegate>
// Every topic the app wants, kept for the whole run (not cleared after a
// subscribe): FCM refuses topic subscriptions until the APNs device token
// is set, and the FCM token can arrive - and change - before and after
// that, so all of them are (re)subscribed each time a token arrives with
// APNs ready. Was a single pendingTopic slot that the second topic
// overwrote and the first, too early, token cleared - leaving the app
// subscribed to nothing.
@property(nonatomic, strong) NSMutableOrderedSet<NSString *> *topics;
- (void)subscribeAllIfReady;
@end

@implementation Radio65strongPushDelegate

- (instancetype)init
{
    // alloc/init, not [NSMutableOrderedSet orderedSet]: this file is built
    // WITHOUT ARC (CMakeLists.txt doesn't enable it), and assigning the
    // ivar directly skips the property's retain - an autoreleased set was
    // freed and its memory reused (crash: addObject: sent to a dictionary).
    // The delegate lives for the whole app run, so it is never released.
    if ((self = [super init]))
        _topics = [[NSMutableOrderedSet alloc] init];
    return self;
}

- (void)dealloc
{
    [_topics release];
    [super dealloc];
}

// Main thread only (callers dispatch there).
- (void)subscribeAllIfReady
{
    if (![FIRMessaging messaging].APNSToken) {
        NSLog(@"[iospush] APNs token not set yet, topics wait: %@", self.topics.array);
        return;
    }
    for (NSString *topic in self.topics) {
        [[FIRMessaging messaging] subscribeToTopic:topic completion:^(NSError *error) {
            if (error)
                NSLog(@"[iospush] Topic subscribe failed: %@ (%@)", topic, error.localizedDescription);
            else
                NSLog(@"[iospush] Topic subscribed: %@", topic);
        }];
    }
}

- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken
{
    Q_UNUSED(messaging)
    NSLog(@"[iospush] FCM registration token received: %@", fcmToken ?: @"<nil>");
    // Firebase sets the APNs token (via its app delegate proxy) before
    // issuing the token that goes with it, so this is the moment to retry.
    dispatch_async(dispatch_get_main_queue(), ^{
        [self subscribeAllIfReady];
    });
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

//namespace {
//Radio65strongPushDelegate *strongPushDelegate = nil;
//}

static Radio65strongPushDelegate *strongPushDelegate = nil;

void iosPushInit()
{
    
    if (strongPushDelegate)
            return;

        // 1. Configure Firebase here, where QIOSApplicationDelegate is officially alive
        if (![FIRApp defaultApp]) {
            [FIRApp configure];
            NSLog(@"[iospush] Firebase configured successfully inside iosPushInit.");
        } else {
            NSLog(@"[iospush] Firebase configured failed in  iosPushInit.");
        }

        // 2. Now set the delegates safely
        strongPushDelegate = [[Radio65strongPushDelegate alloc] init];
        [FIRMessaging messaging].delegate = strongPushDelegate;
        [UNUserNotificationCenter currentNotificationCenter].delegate = strongPushDelegate;
    

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
    if (!strongPushDelegate)
        return;
    NSString *nsTopic = topic.toNSString();
    dispatch_async(dispatch_get_main_queue(), ^{
        [strongPushDelegate.topics addObject:nsTopic];
        // Subscribes now if APNs is ready, else didReceiveRegistrationToken:
        // does it once it is.
        [strongPushDelegate subscribeAllIfReady];
    });
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
