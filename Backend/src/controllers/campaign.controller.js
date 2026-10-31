import { Campaign } from "../models/campaign.models.js";
import { Restaurant } from "../models/restaurant.models.js";
import { Coupon } from "../models/coupon.models.js";
import mongoose from "mongoose";

/**
 * GET /restaurant/:restaurantId/campaigns/active
 * Customer endpoint: Lists active marketing campaigns for display on menu / home screen.
 */
export async function getActiveCampaignsController(req, res) {
  try {
    const restaurantId = req.params.restaurantId || req.query.restaurantId;

    let targetId = null;
    if (restaurantId && mongoose.Types.ObjectId.isValid(restaurantId)) {
      targetId = restaurantId;
    } else {
      const defaultRest = await Restaurant.findOne({ slug: "default" }) || await Restaurant.findOne({});
      if (defaultRest) targetId = defaultRest._id;
    }

    if (!targetId) {
      return res.json({ campaigns: [] });
    }

    const now = new Date();
    const campaigns = await Campaign.find({
      restaurantId: targetId,
      isActive: true,
      startDate: { $lte: now },
      endDate: { $gte: now },
    }).sort({ createdAt: -1 });

    // Asynchronously record views
    if (campaigns.length > 0) {
      Campaign.updateMany(
        { _id: { $in: campaigns.map((c) => c._id) } },
        { $inc: { viewCount: 1 } }
      ).catch(() => {});
    }

    res.json({
      campaigns: campaigns.map((c) => ({
        id: c._id,
        title: c.title,
        description: c.description,
        bannerUrl: c.bannerUrl || "",
        campaignType: c.campaignType,
        couponCode: c.couponCode || "",
        startDate: c.startDate,
        endDate: c.endDate,
        termsAndConditions: c.termsAndConditions,
        eligibleCategories: c.eligibleCategories,
      })),
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

/**
 * POST /restaurant/:restaurantId/campaigns/:id/click
 * Customer endpoint: Records banner click / interaction.
 */
export async function recordCampaignClickController(req, res) {
  try {
    const { id } = req.params;
    await Campaign.findByIdAndUpdate(id, { $inc: { clickCount: 1 } });
    res.json({ success: true });
  } catch (_) {
    res.json({ success: false });
  }
}

/**
 * GET /restaurant/admin/campaigns
 * Admin endpoint: List all campaigns for restaurant with performance stats.
 */
export async function getAdminCampaignsController(req, res) {
  try {
    const campaigns = await Campaign.find({ restaurantId: req.restaurantId }).sort({ createdAt: -1 });
    res.json({ campaigns });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
}

/**
 * POST /restaurant/admin/campaigns
 * Admin endpoint: Create a new marketing campaign.
 */
export async function createCampaignController(req, res) {
  try {
    const {
      title,
      description,
      bannerUrl,
      campaignType,
      couponCode,
      startDate,
      endDate,
      termsAndConditions,
      eligibleCategories,
      eligibleItems,
    } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({ error: "Campaign title is required" });
    }
    if (!description || !description.trim()) {
      return res.status(400).json({ error: "Campaign description is required" });
    }
    if (!endDate) {
      return res.status(400).json({ error: "Campaign end date is required" });
    }

    const start = startDate ? new Date(startDate) : new Date();
    const end = new Date(endDate);

    if (end <= start) {
      return res.status(400).json({ error: "End date must be later than start date" });
    }

    // Optional coupon check
    if (couponCode && couponCode.trim()) {
      const normalizedCode = couponCode.trim().toUpperCase();
      const coupon = await Coupon.findOne({
        restaurantId: req.restaurantId,
        code: normalizedCode,
      });
      if (!coupon) {
        return res.status(400).json({
          error: `Coupon '${normalizedCode}' does not exist for this restaurant. Please create the coupon first.`,
        });
      }
    }

    const campaign = new Campaign({
      restaurantId: req.restaurantId,
      title: title.trim(),
      description: description.trim(),
      bannerUrl: (bannerUrl || "").trim(),
      campaignType: campaignType || "general",
      couponCode: (couponCode || "").trim().toUpperCase(),
      startDate: start,
      endDate: end,
      termsAndConditions: (termsAndConditions || "").trim() || "Valid for a limited time at participating restaurant.",
      eligibleCategories: Array.isArray(eligibleCategories) ? eligibleCategories : [],
      eligibleItems: Array.isArray(eligibleItems) ? eligibleItems : [],
      createdBy: req.user?.email || "admin",
    });

    await campaign.save();
    res.status(201).json({ message: "Campaign created successfully", campaign });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}

/**
 * PUT /restaurant/admin/campaigns/:id
 * Admin endpoint: Update existing campaign.
 */
export async function updateCampaignController(req, res) {
  try {
    const { id } = req.params;
    const campaign = await Campaign.findOne({ _id: id, restaurantId: req.restaurantId });
    if (!campaign) {
      return res.status(404).json({ error: "Campaign not found" });
    }

    const {
      title,
      description,
      bannerUrl,
      campaignType,
      couponCode,
      startDate,
      endDate,
      isActive,
      termsAndConditions,
      eligibleCategories,
      eligibleItems,
    } = req.body;

    if (title !== undefined) campaign.title = title.trim();
    if (description !== undefined) campaign.description = description.trim();
    if (bannerUrl !== undefined) campaign.bannerUrl = bannerUrl.trim();
    if (campaignType !== undefined) campaign.campaignType = campaignType;
    if (couponCode !== undefined) campaign.couponCode = couponCode.trim().toUpperCase();
    if (startDate !== undefined) campaign.startDate = new Date(startDate);
    if (endDate !== undefined) campaign.endDate = new Date(endDate);
    if (isActive !== undefined) campaign.isActive = Boolean(isActive);
    if (termsAndConditions !== undefined) campaign.termsAndConditions = termsAndConditions.trim();
    if (eligibleCategories !== undefined) campaign.eligibleCategories = eligibleCategories;
    if (eligibleItems !== undefined) campaign.eligibleItems = eligibleItems;

    await campaign.save();
    res.json({ message: "Campaign updated successfully", campaign });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}

/**
 * PATCH /restaurant/admin/campaigns/:id/status
 * Admin endpoint: Toggle active status.
 */
export async function toggleCampaignStatusController(req, res) {
  try {
    const { id } = req.params;
    const campaign = await Campaign.findOne({ _id: id, restaurantId: req.restaurantId });
    if (!campaign) {
      return res.status(404).json({ error: "Campaign not found" });
    }

    campaign.isActive = req.body.isActive !== undefined ? Boolean(req.body.isActive) : !campaign.isActive;
    await campaign.save();
    res.json({ message: `Campaign is now ${campaign.isActive ? "Active" : "Inactive"}`, campaign });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}

/**
 * DELETE /restaurant/admin/campaigns/:id
 * Admin endpoint: Delete campaign.
 */
export async function deleteCampaignController(req, res) {
  try {
    const { id } = req.params;
    const campaign = await Campaign.findOneAndDelete({ _id: id, restaurantId: req.restaurantId });
    if (!campaign) {
      return res.status(404).json({ error: "Campaign not found" });
    }
    res.json({ message: "Campaign deleted successfully", campaignId: id });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}
