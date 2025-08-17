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
 * Format timestamp to IST (Indian Standard Time)
 */
function formatTime(timestamp) {
  if (!timestamp) return "N/A";

  let date;
  if (timestamp.toDate) {
    date = timestamp.toDate();
  } else if (timestamp instanceof Date) {
    date = timestamp;
  } else {
    return "N/A";
  }

  // Convert to IST and format
  const istString = date.toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });

  // Parse and reformat to match desired format: "HH:MM, DD MMM YYYY"
  const [datePart, timePart] = istString.split(", ");
  const [day, month, year] = datePart.split(" ");

  return `${timePart}, ${day} ${month} ${year}`;
}

/**
 * MISSING FUNCTION 2: Calculate duration between start and end time
 */
function calculateEventDuration(startTime, endTime) {
  if (!startTime || !endTime) return "";

  let start = startTime.toDate ? startTime.toDate() : new Date(startTime);
  let end = endTime.toDate ? endTime.toDate() : new Date(endTime);

  const diffMs = end - start;
  const minutes = Math.floor(diffMs / (1000 * 60));

  if (minutes < 60) {
    return `${minutes}m`;
  } else {
    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;
    return `${hours}h ${remainingMinutes}m`;
  }
}

/**
 * Enhanced message formatting with icons only (no images)
 */
function formatNotificationMessage(eventData, bayData, status) {
  const assetName = bayData.name;
  const substationName = eventData.substationName || "Unknown Substation";
  const cause =
    eventData.flagsCause && eventData.flagsCause.trim()
      ? eventData.flagsCause.trim()
      : null;
  const flag = eventData.reasonForNonFeeder || "N/A";

  let title = "";
  let bodyLines = [];

  if (status === "closed") {
    // CLOSED EVENT
    title = `✅ ${eventData.eventType} Restored: ${assetName}`;

    bodyLines.push(`📍 Substation: ${substationName}`);
    bodyLines.push(`🕐 Close Time: ${formatTime(eventData.endTime)}`);
    bodyLines.push(`🚩 Flag: ${flag}`);

    if (cause) {
      bodyLines.push(`❗ Cause: ${cause}`);
    }

    // Add shutdown person details for shutdown events
    if (eventData.eventType === "Shutdown") {
      if (eventData.shutdownPersonName) {
        bodyLines.push(`👤 Person: ${eventData.shutdownPersonName}`);
      }
      if (eventData.shutdownPersonDesignation) {
        bodyLines.push(
          `💼 Designation: ${eventData.shutdownPersonDesignation}`
        );
      }
    }

    // Add duration
    const duration = calculateEventDuration(
      eventData.startTime,
      eventData.endTime
    );
    if (duration) {
      bodyLines.push(`⏱️ Duration: ${duration}`);
    }
  } else {
    // OPEN EVENT
    const emoji = eventData.eventType === "Tripping" ? "⚡" : "🔌";
    title = `${emoji} ${eventData.eventType}: ${assetName}`;

    const timeLabel =
      eventData.eventType === "Tripping" ? "Trip Time" : "Start Time";
    bodyLines.push(`📍 Substation: ${substationName}`);
    bodyLines.push(`🕐 ${timeLabel}: ${formatTime(eventData.startTime)}`);
    bodyLines.push(`🚩 Flag: ${flag}`);

    if (cause) {
      bodyLines.push(`❗ Cause: ${cause}`);
    }

    // Add shutdown person details for shutdown events
    if (eventData.eventType === "Shutdown") {
      if (eventData.shutdownPersonName) {
        bodyLines.push(`👤 Person: ${eventData.shutdownPersonName}`);
      }
      if (eventData.shutdownPersonDesignation) {
        bodyLines.push(
          `💼 Designation: ${eventData.shutdownPersonDesignation}`
        );
      }
    }

    // Add phase faults for tripping
    if (
      eventData.eventType === "Tripping" &&
      eventData.phaseFaults &&
      eventData.phaseFaults.length > 0
    ) {
      bodyLines.push(`⚡ Phases: ${eventData.phaseFaults.join(", ")}`);
    }

    // Add distance for line tripping
    if (eventData.eventType === "Tripping" && eventData.distance) {
      bodyLines.push(`📏 Distance: ${eventData.distance} km`);
    }

    // Add auto-reclose info for high voltage lines
    if (
      eventData.eventType === "Tripping" &&
      eventData.hasAutoReclose === true
    ) {
      bodyLines.push(`🔄 Auto-reclose: Yes`);
    }
  }

  return {
    title,
    body: bodyLines.join("\n"),
  };
}

/**
 * Complete enhanced notification logic - Icons only
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
    `Processing ${eventData.eventType} ${status} for bay: ${bayData.name} at ${eventData.substationName}, bayType: ${bayType}, voltage: ${voltageLevel}kV`
  );

  // User hierarchy query
  const eligibleUsers = await getEligibleUsersForSubstation(
    eventData.substationId
  );

  // User filtering based on preferences
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

  // Enhanced professional messaging with icons only
  const { title, body } = formatNotificationMessage(eventData, bayData, status);

  const message = {
    notification: {
      title,
      body,
      // Removed icon and badge properties - using emojis only
    },
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
      endTime: eventData.endTime?.toDate?.()?.toISOString?.() || "",
      status,
      flagsCause: eventData.flagsCause || "",
      reasonForNonFeeder: eventData.reasonForNonFeeder || "",
      hasAutoReclose: eventData.hasAutoReclose?.toString() || "",
      phaseFaults: eventData.phaseFaults
        ? JSON.stringify(eventData.phaseFaults)
        : "",
      distance: eventData.distance || "",
      shutdownType: eventData.shutdownType || "",
      shutdownPersonName: eventData.shutdownPersonName || "",
      shutdownPersonDesignation: eventData.shutdownPersonDesignation || "",
      timestamp: new Date().toISOString(),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: eventData.eventType === "Tripping" ? "high" : "normal",
      notification: {
        channelId: getNotificationChannel(eventData.eventType, status),
        color: getNotificationColor(eventData.eventType, status),
        sound: eventData.eventType === "Tripping" ? "alert.wav" : "default",
        // Removed icon property - using emojis in title/body
      },
    },
    apns: {
      payload: {
        aps: {
          category: getNotificationChannel(eventData.eventType, status),
          sound: eventData.eventType === "Tripping" ? "alert.wav" : "default",
        },
      },
    },
  };

  // Individual sends to avoid batch errors
  let successCount = 0;
  let failureCount = 0;

  for (let i = 0; i < recipientTokens.length; i++) {
    try {
      const individualMessage = {
        notification: message.notification,
        data: message.data,
        android: message.android,
        apns: message.apns,
        token: recipientTokens[i],
      };

      const response = await messaging.send(individualMessage);
      successCount++;
      console.log(
        `✅ Sent to token ${i + 1}/${recipientTokens.length}: ${recipientTokens[
          i
        ].substring(0, 20)}...`
      );
    } catch (error) {
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
}

// Utility functions
function getNotificationColor(eventType, status) {
  if (status === "closed") return "#00C851"; // Green
  return eventType === "Tripping" ? "#FF3547" : "#FF8800"; // Red/Orange
}

function getNotificationChannel(eventType, status) {
  if (status === "closed") return "status_update";
  return eventType === "Tripping" ? "emergency" : "maintenance";
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
    const eventData = event.data.data();
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

// ... [Rest of your existing functions: getEligibleUsersForSubstation, parseVoltageLevel, filterUsersForNotification, cleanupInvalidTokens remain exactly the same] ...

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
