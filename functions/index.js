const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// ─── 個人通知 → FCM プッシュ ────────────────────────────────────────────────
// notifications/{userId}/items/{itemId} に新規ドキュメントが追加された時に発火
// → そのユーザーのデバイスへプッシュ通知を送信する
exports.sendPushOnNotification = onDocumentCreated(
  'notifications/{userId}/items/{itemId}',
  async (event) => {
    const userId = event.params.userId;
    const data = event.data.data();

    const userDoc = await db.collection('users').doc(userId).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) return null;

    try {
      await messaging.send({
        token,
        notification: {
          title: data.title ?? 'Agridic',
          body: data.body ?? '',
        },
        data: {
          type: data.type ?? 'generic',
          postId: data.postId ?? '',
        },
        android: {
          priority: 'high',
          notification: { channelId: 'agridic_default' },
        },
        apns: {
          payload: { aps: { sound: 'default' } },
        },
      });
    } catch (err) {
      // 無効なトークンは Firestore から削除
      if (
        err.code === 'messaging/invalid-registration-token' ||
        err.code === 'messaging/registration-token-not-registered'
      ) {
        await db.collection('users').doc(userId).update({ fcmToken: null });
      }
      console.error('FCM personal push error:', err.code, err.message);
    }
    return null;
  }
);

// ─── 管理者ブロードキャスト → FCM トピック送信 ──────────────────────────────
// broadcasts/{broadcastId} に新規ドキュメントが追加された時に発火
// → 'broadcasts' トピック購読中の全デバイスへ送信
exports.sendPushOnBroadcast = onDocumentCreated(
  'broadcasts/{broadcastId}',
  async (event) => {
    const data = event.data.data();

    try {
      await messaging.send({
        topic: 'broadcasts',
        notification: {
          title: data.title ?? 'Agridic Alert',
          body: data.body ?? '',
        },
        data: { type: 'broadcast' },
        android: {
          priority: 'high',
          notification: { channelId: 'agridic_default' },
        },
        apns: {
          payload: { aps: { sound: 'default' } },
        },
      });
    } catch (err) {
      console.error('FCM broadcast error:', err.code, err.message);
    }
    return null;
  }
);
