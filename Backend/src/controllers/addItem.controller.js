import { Item } from "../models/item.models.js"

export const addItemController = async (req) => {
    const itemExists = await Item.findOne({itemName: req.body.itemName})

    if(itemExists) return "Item Exists!"
    const newItem = new Item({
        itemName: req.body.itemName,
        itemPrice: Number(req.body.itemPrice),
        category: req.body.category,
        description: req.body.description || "",
        isAvailable: req.body.isAvailable !== undefined ? (req.body.isAvailable === true || req.body.isAvailable === 'true') : true,
        imageUrl: req.body.imageUrl || "",
    })
    await newItem.save()
    console.log("Item Created Succesfully")
    return "Item Created Succssfully"
}