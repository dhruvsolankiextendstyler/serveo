import { Notification } from "../models/notification.models.js";
import { User } from "../models/user.models.js";

export const getUserNotificationsController = async (req) => {
    const uid = req.user?.uid;
    const email = req.user?.email;

    if (!uid && !email) {
        const error = new Error("Authentication required");
        error.status = 401;
        throw error;
    }

    let user = await User.findOne({ uid });
    if (!user && email) {
        user = await User.findOne({ email });
    }
    if (!user) {
        return { notifications: [], unreadCount: 0 };
    }

    const notifications = await Notification.find({ userId: user._id })
        .sort({ createdAt: -1 })
        .limit(30)
        .lean();

    const unreadCount = await Notification.countDocuments({
        userId: user._id,
        isRead: false
    });

    return {
        notifications,
        unreadCount
    };
};

export const markNotificationReadController = async (req) => {
    const uid = req.user?.uid;
    const email = req.user?.email;
    const notificationId = req.params?.id || req.body?.notificationId;

    if (!notificationId) {
        const error = new Error("Notification ID is required");
        error.status = 400;
        throw error;
    }

    let user = await User.findOne({ uid });
    if (!user && email) {
        user = await User.findOne({ email });
    }
    if (!user) {
        const error = new Error("User not found");
        error.status = 401;
        throw error;
    }

    const notification = await Notification.findOne({
        _id: notificationId,
        userId: user._id
    });

    if (!notification) {
        const error = new Error("Notification not found");
        error.status = 404;
        throw error;
    }

    notification.isRead = true;
    await notification.save();

    return { message: "Notification marked as read", notification };
};

export const markAllNotificationsReadController = async (req) => {
    const uid = req.user?.uid;
    const email = req.user?.email;

    let user = await User.findOne({ uid });
    if (!user && email) {
        user = await User.findOne({ email });
    }
    if (!user) {
        const error = new Error("User not found");
        error.status = 401;
        throw error;
    }

    await Notification.updateMany(
        { userId: user._id, isRead: false },
        { $set: { isRead: true } }
    );

    return { message: "All notifications marked as read" };
};

export const getNotificationPreferencesController = async (req) => {
    const uid = req.user?.uid;
    const email = req.user?.email;

    let user = await User.findOne({ uid });
    if (!user && email) {
        user = await User.findOne({ email });
    }
    if (!user) {
        return {
            preferences: {
                orders: true,
                promotional: true,
            },
        };
    }

    return {
        preferences: user.notificationPreferences || {
            orders: true,
            promotional: true,
        },
    };
};

export const updateNotificationPreferencesController = async (req) => {
    const uid = req.user?.uid;
    const email = req.user?.email;
    const { orders, promotional } = req.body;

    let user = await User.findOne({ uid });
    if (!user && email) {
        user = await User.findOne({ email });
    }
    if (!user) {
        const error = new Error("User not found");
        error.status = 401;
        throw error;
    }

    if (!user.notificationPreferences) {
        user.notificationPreferences = { orders: true, promotional: true };
    }

    if (orders !== undefined) user.notificationPreferences.orders = Boolean(orders);
    if (promotional !== undefined) user.notificationPreferences.promotional = Boolean(promotional);

    await user.save();
    return {
        message: "Notification preferences updated",
        preferences: user.notificationPreferences,
    };
};
