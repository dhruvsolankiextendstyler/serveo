import { admin } from "../utils/firebase_app.js";
import { Restaurant } from "../models/restaurant.models.js";

/**
 * Middleware: Verifies Firebase ID Token, checks administrator permissions,
 * and attaches the administrator's authorized restaurant to req.restaurant & req.restaurantId.
 *
 * Security:
 * - Does not trust client-supplied restaurant ID.
 * - Always scopes administrative actions to the restaurant assigned to the authenticated user.
 * - Preserves backward compatibility for the existing fixed admin: admin123@ad.in.
 */
export const adminCheck = async (req, res, next) => {
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) return res.status(401).json({ message: "Access denied No token" });

    try {
        const decodedToken = await admin.auth().verifyIdToken(token);

        let restaurant = null;
        if (decodedToken.email) {
            restaurant = await Restaurant.findOne({ adminEmails: decodedToken.email });
        }
        if (!restaurant && decodedToken.uid) {
            restaurant = await Restaurant.findOne({ adminUids: decodedToken.uid });
        }

        // Backward compatibility for existing fixed admin email
        if (!restaurant && decodedToken.email === "admin123@ad.in") {
            restaurant = await Restaurant.findOne({ slug: "default" }) || await Restaurant.findOne({});
        }

        if (!restaurant) {
            return res.status(401).json({
                message: "Unauthorized access",
                error: "You are not an authorized administrator for any restaurant."
            });
        }

        req.user = decodedToken;
        req.restaurant = restaurant;
        req.restaurantId = restaurant._id;

        next();
    } catch (error) {
        res.status(401).json({ message: "Invalid or expired token", error: error.message });
    }
};
