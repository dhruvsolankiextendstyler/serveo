/**
 * Evaluates whether a restaurant is currently open to accept new orders.
 *
 * Rules:
 * 1. If isOrderAcceptancePaused is true: status is "PAUSED" and canOrder is false.
 * 2. Operating days check: verifies if current day is in configured operatingDays or schedule.
 * 3. Operating hours check: supports normal day hours (e.g. 09:00 - 22:00)
 *    and midnight-crossing hours (e.g. 18:00 - 02:00).
 * 4. Timezone-aware: parses date in restaurant's configured timezone (default: Asia/Kolkata).
 */

export function checkRestaurantAvailability(restaurant, checkDate = new Date()) {
  if (!restaurant) {
    return {
      isOpen: false,
      status: "CLOSED",
      reason: "Restaurant profile not found.",
      canOrder: false,
      day: "",
      operatingHours: "",
    };
  }

  // 1. Emergency order acceptance pause toggle
  if (restaurant.isOrderAcceptancePaused) {
    return {
      isOpen: false,
      status: "PAUSED",
      reason: restaurant.pauseReason?.trim() || "Restaurant has temporarily paused accepting new orders.",
      canOrder: false,
      day: "",
      operatingHours: `${restaurant.openingTime || "09:00"} - ${restaurant.closingTime || "22:00"}`,
    };
  }

  // 2. Format current date & time in restaurant's configured timezone
  const tz = restaurant.timezone || "Asia/Kolkata";
  let dayOfWeek = "";
  let currentHours = 0;
  let currentMinutes = 0;

  try {
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      weekday: "long",
      hour: "numeric",
      minute: "numeric",
      hour12: false,
    });
    const parts = formatter.formatToParts(checkDate);
    for (const part of parts) {
      if (part.type === "weekday") dayOfWeek = part.value;
      if (part.type === "hour") currentHours = parseInt(part.value, 10);
      if (part.type === "minute") currentMinutes = parseInt(part.value, 10);
    }
    // Handle 24h edge case where 24 becomes 0
    if (currentHours === 24) currentHours = 0;
  } catch (_) {
    // Robust fallback to IST (UTC + 5:30)
    const istMs = checkDate.getTime() + (5.5 * 60 * 60 * 1000);
    const d = new Date(istMs);
    const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    dayOfWeek = days[d.getUTCDay()];
    currentHours = d.getUTCHours();
    currentMinutes = d.getUTCMinutes();
  }

  // 3. Check daily schedule if configured, else fallback to operatingDays
  let daySchedule = null;
  if (Array.isArray(restaurant.schedule) && restaurant.schedule.length > 0) {
    daySchedule = restaurant.schedule.find(
      s => s.day && s.day.toLowerCase() === dayOfWeek.toLowerCase()
    );
  }

  let isDayOpen = true;
  let openTimeStr = restaurant.openingTime || "09:00";
  let closeTimeStr = restaurant.closingTime || "22:00";

  if (daySchedule) {
    isDayOpen = daySchedule.isOpen !== false;
    if (daySchedule.openTime) openTimeStr = daySchedule.openTime;
    if (daySchedule.closeTime) closeTimeStr = daySchedule.closeTime;
  } else if (Array.isArray(restaurant.operatingDays) && restaurant.operatingDays.length > 0) {
    isDayOpen = restaurant.operatingDays.some(
      d => d.toLowerCase() === dayOfWeek.toLowerCase()
    );
  }

  if (!isDayOpen) {
    return {
      isOpen: false,
      status: "CLOSED",
      reason: `Restaurant is closed on ${dayOfWeek}s.`,
      canOrder: false,
      day: dayOfWeek,
      operatingHours: `${openTimeStr} - ${closeTimeStr}`,
    };
  }

  // 4. Time range comparison
  const [openH = 9, openM = 0] = openTimeStr.split(":").map(Number);
  const [closeH = 22, closeM = 0] = closeTimeStr.split(":").map(Number);

  const currentTotalMins = currentHours * 60 + currentMinutes;
  const openTotalMins = openH * 60 + openM;
  const closeTotalMins = closeH * 60 + closeM;

  let isTimeOpen = false;
  if (openTotalMins <= closeTotalMins) {
    // Standard same-day operating hours (e.g. 09:00 to 22:00)
    isTimeOpen = currentTotalMins >= openTotalMins && currentTotalMins <= closeTotalMins;
  } else {
    // Midnight-crossing hours (e.g. 18:00 to 02:00)
    isTimeOpen = currentTotalMins >= openTotalMins || currentTotalMins <= closeTotalMins;
  }

  if (!isTimeOpen) {
    return {
      isOpen: false,
      status: "CLOSED",
      reason: `Restaurant is currently closed. Today's hours: ${openTimeStr} - ${closeTimeStr} (${tz}).`,
      canOrder: false,
      day: dayOfWeek,
      operatingHours: `${openTimeStr} - ${closeTimeStr}`,
    };
  }

  return {
    isOpen: true,
    status: "OPEN",
    reason: "Restaurant is open and accepting orders.",
    canOrder: true,
    day: dayOfWeek,
    operatingHours: `${openTimeStr} - ${closeTimeStr}`,
  };
}

