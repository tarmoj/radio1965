#include "screenkeeper.h"

#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS)

void ScreenKeeper::setEnabled(bool /*enabled*/)
{
    // Nothing to do - desktop/other builds have no screen-timeout concern
    // to work around here.
}

#endif
