const mongoose = require('mongoose');

const DonorResponseSchema = new mongoose.Schema({
  donorId: String,
  donorName: String,
  phone: String,
  status: {
    type: String,
    enum: ['pending', 'accepted', 'declined'],
    default: 'pending',
  },
  etaMinutes: { type: Number, default: 0 },
  lat: Number,
  lng: Number,
  respondedAt: Date,
});

const BloodRequestSchema = new mongoose.Schema(
  {
    requestId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    hospitalName: { type: String, required: true },
    hospitalAddress: { type: String, required: true },
    bloodGroup: { type: String, required: true },
    unitsNeeded: { type: Number, required: true },
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    radiusKm: { type: Number, default: 10 },

    status: {
      type: String,
      enum: ['active', 'fulfilled', 'cancelled'],
      default: 'active',
    },

    responses: [DonorResponseSchema],
    
    declaredBy: { type: String }, // hospitalId of declaring hospital
  },
  { timestamps: true }
);

module.exports = mongoose.model('BloodRequest', BloodRequestSchema);
