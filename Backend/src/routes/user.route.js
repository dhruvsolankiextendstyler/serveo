import express from "express"
import { authCheck } from "../middlewares/authCheck.js"
import { signupController } from "../controllers/signup.controller.js"
import { loginController } from "../controllers/login.controller.js"
import { updateFcmToken, clearFcmToken } from "../controllers/fcm.controller.js";

export const userRoute = express.Router()

userRoute.post('/signup/', authCheck, async (req,res) => {
    try {
        const msg = await signupController(req)
        if (msg !== "User Created Successfully") return res.status(400).json({"message": msg})
        res.status(201).json({"message": msg})
        console.log("User Signed Up")
    } catch (error) {
        console.error("Signup Route Error:", error.message)
        res.status(500).json({"message": "Server unavailable. Please try again later."})
    }
})

userRoute.get('/login', authCheck, async (req,res) => {
    try {
        const msg = await loginController(req)
        let userType = "normal"
        if( msg == "admin123") userType = "undefined"
        res.json({"message": msg, "userType": userType})
        console.log("User Logged In!")
    } catch (error) {
        console.error("Login Route Error:", error.message)
        res.status(500).json({"message": "Server unavailable. Please try again later."})
    }
})

userRoute.patch("/update-fcm", authCheck, updateFcmToken);

userRoute.patch("/clear-fcm", authCheck, clearFcmToken);
