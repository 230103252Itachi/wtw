const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendTestNotification = functions.https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;

    if (!uid) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User not authenticated"
      );
    }

    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .get();

    if (!userDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "User not found"
      );
    }

    const user = userDoc.data();

    if (!user.fcmToken) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "FCM token not found"
      );
    }

    await admin.messaging().send({
      token: user.fcmToken,
      notification: {
        title: "WTW — тест",
        body: "Cloud Function работает 🚀",
      },
    });

    return { success: true };
  }
);
