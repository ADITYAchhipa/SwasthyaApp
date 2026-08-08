const mongoose = require('mongoose');

const PhcSchema = new mongoose.Schema(
  {
    phcId: {
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
    rating: { type: Number, default: 4.2 },
    reviews: { type: Number, default: 150 },
    status: { type: String, default: 'Open Now' },
    statusDetails: { type: String, default: 'General OPD, Maternal Care' },
    badges: [{ type: String }],
    inchargeDoctor: { type: String, default: 'Medical Officer Incharge' },
    bedCount: { type: Number, default: 10 },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Phc', PhcSchema);
