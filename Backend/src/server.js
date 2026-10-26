import "dotenv/config";
import express from "express";
import cors from "cors";
import mongoose from "mongoose";
import { userRoute } from "./routes/user.route.js";
import { DBConnect } from "./utils/db_connect.js";
import { itemRoute } from "./routes/item.route.js";
import { orderRoute } from "./routes/order.route.js";

const app = express();

app.use(express.json());
app.use(cors());
DBConnect();

// Health check endpoint for uptime monitors, Render pingers, and cold-start diagnostics
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: "serveo-backend",
    timestamp: new Date().toISOString(),
    database: mongoose.connection.readyState === 1 ? "connected" : "connecting"
  });
});

app.use('/user', userRoute);
app.use('/item', itemRoute);
app.use('/order', orderRoute);

app.listen(process.env.PORT || 5000, () => {
  console.log("Server Started");
});