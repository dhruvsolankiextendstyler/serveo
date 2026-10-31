/**
 * Serveo Subscription Plans & Feature Tiers
 *
 * Configurable plan definitions specifying operational limits and feature entitlements.
 */
export const PLANS = {
  starter: {
    id: "starter",
    name: "Starter",
    description: "Essential menu, orders, and counter operations for small cafes",
    maxActiveMenuItems: 20,
    maxStaffAccounts: 2,
    features: {
      basicOrders: true,
      menuManagement: true,
      standardReports: true,
      advancedAnalytics: false,
      exportData: false,
      prioritySupport: false,
      marketingAndLoyalty: false,
      customerRetentionAnalytics: false,
    },
  },
  growth: {
    id: "growth",
    name: "Growth",
    description: "Expanded menu capacity, advanced analytics, and multi-staff management",
    maxActiveMenuItems: 50,
    maxStaffAccounts: 5,
    features: {
      basicOrders: true,
      menuManagement: true,
      standardReports: true,
      advancedAnalytics: true,
      exportData: true,
      prioritySupport: false,
      marketingAndLoyalty: true,
      customerRetentionAnalytics: true,
    },
  },
  premium: {
    id: "premium",
    name: "Premium",
    description: "High-volume catalog, unrestricted staff accounts, and comprehensive analytics",
    maxActiveMenuItems: 500,
    maxStaffAccounts: 25,
    features: {
      basicOrders: true,
      menuManagement: true,
      standardReports: true,
      advancedAnalytics: true,
      exportData: true,
      prioritySupport: true,
      marketingAndLoyalty: true,
      customerRetentionAnalytics: true,
    },
  },
};

/**
 * Helper to retrieve plan configuration by planId with fallback to starter.
 */
export function getPlanConfig(planId) {
  const normalized = (planId || "starter").toLowerCase().trim();
  return PLANS[normalized] || PLANS.starter;
}

