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

    isVerified: { type: Boolean, default: true },
    specialties: [String],
    bedCount: { type: Number, default: 0 },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Hospital', HospitalSchema);
