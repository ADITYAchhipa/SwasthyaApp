const mongoose = require('mongoose');

const MeshDeviceSchema = new mongoose.Schema(
  {
    deviceId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    signingPublicKey: { type: String, required: true },   // base64 raw Ed25519
    agreementPublicKey: { type: String, required: true }, // base64 raw X25519
    ownerType: {
      type: String,
      enum: ['hospital', 'citizen'],
      required: true,
    },
    hospitalId: { type: String, index: true, sparse: true },
    citizenId: { type: String, index: true, sparse: true },
    personnelId: String,
    destinationToken: { type: String, index: true },
    status: {
      type: String,
      enum: ['active', 'revoked'],
      default: 'active',
    },
    lastSeenAt: Date,
  },
  { timestamps: true }
);

module.exports = mongoose.model('MeshDevice', MeshDeviceSchema);
