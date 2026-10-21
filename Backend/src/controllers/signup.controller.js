import { User } from "../models/user.models.js"

export const signupController = async (req) => {
    const token = req.user.uid
    const fname = req.body.uname?.trim()
    const email = req.body.uemail?.trim()
    const password = req.body.upass
    const pnum = req.body.upnum?.trim()

    if (!fname || !email || !password || !pnum) {
        return "Missing required fields"
    }

    const userExists = await User.findOne({uid: token})

    if(userExists != null){ 
        console.log("User Exists")
        return "User already exists"
    }
    
    try{
        const newUser = new User({
            uid : token,
            fullName : fname,
            email : email,
            password : password,
            phoneNumber : pnum,
        })
        await newUser.save()
        console.log("User Created")
        return "User Created Successfully"
    }catch(e){
        console.error("Signup DB Error:", e.message)
        if (e.code === 11000) {
            if (e.keyPattern && e.keyPattern.phoneNumber) {
                return "Phone number is already registered"
            }
            if (e.keyPattern && e.keyPattern.email) {
                return "Email is already registered"
            }
            return "An account with this email or phone number already exists"
        }
        return "Registration failed due to a server error"
    }
}
