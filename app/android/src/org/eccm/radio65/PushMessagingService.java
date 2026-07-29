package org.eccm.radio65;
import android.util.Log;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;
import org.json.JSONException;
import org.json.JSONObject;

public class PushMessagingService extends FirebaseMessagingService {

    static {
        // Forces the C++ library to load as soon as this class is touched by Android
        try {
            System.loadLibrary("appradio65_arm64-v8a.so");
        } catch (UnsatisfiedLinkError e) {
            Log.e("PushMessagingService", "Failed to load native library: " + e.getMessage());
        }
    }

    // Called once from C++ (main.cpp) at startup so this device's FCM
    // registration receives messages sent to the server's topic
    // (see server/config.py TEST_TOPIC = "radio65_event").
    public static void subscribeToTopic(String topic) {
        FirebaseMessaging.getInstance().subscribeToTopic(topic);
    }

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        String[] titleAndBody = resolveTitleAndBody(remoteMessage);
        String title = titleAndBody[0];
        String body = titleAndBody[1];

        String dataJson = new JSONObject(remoteMessage.getData()).toString();

        Log.d("PushMessagingService", "Message JSON: " + dataJson + "  From: " + remoteMessage.getFrom());

        // NOTE: this only works while the app's native library is already
        // loaded in this process (app previously started, e.g. in foreground
        // or background). If Android starts this service in a fresh process
        // without ever starting the QtActivity, the native lib won't be
        // loaded yet and this call will throw UnsatisfiedLinkError.
        try {
            nativeOnMessageReceived(title, body, dataJson);
        } catch (UnsatisfiedLinkError e) {
            Log.d("PushMessagingService", "Native library not loaded yet, ignoring message: " + e.getMessage());
            // App process/native lib not loaded (cold start) - ignored for now.
        }
    }

    public static native void nativeOnMessageReceived(String title, String body, String data);

    // Resolves the title/summary to display for a message. Normally these
    // come straight from the FCM "notification" payload, but when a
    // background/killed-app notification tap is reconstructed from the
    // launch intent's extras (see MainActivity), the notification part is
    // sometimes stripped by the system before we see it - fall back to the
    // title/summary embedded in the "event" data field in that case (see
    // server/notifications.py send_event_notification()).
    static String[] resolveTitleAndBody(RemoteMessage remoteMessage) {
        String title = "";
        String body = "";

        if (remoteMessage.getNotification() != null) {
            String notifTitle = remoteMessage.getNotification().getTitle();
            String notifBody = remoteMessage.getNotification().getBody();
            title = notifTitle != null ? notifTitle : "";
            body = notifBody != null ? notifBody : "";
        }

        if (title.isEmpty() && body.isEmpty()) {
            String eventJson = remoteMessage.getData().get("event");
            if (eventJson != null) {
                try {
                    JSONObject event = new JSONObject(eventJson);
                    title = event.optString("title", "");
                    body = event.optString("summary", "");
                } catch (JSONException e) {
                    // Malformed event JSON - leave title/body empty.
                }
            }
        }

        return new String[]{title, body};
    }
}
