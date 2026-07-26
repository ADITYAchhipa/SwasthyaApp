const mongoose = require('mongoose');

const NfcCardSchema = new mongoose.Schema(
  {
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Citizen',
      required: true,
      index: true,
    },
    hashedToken: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    rawToken: {
      type: String,
      unique: true,
      sparse: true, // allows null for old records seeded without rawToken
      index: true,
    },
    publicCardId: {
      type: String,
      required: true,
      unique: true,
    },
    status: {
      type: String,
      enum: ['active', 'inactive', 'revoked', 'expired'],
      default: 'active',
    },
    issuedAt: {
      type: Date,
      default: Date.now,
    },
    scanCount: {
      type: Number,
      default: 0,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('NFCCard', NfcCardSchema);
