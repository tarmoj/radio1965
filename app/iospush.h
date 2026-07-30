#pragma once

#include <QString>

// Configures Firebase/APNs, requests notification permission, and installs
// the delegates that forward incoming pushes to NotificationManager.
void iosPushInit();

// Subscribes this device to an FCM topic (mirrors PushMessagingService.subscribeToTopic on Android).
void iosPushSubscribeToTopic(const QString &topic);
