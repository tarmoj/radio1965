#include "screenpinner.h"

#ifndef Q_OS_ANDROID

void ScreenPinner::setEnabled(bool /*enabled*/)
{
    // No app-triggerable equivalent on this platform (iOS's Guided Access
    // is user-enabled only, not something an app can turn on itself) -
    // lockOverlay's own QML-level input blocking is all that applies here.
}

#endif
