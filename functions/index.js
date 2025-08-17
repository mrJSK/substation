/**
 * @fileoverview Firebase Cloud Functions for notification system
 */

const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// Set global options (optional)
setGlobalOptions({ region: "us-central1", maxInstances: 10 });

/**
 * Notification logic for open/close tripping or shutdown events
 * Handles both line/transformer default and user preferences
 */
async function sendEventNotification(eventData, eventId, status) {
  const bayDoc = await db.collection("bays").doc(eventData.bayId).get();
  if (!bayDoc.exists) {
    console.log("Bay not found:", eventData.bayId);
    return;
  }
  const bayData = bayDoc.data();
  const voltageLevel = parseVoltageLevel(bayData.voltageLevel);
  const bayType = (bayData.bayType || "").toLowerCase();

  console.log(
    `Processing ${eventData.eventType} ${status} for bay: ${bayData.name}, bayType: ${bayType}, voltage: ${voltageLevel}kV`
  );

  // User hierarchy query
  const eligibleUsers = await getEligibleUsersForSubstation(
    eventData.substationId
  );

  // User filtering based on preferences and critical bay type
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
  // Notification title/body
  let title = "";
  let body = "";
  if (status === "closed") {
    title = `✅ ${eventData.eventType} Event Closed`;
    body = `${bayData.name} at ${eventData.substationName} - ${voltageLevel}kV (Resolved)`;
  } else {
    title =
      eventData.eventType === "Tripping"
        ? `⚡ Tripping Alert`
        : `🔌 Shutdown Alert`;
    body = `${bayData.name} at ${eventData.substationName} - ${voltageLevel}kV`;
  }
  const message = {
    notification: { title, body },
    data: {
      eventId,
      eventType: eventData.eventType.toLowerCase(),
      substationId: eventData.substationId || "",
      substationName: eventData.substationName || "",
      bayId: eventData.bayId || "",
      bayName: bayData.name || "",
      bayType: bayData.bayType || "",
      voltageLevel: bayData.voltageLevel || "",
      startTime: eventData.startTime?.toDate?.()?.toISOString?.() || "",
      status, // open/closed
      shutdownType: eventData.shutdownType || "",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
  };

  // ✅ FIXED: Individual sends to avoid /batch endpoint error
  const responses = [];
  let successCount = 0;
  let failureCount = 0;

  for (let i = 0; i < recipientTokens.length; i++) {
    try {
      const individualMessage = {
        notification: message.notification,
        data: message.data,
        token: recipientTokens[i], // Send to individual token
      };

      const response = await messaging.send(individualMessage);
      responses.push({ success: true, messageId: response, index: i });
      successCount++;
      console.log(
        `✅ Sent to token ${i + 1}/${recipientTokens.length}: ${recipientTokens[
          i
        ].substring(0, 20)}...`
      );
    } catch (error) {
      responses.push({ success: false, error, index: i, response: { error } });
      failureCount++;
      console.log(
        `❌ Failed to send to token ${i + 1}/${recipientTokens.length}:`,
        error.code || error.message
      );
    }
  }

  console.log(
    `✅ Notification sent to ${successCount} devices (${failureCount} failed)`
  );

  // Handle failures if any
  if (failureCount > 0) {
    const failures = responses.filter((r) => !r.success);
    console.log("Failed sends:", failures.length);
    await cleanupInvalidTokens(failures, recipientTokens);
  }
}

/**
 * Trigger for event OPEN (creation)
 */
exports.sendEventOpenedNotification = onDocumentCreated(
  "trippingShutdownEntries/{eventId}",
  async (event) => {
    if (!event.data) {
      console.log("No data in document");
      return;
    }
    const eventData = event.data.data(); // ✅ FIXED: event.data is DocumentSnapshot
    // Tripping or Shutdown only
    if (
      eventData.eventType !== "Tripping" &&
      eventData.eventType !== "Shutdown"
    )
      return;
    await sendEventNotification(eventData, event.params.eventId, "open");
  }
);

/**
 * Trigger for event CLOSE (status update)
 * ----> UPDATED FOR CLOUD FUNCTIONS V2 <----
 */
exports.sendEventClosedNotification = onDocumentUpdated(
  "trippingShutdownEntries/{eventId}",
  async (event) => {
    // V2: 'event' parameter, not 'change'
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!before || !after) {
      console.log("Invalid document state");
      return;
    }

    // Only notify when status changes from OPEN to CLOSED
    if (before.status !== "OPEN" || after.status !== "CLOSED") return;
    if (after.eventType !== "Tripping" && after.eventType !== "Shutdown")
      return;
    await sendEventNotification(after, event.data.after.id, "closed");
  }
);

/**
 * Hierarchical user fetch for targeting notifications
 */
async function getEligibleUsersForSubstation(substationId) {
  try {
    const substationDoc = await db
      .collection("substations")
      .doc(substationId)
      .get();
    if (!substationDoc.exists) return [];
    const substationData = substationDoc.data();
    const subdivisionId = substationData.subdivisionId;
    if (!subdivisionId) return [];
    const subdivisionDoc = await db
      .collection("subdivisions")
      .doc(subdivisionId)
      .get();
    if (!subdivisionDoc.exists) return [];
    const subdivisionData = subdivisionDoc.data();
    const divisionId = subdivisionData.divisionId;
    // Fetch hierarchy IDs
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
    // Build eligible user list
    const eligibleUsers = [];
    // Subdivision managers
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
    // Division managers
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
    // Circle managers
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
    // Zone managers
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
    // Admin users
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
    return eligibleUsers;
  } catch (error) {
    console.error("Error getting eligible users:", error);
    return [];
  }
}

/**
 * Basic voltage parsing utility
 */
function parseVoltageLevel(voltageString) {
  if (!voltageString) return 0;
  const match = voltageString.match(/(\d+)kV/i);
  return match ? parseInt(match[1], 10) : 0;
}

/**
 * Preference-aware user filtering
 * - Users are by default subscribed only to "Line" and "Transformer" (see below)
 * - If a user disables either via their preferences, no notification is sent for that bay type
 * - Other bay types strictly require explicit subscription
 */
async function filterUsersForNotification(
  eventData,
  bayData,
  voltageLevel,
  eligibleUsers,
  notificationType
) {
  console.log(`🔍 FILTERING DEBUG START`);
  console.log(
    `🔍 Event: ${eventData.eventType}, Bay: ${bayData.bayType}, Voltage: ${voltageLevel}kV`
  );
  console.log(`🔍 Eligible users count: ${eligibleUsers.length}`);

  const recipientTokens = [];
  const bayType = (bayData.bayType || "").toLowerCase();

  for (const user of eligibleUsers) {
    console.log(`\n🔍 Processing user: ${user.userId}, Role: ${user.role}`);

    try {
      // Get user's notification preferences
      const preferencesDoc = await db
        .collection("notificationPreferences")
        .doc(user.userId)
        .get();

      let preferences;
      if (preferencesDoc.exists) {
        preferences = preferencesDoc.data();
        console.log(`🔍 Found existing preferences for ${user.userId}`);
      } else {
        // Defaults: Only "Line" and "Transformer"
        preferences = {
          subscribedVoltageThresholds: [132, 220, 400, 765],
          optionalVoltageThresholds: [11, 33, 66, 110],
          enabledOptionalVoltages: [],
          subscribedBayTypes: ["Line", "Transformer"],
          subscribedSubstations: ["all"],
          enableTrippingNotifications: true,
          enableShutdownNotifications: true,
        };
        await db
          .collection("notificationPreferences")
          .doc(user.userId)
          .set(preferences);
        console.log(`🔍 Created default preferences for ${user.userId}`);
      }

      // 1. Check notification enabled
      const notificationEnabled =
        notificationType === "shutdown"
          ? preferences.enableShutdownNotifications
          : preferences.enableTrippingNotifications;
      console.log(
        `🔍 Notification enabled (${notificationType}): ${notificationEnabled}`
      );
      if (!notificationEnabled) {
        console.log(
          `❌ User ${user.userId} has disabled ${notificationType} notifications`
        );
        continue;
      }

      // 2. Check voltage threshold
      const allSubscribedVoltages = Array.isArray(
        preferences.subscribedVoltageThresholds
      )
        ? [...preferences.subscribedVoltageThresholds]
        : [];
      if (Array.isArray(preferences.enabledOptionalVoltages))
        preferences.enabledOptionalVoltages.forEach((v) => {
          if (!allSubscribedVoltages.includes(v)) allSubscribedVoltages.push(v);
        });
      const meetsVoltageThreshold = allSubscribedVoltages.some(
        (threshold) => voltageLevel >= Number(threshold || 0)
      );
      console.log(
        `🔍 Voltage check: ${voltageLevel}kV >= ${allSubscribedVoltages}: ${meetsVoltageThreshold}`
      );
      if (!meetsVoltageThreshold) {
        console.log(`❌ User ${user.userId} voltage threshold not met`);
        continue;
      }

      // 3. Check bay type
      let bayTypes = Array.isArray(preferences.subscribedBayTypes)
        ? preferences.subscribedBayTypes.map((x) => x.toLowerCase())
        : [];
      console.log(`🔍 User bay types: ${bayTypes}, Event bay type: ${bayType}`);
      if (bayTypes.includes("all") || bayTypes.includes(bayType)) {
        console.log(`✅ Bay type match found`);
      } else {
        console.log(
          `❌ User ${user.userId} not subscribed to bay type: ${bayType}`
        );
        continue;
      }

      // 4. Check substation
      if (
        Array.isArray(preferences.subscribedSubstations) &&
        !preferences.subscribedSubstations.includes("all") &&
        !preferences.subscribedSubstations.includes(eventData.substationId)
      ) {
        console.log(
          `❌ User ${user.userId} not subscribed to substation: ${eventData.substationId}`
        );
        continue;
      }

      // 5. Get FCM tokens
      console.log(`🔍 Checking FCM tokens for user: ${user.userId}`);
      const tokenDoc = await db.collection("fcmTokens").doc(user.userId).get();
      if (tokenDoc.exists) {
        const data = tokenDoc.data();
        console.log(
          `🔍 Token exists - Active: ${data.active}, Has Token: ${!!data.token}`
        );
        if (data.active && data.token) {
          recipientTokens.push(data.token);
          console.log(
            `✅ Added token for user ${user.userId}: ${data.token.substring(
              0,
              20
            )}...`
          );
        } else {
          console.log(`❌ Token inactive or missing for user ${user.userId}`);
        }
      } else {
        console.log(`❌ No FCM token document found for user ${user.userId}`);
      }
    } catch (error) {
      console.error(`❌ Error processing user ${user.userId}:`, error);
    }
  }

  console.log(`🔍 FILTERING COMPLETE: Found ${recipientTokens.length} tokens`);
  return recipientTokens;
}

/**
 * Mark failed tokens as inactive
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
    const batch = db.batch();
    for (const token of invalidTokens) {
      const tokenQuery = await db
        .collection("fcmTokens")
        .where("token", "==", token)
        .limit(1)
        .get();
      tokenQuery.docs.forEach((doc) => {
        batch.update(doc.ref, { active: false, deactivatedAt: new Date() });
      });
    }
    await batch.commit();
    console.log("Invalid tokens marked as inactive");
  }
}
