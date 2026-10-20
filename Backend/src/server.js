import "dotenv/config";
import express from "express";
import cors from "cors";
import { userRoute } from "./routes/user.route.js";
import { DBConnect } from "./utils/db_connect.js";
import { itemRoute } from "./routes/item.route.js";
import { orderRoute } from "./routes/order.route.js";

const app = express();

app.use(express.json())
app.use(cors())
DBConnect()

app.use('/user', userRoute)
app.use('/item', itemRoute)
app.use('/order', orderRoute)

app.listen( process.env.PORT || 5000 , () => {console.log("Server Started")})