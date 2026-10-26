import mongoose from "mongoose";
import { Order } from "../models/order.models.js";
import { User } from "../models/user.models.js";

/**
 * Controller to retrieve order details for live tracking.
 * Enforces verified ownership: customers can ONLY track their own orders.
 */
export async function trackOrderController(req) {
  const orderId = req.params?.id || req.query?.id || req.body?.orderId;

  if (!orderId) {
    const error = new Error("Order ID is required");
    error.status = 400;
    throw error;
  }

  if (!mongoose.Types.ObjectId.isValid(orderId)) {
    const error = new Error("Invalid Order ID format");
    error.status = 400;
    throw error;
  }

  // 1. Identify authenticated user
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

  if (!user && email !== "admin123@ad.in") {
    const error = new Error("User account not found");
    error.status = 401;
    throw error;
  }

  // 2. Retrieve order from database
  const order = await Order.findById(orderId).lean();

  if (!order) {
    const error = new Error("Order not found");
    error.status = 404;
    throw error;
  }

  // 3. Verify ownership (allow order owner or verified admin)
  const isOwner = user && order.userId.toString() === user._id.toString();
  const isAdmin = email === "admin123@ad.in";

  if (!isOwner && !isAdmin) {
    const error = new Error("Access denied. You do not have permission to view this order.");
    error.status = 403;
    throw error;
  }

  // 4. Return sanitized tracking payload (strictly no customer PII leaked)
  const terminalStatuses = ["Collected", "Completed", "Cancelled", "Payment Rejected"];
  const isTerminal = terminalStatuses.includes(order.status);

  return {
    id: order._id.toString(),
    status: order.status,
    paymentMethod: order.paymentMethod,
    paymentStatus: order.paymentStatus,
    totalAmount: order.totalAmount,
    orderItems: (order.orderItems || []).map(item => ({
      itemId: item.itemId?.toString() || "",
      itemName: item.itemName,
      itemPrice: item.itemPrice,
      quantity: item.quantity,
    })),
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
    paymentClaimedAt: order.paymentClaimedAt,
    paymentVerifiedAt: order.paymentVerifiedAt,
    isTerminal,
  };
}
