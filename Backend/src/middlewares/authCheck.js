import { admin } from "../utils/firebase_app.js"

export const authCheck = async (req,res,next) => {
    const token = req.headers.authorization?.split(" ")[1]
    if(!token) return res.status(401).json({"message": "Access denied No token"});
    try{
        req.user = await admin.auth().verifyIdToken(token)
        console.log("User Auth done")
        next()
    }catch(error){
        res.status(401).json({"message": "Invalid or expired token"})
    }
}
