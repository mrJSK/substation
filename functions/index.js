/**
 * @fileoverview Firebase Cloud Functions for notification system
 */

const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// Set global options (optional)
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

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
        `Processing ${eventData.eventType} event for bay: ${bayData.name}, ` +
          `voltage: ${voltageLevel}kV at substation: ${eventData.substationId}`
      );

      // Get hierarchically eligible users for this specific substation
      const eligibleUsers = await getEligibleUsersForSubstation(
        eventData.substationId
      );
      console.log(`Found ${eligibleUsers.length} eligible users in hierarchy`);

      // Filter users based on their notification preferences
      const recipientTokens = await filterUsersForNotification(
        eventData,
        bayData,
        voltageLevel,
        eligibleUsers,
        eventData.eventType.toLowerCase()
      );

      if (recipientTokens.length === 0) {
        console.log("No eligible recipients found after filtering");
        return;
      }

      console.log(`Sending notification to ${recipientTokens.length} devices`);

      // Send notification
      const message = {
        notification: {
          title: `⚡ ${eventData.eventType} Alert`,
          body: `${bayData.name} at ${eventData.substationName} - ${voltageLevel}kV`,
        },
        data: {
          eventId: event.params.eventId,
          eventType: eventData.eventType.toLowerCase(),
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
      console.log(`✅ Notification sent to ${response.successCount} devices`);

      if (response.failureCount > 0) {
        const failures = response.responses
          .map((r, index) => ({ index, response: r }))
          .filter((item) => !item.response.success);
        console.log("Failed sends:", failures);
        await cleanupInvalidTokens(failures, recipientTokens);
      }
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  }
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

      console.log(
        `Processing shutdown event for bay: ${bayData.name}, ` +
          `voltage: ${voltageLevel}kV at substation: ${eventData.substationId}`
      );

      // Get hierarchically eligible users for this specific substation
      const eligibleUsers = await getEligibleUsersForSubstation(
        eventData.substationId
      );
      const recipientTokens = await filterUsersForNotification(
        eventData,
        bayData,
        voltageLevel,
        eligibleUsers,
        "shutdown"
      );

      if (recipientTokens.length === 0) {
        console.log("No eligible recipients found for shutdown notification");
        return;
      }

      console.log(
        `Sending shutdown notification to ${recipientTokens.length} devices`
      );

      const message = {
        notification: {
          title: "🔌 Shutdown Event Alert",
          body: `${bayData.name} at ${eventData.substationName} - ${voltageLevel}kV`,
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
        `Shutdown notification sent to ${response.successCount} devices`
      );

      if (response.failureCount > 0) {
        const failures = response.responses
          .map((r, index) => ({ index, response: r }))
          .filter((item) => !item.response.success);
        console.log("Failed shutdown notification sends:", failures);
        await cleanupInvalidTokens(failures, recipientTokens);
      }
    } catch (error) {
      console.error("Error sending shutdown notification:", error);
    }
  }
);

/**
 * Get all eligible users in the hierarchy for a specific substation
 * @param {string} substationId - The substation ID where the event occurred
 * @return {Promise<Array>} - Array of eligible users with their hierarchy info
 */
async function getEligibleUsersForSubstation(substationId) {
  try {
    // Get the substation details first
    const substationDoc = await db
      .collection("substations")
      .doc(substationId)
      .get();
    if (!substationDoc.exists) {
      console.log(`Substation ${substationId} not found`);
      return [];
    }

    const substationData = substationDoc.data();
    const subdivisionId = substationData.subdivisionId;

    if (!subdivisionId) {
      console.log(`No subdivision found for substation ${substationId}`);
      return [];
    }

    // Get subdivision details
    const subdivisionDoc = await db
      .collection("subdivisions")
      .doc(subdivisionId)
      .get();
    if (!subdivisionDoc.exists) {
      console.log(`Subdivision ${subdivisionId} not found`);
      return [];
    }

    const subdivisionData = subdivisionDoc.data();
    const divisionId = subdivisionData.divisionId;

    // Get division details
    let circleId = null;
    let zoneId = null;

    if (divisionId) {
      const divisionDoc = await db
        .collection("divisions")
        .doc(divisionId)
        .get();
      if (divisionDoc.exists) {
        const divisionData = divisionDoc.data();
        circleId = divisionData.circleId;

        if (circleId) {
          const circleDoc = await db.collection("circles").doc(circleId).get();
          if (circleDoc.exists) {
            const circleData = circleDoc.data();
            zoneId = circleData.zoneId;
          }
        }
      }
    }

    console.log(
      `Hierarchy for substation ${substationId}: Zone=${zoneId}, Circle=${circleId}, Division=${divisionId}, Subdivision=${subdivisionId}`
    );

    // Build queries for eligible users at each level
    const eligibleUsers = [];

    // 1. Subdivision managers for this subdivision
    const subdivisionManagers = await db
      .collection("users")
      .where("role", "==", "subdivisionManager")
      .where("assignedLevels.subdivisionId", "==", subdivisionId)
      .get();

    subdivisionManagers.docs.forEach((doc) => {
      eligibleUsers.push({
        userId: doc.id,
        role: "subdivisionManager",
        level: "subdivision",
        ...doc.data(),
      });
    });

    // 2. Division managers for this division
    if (divisionId) {
      const divisionManagers = await db
        .collection("users")
        .where("role", "==", "divisionManager")
        .where("assignedLevels.divisionId", "==", divisionId)
        .get();

      divisionManagers.docs.forEach((doc) => {
        eligibleUsers.push({
          userId: doc.id,
          role: "divisionManager",
          level: "division",
          ...doc.data(),
        });
      });
    }

    // 3. Circle managers for this circle
    if (circleId) {
      const circleManagers = await db
        .collection("users")
        .where("role", "==", "circleManager")
        .where("assignedLevels.circleId", "==", circleId)
        .get();

      circleManagers.docs.forEach((doc) => {
        eligibleUsers.push({
          userId: doc.id,
          role: "circleManager",
          level: "circle",
          ...doc.data(),
        });
      });
    }

    // 4. Zone managers for this zone
    if (zoneId) {
      const zoneManagers = await db
        .collection("users")
        .where("role", "==", "zoneManager")
        .where("assignedLevels.zoneId", "==", zoneId)
        .get();

      zoneManagers.docs.forEach((doc) => {
        eligibleUsers.push({
          userId: doc.id,
          role: "zoneManager",
          level: "zone",
          ...doc.data(),
        });
      });
    }

    // 5. Admin users (get notifications for everything)
    const adminUsers = await db
      .collection("users")
      .where("role", "==", "admin")
      .get();

    adminUsers.docs.forEach((doc) => {
      eligibleUsers.push({
        userId: doc.id,
        role: "admin",
        level: "admin",
        ...doc.data(),
      });
    });

    console.log(
      `Found ${eligibleUsers.length} eligible users across all hierarchy levels`
    );
    return eligibleUsers;
  } catch (error) {
    console.error("Error getting eligible users:", error);
    return [];
  }
}

/**
 * Parse voltage level from string format (e.g., "132kV" -> 132)
 * @param {string} voltageString - Voltage string to parse
 * @return {number} - Parsed voltage level as number
 */
function parseVoltageLevel(voltageString) {
  if (!voltageString) return 0;
  const match = voltageString.match(/(\d+)kV/i);
  return match ? parseInt(match[1], 10) : 0;
}

/**
 * Filter users based on their notification preferences and hierarchy
 * @param {Object} eventData - Event data from the document
 * @param {Object} bayData - Bay information
 * @param {number} voltageLevel - Voltage level as number
 * @param {Array} eligibleUsers - Array of eligible users from hierarchy
 * @param {string} notificationType - Type of notification (tripping/shutdown)
 * @return {Promise<Array>} - Array of FCM tokens to send notifications to
 */
async function filterUsersForNotification(
  eventData,
  bayData,
  voltageLevel,
  eligibleUsers,
  notificationType = "tripping"
) {
  const recipientTokens = [];

  for (const user of eligibleUsers) {
    try {
      console.log(
        `Processing ${user.role} user ${user.userId} at ${user.level} level`
      );

      // Get user's notification preferences
      const preferencesDoc = await db
        .collection("notificationPreferences")
        .doc(user.userId)
        .get();

      let preferences;
      if (preferencesDoc.exists) {
        preferences = preferencesDoc.data();
      } else {
        // UPDATED: Default preferences with your specified requirements
        preferences = {
          // Default mandatory voltages: 132, 220, 400, 765 kV
          subscribedVoltageThresholds: [132, 220, 400, 765],

          // Optional voltages (not subscribed by default): 11, 33, 66, 110 kV
          optionalVoltageThresholds: [11, 33, 66, 110],

          // All bay types by default (includes Transformer, Line, and others)
          subscribedBayTypes: ["all"], // This covers "Transformer", "Line", "Bus", "Reactor", etc.

          // All substations under their hierarchy by default
          subscribedSubstations: ["all"],

          // Both notification types enabled by default
          enableTrippingNotifications: true,
          enableShutdownNotifications: true,
        };

        await db
          .collection("notificationPreferences")
          .doc(user.userId)
          .set(preferences);

        console.log(
          `Created default preferences for user ${user.userId} with role ${user.role}:`
        );
        console.log(`- Default voltages: 132, 220, 400, 765 kV`);
        console.log(
          `- Optional voltages: 11, 33, 66, 110 kV (not subscribed by default)`
        );
        console.log(`- All bay types (Transformer, Line, etc.)`);
        console.log(`- All substations under their hierarchy`);
      }

      // Check if notifications are enabled for this event type
      const notificationEnabled =
        notificationType === "shutdown"
          ? preferences.enableShutdownNotifications
          : preferences.enableTrippingNotifications;

      if (!notificationEnabled) {
        console.log(
          `User ${user.userId} has disabled ${notificationType} notifications`
        );
        continue;
      }

      // Check voltage threshold - now includes both subscribed and optional if user opted in
      if (
        Array.isArray(preferences.subscribedVoltageThresholds) &&
        preferences.subscribedVoltageThresholds.length > 0
      ) {
        // Combine subscribed voltages with any optional voltages the user has enabled
        const allSubscribedVoltages = [
          ...preferences.subscribedVoltageThresholds,
        ];

        // If user has opted into optional voltages, include them
        if (Array.isArray(preferences.optionalVoltageThresholds)) {
          // Check if user has specifically enabled optional voltages
          const enabledOptionalVoltages =
            preferences.enabledOptionalVoltages || [];
          enabledOptionalVoltages.forEach((voltage) => {
            if (
              preferences.optionalVoltageThresholds.includes(voltage) &&
              !allSubscribedVoltages.includes(voltage)
            ) {
              allSubscribedVoltages.push(voltage);
            }
          });
        }

        const meetsVoltageThreshold = allSubscribedVoltages.some(
          (threshold) => voltageLevel >= Number(threshold || 0)
        );

        if (!meetsVoltageThreshold) {
          console.log(
            `User ${user.userId} voltage threshold not met: ${voltageLevel}kV (subscribed to: ${allSubscribedVoltages})`
          );
          continue;
        }
      }

      // Check bay type subscription
      if (
        Array.isArray(preferences.subscribedBayTypes) &&
        !preferences.subscribedBayTypes.includes("all")
      ) {
        // Check if the specific bay type is subscribed
        const bayTypeMatch = preferences.subscribedBayTypes.some(
          (subscribedType) =>
            subscribedType.toLowerCase() === bayData.bayType.toLowerCase()
        );

        if (!bayTypeMatch) {
          console.log(
            `User ${user.userId} bay type not subscribed: ${bayData.bayType} (subscribed to: ${preferences.subscribedBayTypes})`
          );
          continue;
        }
      }

      // Check substation subscription
      if (
        Array.isArray(preferences.subscribedSubstations) &&
        !preferences.subscribedSubstations.includes("all") &&
        !preferences.subscribedSubstations.includes(eventData.substationId)
      ) {
        console.log(
          `User ${user.userId} substation not subscribed: ${eventData.substationId}`
        );
        continue;
      }

      // Get user's FCM tokens
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

      console.log(
        `✅ User ${user.userId} (${user.role}) qualified: ${userTokens.length} active tokens`
      );
    } catch (error) {
      console.error(`Error processing user ${user.userId}:`, error);
    }
  }

  return recipientTokens;
}

/**
 * Clean up invalid FCM tokens by marking them as inactive
 * @param {Array} failures - Array of failed message attempts
 * @param {Array} originalTokens - Original array of tokens used
 * @return {Promise<void>} - Promise that resolves when cleanup is complete
 */
async function cleanupInvalidTokens(failures, originalTokens) {
  const invalidTokens = failures
    .filter(
      (failure) =>
        failure.response.error?.code ===
          "messaging/registration-token-not-registered" ||
        failure.response.error?.code === "messaging/invalid-registration-token"
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
