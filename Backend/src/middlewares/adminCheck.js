import { admin } from "../utils/firebase_app.js";

export const adminCheck = async (req,res,next) => {
    const token = req.headers.authorization?.split(" ")[1]
    if(!token) return res.status(401).json({"message": "Access denied No token"})
    try{
        const decodedToken = await admin.auth().verifyIdToken(token)
        if (decodedToken.email == "admin123@ad.in"){
            req.user = decodedToken
            console.log("User Auth done")
            next()
        }else{
            res.status(401).json({"message": "Unauthorized access"})
        }
    }catch(error){
        res.status(401).json({"message": "Invalid or expired token"})
    }
}