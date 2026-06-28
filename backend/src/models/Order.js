const mongoose = require('mongoose');

const OrderSchema = new mongoose.Schema(
  {
    orderId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    citizenId: {
      type: String,
      required: true,
      index: true,
    },
    citizenName: { type: String, required: true },
    phone: { type: String, required: true },

    // Card type chosen
    cardType: {
      type: String,
      enum: ['free', 'standard', 'wristband', 'premium'],
      default: 'free',
    },
    price: { type: Number, default: 0 },

    // Delivery details
    deliveryAddress: { type: String, required: true },
    city: { type: String, required: true },
    state: { type: String, required: true },
    pincode: { type: String, required: true },

    // Order lifecycle
    status: {
      type: String,
      enum: ['ordered', 'programmed', 'shipped', 'delivered'],
      default: 'ordered',
    },
    statusStep: { type: Number, default: 0 }, // 0,1,2,3

    estimatedDelivery: { type: Date },
    deliveredAt: { type: Date },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Order', OrderSchema);
