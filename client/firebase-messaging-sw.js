// Service worker: handles push messages while index.html is not in the
// foreground. Must be served from the same origin/path as index.html.
importScripts("https://www.gstatic.com/firebasejs/12.16.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/12.16.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAB9eOcQ0Anbn7TP83rFf0v36BBIQYgWRw",
  authDomain: "radio1965-fbffd.firebaseapp.com",
  projectId: "radio1965-fbffd",
  storageBucket: "radio1965-fbffd.firebasestorage.app",
  messagingSenderId: "43305541336",
  appId: "1:43305541336:web:abc18ff93537d6d81781ad",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] background message:", payload);
  const title = payload.notification?.title || "Radio 1965";
  const options = {
    body: payload.notification?.body || "",
  };
  self.registration.showNotification(title, options);
});
