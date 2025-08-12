/**
 * @fileoverview Firebase Cloud Functions for notification system
 */

const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// Set global options (optional)
setGlobalOptions({region: "us-central1", maxInstances: 10});

/**
 * Sends tripping notification when a new tripping event is created
 * @param {!Object} event - Cloud Function event object
 * @return {Promise<void>} - Promise that resolves when notification is sent
 */
exports.sendTrippingNotification = onDocumentCreated(
    "trippingShutdownEntries/{eventId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        console.log("No data in document");
        return;
      }

      const eventData = snap.data();

      // Only process tripping events
      if (eventData.eventType !== "Tripping") {
        console.log("Not a tripping event, skipping");
        return;
      }

      try {
      // Get bay information to determine voltage level
        const bayDoc = await db.collection("bays").doc(eventData.bayId).get();
        if (!bayDoc.exists) {
          console.log("Bay not found:", eventData.bayId);
          return;
        }

        const bayData = bayDoc.data();
        const voltageLevel = parseVoltageLevel(bayData.voltageLevel);

        console.log(
            `Processing tripping event for bay: ${bayData.name}, ` +
          `voltage: ${voltageLevel}kV`,
        );

        // Get users who should receive notifications
        const eligibleUsers = await getEligibleUsers();
        console.log(`Found ${eligibleUsers.length} eligible users`);

        // Filter users based on their notification preferences
        const recipientTokens = await filterUsersForNotification(
            eventData,
            bayData,
            voltageLevel,
            eligibleUsers,
        );

        if (recipientTokens.length === 0) {
          console.log("No eligible recipients found after filtering");
          return;
        }

        console.log(`Sending notification to ${recipientTokens.length} devices`);

        // Send notification
        const message = {
          notification: {
            title: "⚡ Tripping Event Alert",
            body:
            `${bayData.name} at ${eventData.substationName} ` + "has tripped",
          },
          data: {
            eventId: event.params.eventId,
            eventType: "tripping",
            substationId: eventData.substationId || "",
            substationName: eventData.substationName || "",
            bayId: eventData.bayId || "",
            bayName: bayData.name || "",
            bayType: bayData.bayType || "",
            voltageLevel: bayData.voltageLevel || "",
            startTime: eventData.startTime?.toDate?.()?.toISOString?.() || "",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          tokens: recipientTokens,
        };

        const response = await messaging.sendMulticast(message);
        console.log(`Notification sent to ${response.successCount} devices`);

        // Log failed sends
        if (response.failureCount > 0) {
          const failures = response.responses
              .map((r, index) => ({index, response: r}))
              .filter((item) => !item.response.success);
          console.log("Failed sends:", failures);

          // Clean up invalid tokens
          await cleanupInvalidTokens(failures, recipientTokens);
        }
      } catch (error) {
        console.error("Error sending notification:", error);
      }
    },
);

/**
 * Sends shutdown notification when a new shutdown event is created
 * @param {!Object} event - Cloud Function event object
 * @return {Promise<void>} - Promise that resolves when notification is sent
 */
exports.sendShutdownNotification = onDocumentCreated(
    "trippingShutdownEntries/{eventId}",
    async (event) => {
      const snap = event.data;
      if (!snap) {
        console.log("No data in document");
        return;
      }

      const eventData = snap.data();

      // Only process shutdown events
      if (eventData.eventType !== "Shutdown") {
        return;
      }

      try {
        const bayDoc = await db.collection("bays").doc(eventData.bayId).get();
        if (!bayDoc.exists) {
          console.log("Bay not found:", eventData.bayId);
          return;
        }

        const bayData = bayDoc.data();
        const voltageLevel = parseVoltageLevel(bayData.voltageLevel);

        const eligibleUsers = await getEligibleUsers();
        const recipientTokens = await filterUsersForNotification(
            eventData,
            bayData,
            voltageLevel,
            eligibleUsers,
            "shutdown",
        );

        if (recipientTokens.length === 0) {
          console.log("No eligible recipients found for shutdown notification");
          return;
        }

        const message = {
          notification: {
            title: "🔌 Shutdown Event Alert",
            body:
            `${bayData.name} at ${eventData.substationName} ` +
            "is under shutdown",
          },
          data: {
            eventId: event.params.eventId,
            eventType: "shutdown",
            substationId: eventData.substationId || "",
            substationName: eventData.substationName || "",
            bayId: eventData.bayId || "",
            bayName: bayData.name || "",
            bayType: bayData.bayType || "",
            voltageLevel: bayData.voltageLevel || "",
            startTime: eventData.startTime?.toDate?.()?.toISOString?.() || "",
            shutdownType: eventData.shutdownType || "",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          tokens: recipientTokens,
        };

        const response = await messaging.sendMulticast(message);
        console.log(
            `Shutdown notification sent to ${response.successCount} devices`,
        );

        if (response.failureCount > 0) {
          const failures = response.responses
              .map((r, index) => ({index, response: r}))
              .filter((item) => !item.response.success);
          console.log("Failed shutdown notification sends:", failures);
          await cleanupInvalidTokens(failures, recipientTokens);
        }
      } catch (error) {
        console.error("Error sending shutdown notification:", error);
      }
    },
);

function parseVoltageLevel(voltageString) {
  if (!voltageString) return 0;
  const match = voltageString.match(/(\d+)kV/i);
  return match ? parseInt(match[1], 10) : 0;
}

async function getEligibleUsers() {
  const eligibleRoles = [
    "subdivisionManager",
    "divisionManager",
    "circleManager",
    "zoneManager",
    "executiveEngineer",
    "superintendingEngineer",
    "admin",
  ];

  const usersSnapshot = await db
      .collection("users")
      .where("role", "in", eligibleRoles)
      .get();

  return usersSnapshot.docs.map((doc) => ({
    userId: doc.id,
    ...doc.data(),
  }));
}

async function filterUsersForNotification(
    eventData,
    bayData,
    voltageLevel,
    eligibleUsers,
    notificationType = "tripping",
) {
  const recipientTokens = [];

  for (const user of eligibleUsers) {
    try {
      const preferencesDoc = await db
          .collection("notificationPreferences")
          .doc(user.userId)
          .get();

      let preferences;
      if (preferencesDoc.exists) {
        preferences = preferencesDoc.data();
      } else {
        preferences = {
          subscribedVoltageThresholds: [220, 400],
          subscribedBayTypes: ["all"],
          subscribedSubstations: ["all"],
          enableTrippingNotifications: true,
          enableShutdownNotifications: true,
        };

        await db
            .collection("notificationPreferences")
            .doc(user.userId)
            .set(preferences);
      }

      const notificationEnabled =
        notificationType === "shutdown" ?
          preferences.enableShutdownNotifications :
          preferences.enableTrippingNotifications;

      if (!notificationEnabled) {
        console.log(
            `User ${user.userId} has disabled ${notificationType} notifications`,
        );
        continue;
      }

      if (
        Array.isArray(preferences.subscribedVoltageThresholds) &&
        preferences.subscribedVoltageThresholds.length > 0
      ) {
        const meetsVoltageThreshold =
          preferences.subscribedVoltageThresholds.some(
              (threshold) => voltageLevel >= Number(threshold || 0),
          );
        if (!meetsVoltageThreshold) {
          console.log(
              `User ${user.userId} voltage threshold not met: ${voltageLevel}kV`,
          );
          continue;
        }
      }

      if (
        Array.isArray(preferences.subscribedBayTypes) &&
        !preferences.subscribedBayTypes.includes("all") &&
        !preferences.subscribedBayTypes.includes(bayData.bayType)
      ) {
        console.log(
            `User ${user.userId} bay type not subscribed: ${bayData.bayType}`,
        );
        continue;
      }

      if (
        Array.isArray(preferences.subscribedSubstations) &&
        !preferences.subscribedSubstations.includes("all") &&
        !preferences.subscribedSubstations.includes(eventData.substationId)
      ) {
        console.log(
            `User ${user.userId} substation not subscribed: ${eventData.substationId}`,
        );
        continue;
      }

      const tokensSnapshot = await db
          .collection("fcmTokens")
          .where("userId", "==", user.userId)
          .where("active", "==", true)
          .get();

      const userTokens = [];
      tokensSnapshot.docs.forEach((tokenDoc) => {
        const tokenData = tokenDoc.data();
        if (tokenData.token) {
          userTokens.push(tokenData.token);
          recipientTokens.push(tokenData.token);
        }
      });

      console.log(`User ${user.userId} has ${userTokens.length} active tokens`);
    } catch (error) {
      console.error(`Error processing user ${user.userId}:`, error);
    }
  }

  return recipientTokens;
}

async function cleanupInvalidTokens(failures, originalTokens) {
  const invalidTokens = failures
      .filter(
          (failure) =>
            failure.response.error?.code ===
          "messaging/registration-token-not-registered" ||
        failure.response.error?.code === "messaging/invalid-registration-token",
      )
      .map((failure) => originalTokens[failure.index]);

  if (invalidTokens.length > 0) {
    console.log(`Cleaning up ${invalidTokens.length} invalid tokens`);

    const batch = db.batch();
    for (const token of invalidTokens) {
      const tokenQuery = await db
          .collection("fcmTokens")
          .where("token", "==", token)
          .limit(1)
          .get();

      tokenQuery.docs.forEach((doc) => {
        batch.update(doc.ref, {
          active: false,
          deactivatedAt: new Date(),
        });
      });
    }

    await batch.commit();
    console.log("Invalid tokens marked as inactive");
  }
}
