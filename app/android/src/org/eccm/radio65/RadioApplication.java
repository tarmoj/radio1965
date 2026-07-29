package org.eccm.radio65;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.os.Build;

import org.qtproject.qt.android.bindings.QtApplication;

public class RadioApplication extends QtApplication {

    public static final String CHANNEL_ID = "radio65_default_channel";

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
    }

    // FCM needs a notification channel to exist before it can auto-display a
    // system-tray notification for messages received while the app is in the
    // background/killed (see the default_notification_channel_id meta-data
    // in AndroidManifest.xml, which must reference the same channel id).
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID, "Radio65 Notifications", NotificationManager.IMPORTANCE_DEFAULT);
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }
}
