#include "qglobal.h"
#include "screenkeeper.h"

#ifdef Q_OS_IOS

#import <UIKit/UIKit.h>

void ScreenKeeper::setEnabled(bool enabled)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication sharedApplication].idleTimerDisabled = enabled;
    });
}

#endif // Q_OS_IOS
