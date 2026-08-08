const mongoose = require('mongoose');

const BloodBankSchema = new mongoose.Schema(
  {
    bloodBankId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    name: { type: String, required: true },
    address: { type: String, required: true },
    city: { type: String, default: 'Bangalore' },
    state: { type: String, default: 'Karnataka' },
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    phone: { type: String, required: true },
    rating: { type: Number, default: 4.5 },
    reviews: { type: Number, default: 220 },
    status: { type: String, default: 'Open Now' },
    statusDetails: { type: String, default: '24x7 Emergency Blood Supply' },
    availableGroups: [{ type: String }],
    badges: [{ type: String }],
    hasPlateletApheresis: { type: Boolean, default: true },
    isGovernment: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model('BloodBank', BloodBankSchema);
