package org.eccm.radio65;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import com.google.firebase.messaging.RemoteMessage;

import org.json.JSONObject;
import org.qtproject.qt.android.bindings.QtActivity;

public class MainActivity extends QtActivity {

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        forwardNotificationIntent(getIntent());
    }

    @Override
    public void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        forwardNotificationIntent(intent);
    }

    // When the app is in the background/killed, FCM shows the system-tray
    // notification itself and PushMessagingService.onMessageReceived() is
    // never called. Tapping that notification instead launches this
    // activity with the original FCM payload in the intent's extras, so
    // reconstruct the RemoteMessage from those extras here and forward it
    // through the same native bridge used for foreground messages.
    private void forwardNotificationIntent(Intent intent) {
        if (intent == null) {
            return;
        }
        Bundle extras = intent.getExtras();
        // FCM tap-launched intents always carry this extra (see
        // RemoteMessage.getMessageId()); anything else - including the
        // PendingIntent used by our own foreground notification, or Qt's
        // own launcher/source-info extras - is not an FCM payload.
        if (extras == null || !extras.containsKey("google.message_id")) {
            return;
        }

        try {
            RemoteMessage remoteMessage = new RemoteMessage(extras);

            String[] titleAndBody = PushMessagingService.resolveTitleAndBody(remoteMessage);
            String title = titleAndBody[0];
            String body = titleAndBody[1];
            String dataJson = new JSONObject(remoteMessage.getData()).toString();
            if (title.isEmpty() && body.isEmpty() && remoteMessage.getData().isEmpty()) {
                // Not an FCM payload (e.g. plain launcher start) - nothing to forward.
                return;
            }

            Log.d("MainActivity", "Forwarding tapped notification: " + dataJson);
            PushMessagingService.nativeOnMessageReceived(title, body, dataJson);
        } catch (UnsatisfiedLinkError e) {
            Log.d("MainActivity", "Native library not loaded yet, ignoring message: " + e.getMessage());
        } catch (Exception e) {
            // Not a well-formed FCM intent - ignore.
        }
    }
}
