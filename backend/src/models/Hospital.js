const mongoose = require('mongoose');

const HospitalSchema = new mongoose.Schema(
  {
    hospitalId: {
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

    // List of authorized personnel IDs for this hospital
    authorizedPersonnel: [
      {
        personnelId: String,
        name: String,
        designation: String,
      },
    ],

    // Registered phone for OTP during login
    registeredPhone: { type: String, required: true },
    phone: { type: String, default: '+91 80 2699 5000' },
    rating: { type: Number, default: 4.6 },
    reviews: { type: Number, default: 1250 },
    status: { type: String, default: 'Open Now' },
    statusDetails: { type: String, default: '24x7 Emergency Services' },

    isVerified: { type: Boolean, default: true },
    specialties: [{ type: String }],
    badges: [{ type: String }],
    bedCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Hospital', HospitalSchema);
