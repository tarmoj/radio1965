package org.eccm.radio65;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;
import org.json.JSONObject;

public class PushMessagingService extends FirebaseMessagingService {

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        String title = "";
        String body = "";

        if (remoteMessage.getNotification() != null) {
            String notifTitle = remoteMessage.getNotification().getTitle();
            String notifBody = remoteMessage.getNotification().getBody();
            title = notifTitle != null ? notifTitle : "";
            body = notifBody != null ? notifBody : "";
        }

        String dataJson = new JSONObject(remoteMessage.getData()).toString();

        // NOTE: this only works while the app's native library is already
        // loaded in this process (app previously started, e.g. in foreground
        // or background). If Android starts this service in a fresh process
        // without ever starting the QtActivity, the native lib won't be
        // loaded yet and this call will throw UnsatisfiedLinkError.
        try {
            nativeOnMessageReceived(title, body, dataJson);
        } catch (UnsatisfiedLinkError e) {
            // App process/native lib not loaded (cold start) - ignored for now.
        }
    }

    public static native void nativeOnMessageReceived(String title, String body, String data);
}
