package org.eccm.radio65;
import android.util.Log;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;
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
        String title = "";
        String body = "";

        

        if (remoteMessage.getNotification() != null) {
            String notifTitle = remoteMessage.getNotification().getTitle();
            String notifBody = remoteMessage.getNotification().getBody();
            title = notifTitle != null ? notifTitle : "";
            body = notifBody != null ? notifBody : "";
        }

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
}
