const mongoose = require('mongoose');

const OfflineMeshRequestSchema = new mongoose.Schema(
  {
    requestId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    originDeviceId: { type: String, index: true },
    requestDigest: String, // binds retries to the exact signed request
    authorizedAt: Date,
    snapshotAt: Date,
    requestType: { type: String, default: 'MEDICAL_DATA_FETCH' },
    createdAt: Number, // packet iat (unix sec)
    expiresAt: Number, // packet exp (unix sec)
    receivedAt: { type: Date, default: Date.now },
    status: {
      type: String,
      enum: [
        'RECEIVED_BY_GATEWAY',
        'PROCESSING',
        'RESPONSE_READY',
        'DELIVERED',
        'EXPIRED',
        'FAILED',
        'REJECTED',
      ],
      default: 'RECEIVED_BY_GATEWAY',
      index: true,
    },
    ttlOnArrival: Number,
    gatewayDeviceId: String,
    gatewayIp: String,
    targetRefHash: String, // sha256 of profileId / token
    responseStatus: String,
    sealedResponse: String, // base64url sealed RESPONSE packet
    completedAt: Date,
    rejectReason: String,
  },
  { timestamps: true }
);

// TTL index to automatically purge records after 15 minutes (900 seconds)
OfflineMeshRequestSchema.index({ receivedAt: 1 }, { expireAfterSeconds: 900 });

module.exports = mongoose.model('OfflineMeshRequest', OfflineMeshRequestSchema);
