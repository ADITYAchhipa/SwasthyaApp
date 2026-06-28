const mongoose = require('mongoose');

const OtpSessionSchema = new mongoose.Schema({
  phone: {
    type: String,
    required: false,
    index: true,
  },
  email: {
    type: String,
    required: false,
    index: true,
  },
  otp: {
    type: String,
    required: true,
  },
  purpose: {
    type: String,
    enum: ['citizen_login', 'hospital_login'],
    default: 'citizen_login',
  },
  expiresAt: {
    type: Date,
    required: true,
    index: { expireAfterSeconds: 0 }, // MongoDB TTL index: auto-delete when expired
  },
  used: {
    type: Boolean,
    default: false,
  },
});

module.exports = mongoose.model('OtpSession', OtpSessionSchema);
