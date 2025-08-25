const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

setGlobalOptions({ region: "us-central1", maxInstances: 10 });

let preferencesCache = new Map();
let tokenCache = new Map();
let cacheTimestamp = 0;
const CACHE_DURATION = 5 * 60 * 1000;

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

  const istString = date.toLocaleString("en-IN", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });

  const [datePart, timePart] = istString.split(", ");
  const [day, month, year] = datePart.split(" ");

  return `${timePart}, ${day} ${month} ${year}`;
}

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
    const restoredText =
      eventData.eventType === "Breakdown" ? "Fixed" : "Restored";
    title = `✅ ${eventData.eventType} ${restoredText}: ${assetName}`;

    bodyLines.push(`📍 Substation: ${substationName}`);

    const closeTimeLabel =
      eventData.eventType === "Breakdown" ? "Fix Time" : "Close Time";
    bodyLines.push(`🕐 ${closeTimeLabel}: ${formatTime(eventData.endTime)}`);
    bodyLines.push(`🚩 Flag: ${flag}`);

    if (cause) {
      bodyLines.push(`❗ Cause: ${cause}`);
    }

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

    const duration = calculateEventDuration(
      eventData.startTime,
      eventData.endTime
    );
    if (duration) {
      const durationLabel =
        eventData.eventType === "Breakdown" ? "Repair Duration" : "Duration";
      bodyLines.push(`⏱️ ${durationLabel}: ${duration}`);
    }
  } else {
    let emoji = "⚡";
    if (eventData.eventType === "Shutdown") {
      emoji = "🔌";
    } else if (eventData.eventType === "Breakdown") {
      emoji = "🔧";
    }

    title = `${emoji} ${eventData.eventType}: ${assetName}`;

    let timeLabel = "Start Time";
    if (eventData.eventType === "Tripping") {
      timeLabel = "Trip Time";
    } else if (eventData.eventType === "Breakdown") {
      timeLabel = "Breakdown Time";
    }

    bodyLines.push(`📍 Substation: ${substationName}`);
    bodyLines.push(`🕐 ${timeLabel}: ${formatTime(eventData.startTime)}`);
    bodyLines.push(`🚩 Flag: ${flag}`);

    if (cause) {
      bodyLines.push(`❗ Cause: ${cause}`);
    }

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

    if (
      (eventData.eventType === "Tripping" ||
        eventData.eventType === "Breakdown") &&
      eventData.phaseFaults &&
      eventData.phaseFaults.length > 0
    ) {
      bodyLines.push(`⚡ Phases: ${eventData.phaseFaults.join(", ")}`);
    }

    if (
      (eventData.eventType === "Tripping" ||
        eventData.eventType === "Breakdown") &&
      eventData.distance
    ) {
      bodyLines.push(`📏 Distance: ${eventData.distance} km`);
    }

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

async function sendEventNotification(eventData, eventId, status) {
  try {
    const bayDoc = await db.collection("bays").doc(eventData.bayId).get();
    if (!bayDoc.exists) {
      console.log("Bay not found:", eventData.bayId);
      return;
    }

    const bayData = bayDoc.data();
    const voltageLevel = parseVoltageLevel(bayData.voltageLevel);
    const bayType = (bayData.bayType || "").toLowerCase();

    console.log(
      `Processing ${eventData.eventType} ${status} for bay: ${bayData.name} at ${eventData.substationName}`
    );

    const recipientTokens = await getOptimizedRecipientsForNotification(
      eventData.substationId,
      eventData.eventType.toLowerCase(),
      voltageLevel,
      bayType,
      eventId
    );

    if (recipientTokens.length === 0) {
      console.log("No eligible recipients found after filtering");
      return;
    }

    console.log(`Sending notification to ${recipientTokens.length} devices`);

    const { title, body } = formatNotificationMessage(
      eventData,
      bayData,
      status
    );

    const message = {
      notification: {
        title,
        body,
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
        navigation_target: "event_details",
      },
      android: {
        priority: getNotificationPriority(eventData.eventType),
        notification: {
          channelId: getNotificationChannel(eventData.eventType, status),
          color: getNotificationColor(eventData.eventType, status),
          sound: getNotificationSound(eventData.eventType),
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            category: getNotificationChannel(eventData.eventType, status),
            sound: getNotificationSound(eventData.eventType),
          },
        },
      },
    };

    const batches = [];
    for (let i = 0; i < recipientTokens.length; i += 500) {
      batches.push(recipientTokens.slice(i, i + 500));
    }

    let totalSuccess = 0;
    let totalFailure = 0;

    const batchPromises = batches.map(async (batch, index) => {
      try {
        const multicastMessage = {
          ...message,
          tokens: batch,
        };

        const response = await messaging.sendMulticast(multicastMessage);
        totalSuccess += response.successCount;
        totalFailure += response.failureCount;

        console.log(
          `✅ Batch ${index + 1}: ${response.successCount}/${
            batch.length
          } sent successfully`
        );

        if (response.failureCount > 0) {
          await cleanupInvalidTokensBatch(response.responses, batch);
        }

        return {
          success: response.successCount,
          failure: response.failureCount,
        };
      } catch (error) {
        console.error(`❌ Batch ${index + 1} failed:`, error);
        totalFailure += batch.length;
        return { success: 0, failure: batch.length };
      }
    });

    await Promise.all(batchPromises);

    console.log(
      `🎯 TOTAL NOTIFICATION RESULT: ${totalSuccess} successful, ${totalFailure} failed`
    );
  } catch (error) {
    console.error("❌ Error in sendEventNotification:", error);
  }
}

async function getOptimizedRecipientsForNotification(
  substationId,
  eventType,
  voltageLevel,
  bayType,
  eventId
) {
  try {
    console.log(
      `🚀 Starting optimized recipient filtering for event ${eventId}`
    );

    const now = Date.now();
    const isCacheValid = now - cacheTimestamp < CACHE_DURATION;

    if (!isCacheValid) {
      console.log(
        `🔄 Refreshing cache (expired ${Math.round(
          (now - cacheTimestamp) / 1000
        )}s ago)`
      );
      await refreshCache();
    } else {
      console.log(
        `✅ Using cached data (${Math.round(
          (now - cacheTimestamp) / 1000
        )}s old)`
      );
    }

    const hierarchy = await getSubstationHierarchy(substationId);
    if (!hierarchy) {
      console.log(`❌ No hierarchy found for substation: ${substationId}`);
      return [];
    }

    const eligibleUsers = await getEligibleUsersOptimized(hierarchy);
    console.log(`👥 Found ${eligibleUsers.length} eligible users in hierarchy`);

    const filteredTokens = [];
    let processedUsers = 0;
    let eligibleUsers_filtered = 0;

    for (const user of eligibleUsers) {
      processedUsers++;

      const preferences =
        preferencesCache.get(user.userId) || getDefaultPreferences();

      if (!isNotificationEnabled(preferences, eventType)) {
        continue;
      }

      if (!meetsVoltageThreshold(preferences, voltageLevel)) {
        continue;
      }

      if (!matchesBayType(preferences, bayType)) {
        continue;
      }

      if (!matchesSubstation(preferences, substationId)) {
        continue;
      }

      const token = tokenCache.get(user.userId);
      if (token) {
        filteredTokens.push(token);
        eligibleUsers_filtered++;
      }
    }

    console.log(
      `🎯 FILTERING SUMMARY: Processed ${processedUsers} users, ${eligibleUsers_filtered} eligible, ${filteredTokens.length} tokens found`
    );

    return filteredTokens;
  } catch (error) {
    console.error("❌ Error in getOptimizedRecipientsForNotification:", error);
    return [];
  }
}

async function refreshCache() {
  try {
    const startTime = Date.now();

    const [preferencesSnapshot, tokensSnapshot] = await Promise.all([
      db.collection("notificationPreferences").get(),
      db.collection("fcmTokens").where("active", "==", true).get(),
    ]);

    preferencesCache.clear();
    tokenCache.clear();

    preferencesSnapshot.docs.forEach((doc) => {
      preferencesCache.set(doc.id, doc.data());
    });

    tokensSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      if (data.token) {
        tokenCache.set(doc.id, data.token);
      }
    });

    cacheTimestamp = Date.now();

    const duration = Date.now() - startTime;
    console.log(
      `✅ Cache refreshed in ${duration}ms: ${preferencesCache.size} preferences, ${tokenCache.size} tokens`
    );
  } catch (error) {
    console.error("❌ Error refreshing cache:", error);
  }
}

async function getSubstationHierarchy(substationId) {
  try {
    const substationDoc = await db
      .collection("substations")
      .doc(substationId)
      .get();

    if (!substationDoc.exists) {
      return null;
    }

    const substationData = substationDoc.data();
    const subdivisionId = substationData.subdivisionId;

    if (!subdivisionId) {
      return null;
    }

    const [subdivisionDoc, divisionDoc, circleDoc] = await Promise.all([
      db.collection("subdivisions").doc(subdivisionId).get(),
      subdivisionDoc?.exists && substationData.divisionId
        ? db.collection("divisions").doc(substationData.divisionId).get()
        : Promise.resolve(null),
      subdivisionDoc?.exists && substationData.circleId
        ? db.collection("circles").doc(substationData.circleId).get()
        : Promise.resolve(null),
    ]);

    return {
      substationId,
      subdivisionId,
      divisionId: divisionDoc?.exists ? divisionDoc.id : null,
      circleId: circleDoc?.exists ? circleDoc.id : null,
      zoneId: circleDoc?.exists ? circleDoc.data()?.zoneId : null,
    };
  } catch (error) {
    console.error("Error getting substation hierarchy:", error);
    return null;
  }
}

async function getEligibleUsersOptimized(hierarchy) {
  const userQueries = [
    db
      .collection("users")
      .where("role", "==", "subdivisionManager")
      .where("assignedLevels.subdivisionId", "==", hierarchy.subdivisionId)
      .get(),
  ];

  if (hierarchy.divisionId) {
    userQueries.push(
      db
        .collection("users")
        .where("role", "==", "divisionManager")
        .where("assignedLevels.divisionId", "==", hierarchy.divisionId)
        .get()
    );
  }

  if (hierarchy.circleId) {
    userQueries.push(
      db
        .collection("users")
        .where("role", "==", "circleManager")
        .where("assignedLevels.circleId", "==", hierarchy.circleId)
        .get()
    );
  }

  if (hierarchy.zoneId) {
    userQueries.push(
      db
        .collection("users")
        .where("role", "==", "zoneManager")
        .where("assignedLevels.zoneId", "==", hierarchy.zoneId)
        .get()
    );
  }

  userQueries.push(db.collection("users").where("role", "==", "admin").get());

  try {
    const userResults = await Promise.all(userQueries);
    const eligibleUsers = [];

    userResults.forEach((querySnapshot) => {
      querySnapshot.docs.forEach((doc) => {
        eligibleUsers.push({
          userId: doc.id,
          ...doc.data(),
        });
      });
    });

    return eligibleUsers;
  } catch (error) {
    console.error("Error getting eligible users:", error);
    return [];
  }
}

function getDefaultPreferences() {
  return {
    subscribedVoltageThresholds: [132, 220, 400, 765],
    enabledOptionalVoltages: [],
    subscribedBayTypes: ["line", "transformer"],
    subscribedSubstations: ["all"],
    enableTrippingNotifications: true,
    enableShutdownNotifications: true,
    enableBreakdownNotifications: true,
  };
}

function isNotificationEnabled(preferences, eventType) {
  if (eventType === "shutdown") {
    return preferences.enableShutdownNotifications !== false;
  } else if (eventType === "breakdown") {
    return preferences.enableBreakdownNotifications !== false;
  } else {
    return preferences.enableTrippingNotifications !== false;
  }
}

function meetsVoltageThreshold(preferences, voltageLevel) {
  const allVoltages = [
    ...(preferences.subscribedVoltageThresholds || []),
    ...(preferences.enabledOptionalVoltages || []),
  ];
  return allVoltages.some(
    (threshold) => voltageLevel >= Number(threshold || 0)
  );
}

function matchesBayType(preferences, bayType) {
  const bayTypes = (preferences.subscribedBayTypes || []).map((x) =>
    x.toLowerCase()
  );
  return bayTypes.includes("all") || bayTypes.includes(bayType);
}

function matchesSubstation(preferences, substationId) {
  const substations = preferences.subscribedSubstations || ["all"];
  return substations.includes("all") || substations.includes(substationId);
}

async function cleanupInvalidTokensBatch(responses, tokens) {
  const invalidTokens = [];

  responses.forEach((response, index) => {
    if (
      response.error &&
      (response.error.code === "messaging/registration-token-not-registered" ||
        response.error.code === "messaging/invalid-registration-token")
    ) {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length > 0) {
    invalidTokens.forEach((token) => {
      for (const [userId, cachedToken] of tokenCache.entries()) {
        if (cachedToken === token) {
          tokenCache.delete(userId);
          break;
        }
      }
    });

    const batch = db.batch();
    const tokenPromises = invalidTokens.map((token) =>
      db.collection("fcmTokens").where("token", "==", token).limit(1).get()
    );

    try {
      const tokenSnapshots = await Promise.all(tokenPromises);

      tokenSnapshots.forEach((snapshot) => {
        snapshot.docs.forEach((doc) => {
          batch.update(doc.ref, { active: false, deactivatedAt: new Date() });
        });
      });

      await batch.commit();
      console.log(
        `🧹 Deactivated ${invalidTokens.length} invalid tokens and updated cache`
      );
    } catch (error) {
      console.error("Error cleaning up invalid tokens:", error);
    }
  }
}

function getNotificationPriority(eventType) {
  if (eventType === "Tripping") return "high";
  if (eventType === "Breakdown") return "high";
  return "normal";
}

function getNotificationSound(eventType) {
  if (eventType === "Tripping" || eventType === "Breakdown") {
    return "alert.wav";
  }
  return "default";
}

function getNotificationColor(eventType, status) {
  if (status === "closed") return "#00C851";

  if (eventType === "Tripping") return "#FF3547";
  if (eventType === "Breakdown") return "#8B00FF";
  return "#FF8800";
}

function getNotificationChannel(eventType, status) {
  if (status === "closed") return "status_update";

  if (eventType === "Tripping") return "emergency";
  if (eventType === "Breakdown") return "breakdown";
  return "maintenance";
}

function parseVoltageLevel(voltageString) {
  if (!voltageString) return 0;
  const match = voltageString.match(/(\d+)kV/i);
  return match ? parseInt(match[1], 10) : 0;
}

exports.sendEventOpenedNotification = onDocumentCreated(
  "trippingShutdownEntries/{eventId}",
  async (event) => {
    if (!event.data) {
      console.log("No data in document");
      return;
    }

    const eventData = event.data.data();

    if (
      eventData.eventType !== "Tripping" &&
      eventData.eventType !== "Shutdown" &&
      eventData.eventType !== "Breakdown"
    ) {
      console.log(`Ignoring event type: ${eventData.eventType}`);
      return;
    }

    console.log(
      `📢 Processing ${eventData.eventType} OPEN notification for event: ${event.params.eventId}`
    );
    await sendEventNotification(eventData, event.params.eventId, "open");
  }
);

exports.sendEventClosedNotification = onDocumentUpdated(
  "trippingShutdownEntries/{eventId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!before || !after) {
      console.log("Invalid document state");
      return;
    }

    if (before.status !== "OPEN" || after.status !== "CLOSED") return;

    if (
      after.eventType !== "Tripping" &&
      after.eventType !== "Shutdown" &&
      after.eventType !== "Breakdown"
    ) {
      return;
    }

    console.log(
      `📢 Processing ${after.eventType} CLOSED notification for event: ${event.data.after.id}`
    );
    await sendEventNotification(after, event.data.after.id, "closed");
  }
);
