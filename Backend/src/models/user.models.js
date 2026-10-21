import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
    {
        uid : {
            type: String,
            unique: true,
            required: true
        },
        fcmToken: {
            type: String,
            default: ""
        },
        fullName : {
            type: String,
            required: true
        },
        email : {
            type: String,
            unique: true,
            required: true
        },
        password : {
            type: String,
            required: true
        },
        phoneNumber : {
            type: String,
            unique: true,
            required: true
        },
        sapId : {
            type: String,
            required: false
        }
    },
    {
        timestamps: true
    })

export const User = mongoose.model("User", userSchema)

// Ensure legacy unique index on sapId is dropped if it exists so registrations succeed without sapId
User.collection.dropIndex("sapId_1").catch(() => {});



