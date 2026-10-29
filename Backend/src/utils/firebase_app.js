import dotenv from "dotenv";
dotenv.config();
import firebase from "firebase-admin";

const privateKey = process.env.FIREBASE_PRIVATE_KEY
  ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
  : undefined;

export const admin = firebase.apps.length > 0
  ? firebase.app()
  : (privateKey
      ? firebase.initializeApp({
          credential: firebase.credential.cert({
            projectId: process.env.FIREBASE_PROJECT_ID,
            clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
            privateKey: privateKey,
          }),
        })
      : firebase.initializeApp({
          projectId: process.env.FIREBASE_PROJECT_ID || "serveo-foods",
        }));
