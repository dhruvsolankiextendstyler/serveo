import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";
import { admin } from "../utils/firebase_app.js";


export const updateStatusController = async (req) => {
    const {id, newStatus} = req.body
    const order = await Order.findByIdAndUpdate({ _id : id }, {status : newStatus}, {new : true})
    if (newStatus == "Completed" && order) {
        const user = await User.findById(order.userId);
        if (user && user.fcmToken) {
            const message = {
                notification: {
                    title: "Serveo: Food is Ready!",
                    body: `Order #${order._id.toString().slice(-4)} is ready for pickup.`,
                },
                token: user.fcmToken,
            };
            // Respond without waiting on Google's FCM network round-trip
            admin.messaging().send(message)
                .then(() => console.log("✅ FCM sent to:", user.email))
                .catch((fcmError) => console.error("❌ FCM Error Details:", fcmError));
        }
    }
    return "Status Changed"
}