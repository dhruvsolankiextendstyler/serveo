import { User } from "../models/user.models.js";

export const loginController = async (req) => {
    if (req.user?.email === "admin123@ad.in") return "admin123";
    const token = req.user.uid;
    const user = await User.findOne({uid: token}).select("fullName");
    return user ? user.fullName : (req.user.name || "User");
}   