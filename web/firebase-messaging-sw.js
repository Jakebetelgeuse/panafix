importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCMlyVMFeQ6SAn-8NQIhGAKLCmui0al03M',
  authDomain: 'panafix-app.firebaseapp.com',
  projectId: 'panafix-app',
  storageBucket: 'panafix-app.firebasestorage.app',
  messagingSenderId: '809573891168',
  appId: '1:809573891168:web:36c4eaf3462daf745b5705',
  measurementId: 'G-YG2QC843SH',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'Panafix';
  const options = {
    body: payload.notification?.body || 'Tienes una nueva actualizacion.',
    icon: '/icons/Icon-192.png',
  };

  self.registration.showNotification(title, options);
});
