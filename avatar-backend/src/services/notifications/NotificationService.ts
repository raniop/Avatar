import prisma from '../../config/prisma';
// Import firebaseMessaging from our config to ensure the app is initialized with credentials
import { firebaseMessaging } from '../../config/firebase';

/**
 * Sends push notifications to parent devices via Firebase Cloud Messaging.
 */
export class NotificationService {
  /**
   * Send push notification to all parent-role devices for a given userId.
   */
  async notifyParentDevices(
    parentUserId: string,
    notification: { title: string; body: string },
    data?: Record<string, string>,
  ): Promise<void> {
    const deviceTokens = await prisma.deviceToken.findMany({
      where: {
        userId: parentUserId,
        role: 'parent',
        isActive: true,
      },
    });

    if (deviceTokens.length === 0) return;

    const tokens = deviceTokens.map((dt) => dt.token);

    try {
      const response = await firebaseMessaging.sendEachForMulticast({
        tokens,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: data || {},
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });

      // Log and deactivate stale/invalid tokens
      response.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error) {
          console.error(`[FCM] Token ${idx} failed:`, resp.error.code, resp.error.message);
          const code = resp.error.code;
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ) {
            prisma.deviceToken
              .update({
                where: { token: tokens[idx] },
                data: { isActive: false },
              })
              .catch(() => {});
          }
        }
      });

      console.log(
        `[FCM] Sent notification to ${response.successCount}/${tokens.length} parent devices for user ${parentUserId}`,
      );
    } catch (error) {
      console.error('[FCM] Send error:', error);
    }
  }

  /**
   * Notify parent that child started a conversation.
   */
  async notifyChildStartedPlaying(
    parentUserId: string,
    childName: string,
    conversationId: string,
    locale: string,
  ): Promise<void> {
    const isHebrew = locale === 'he';
    await this.notifyParentDevices(
      parentUserId,
      {
        title: isHebrew ? 'אווטאר' : 'Avatar',
        body: isHebrew
          ? `${childName} התחיל/ה לשחק!`
          : `${childName} started playing!`,
      },
      {
        type: 'child_started_playing',
        conversationId,
        childName,
      },
    );
  }
}
