const mongoose = require('mongoose');

const EmergencyContactSchema = new mongoose.Schema({
  name: { type: String, required: true },
  relation: { type: String, required: true },
  phone: { type: String, required: true },
});

const OrganPledgeSchema = new mongoose.Schema({
  pledgeId: String,
  pledgedOrgans: [String],
  signedDate: String,
  signatureHash: String,
  nottoVerified: { type: Boolean, default: false },
});

const CitizenSchema = new mongoose.Schema(
  {
    // Short URL-safe ID (e.g., 'x7k9m2') — used in NFC/QR payloads
    profileId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    phoneNumber: {
      type: String,
      required: false,
      unique: true,
      sparse: true,
      index: true,
    },
    email: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },

    // Core Identity
    fullName: { type: String, required: true },
    bloodGroup: { type: String, default: 'Unknown' },
    age: { type: Number, default: null },
    address: { type: String, default: '' },

    // Medical Details
    allergies: { type: String, default: 'None' },
    medications: { type: String, default: 'None' },
    chronicConditions: { type: String, default: 'None' },
    specialInstructions: { type: String, default: 'None' },
    isDnr: { type: Boolean, default: false },

    // Emergency Network
    emergencyContacts: [EmergencyContactSchema],

    // Organ Donation
    organPledge: OrganPledgeSchema,

    // Insurance
    insuranceCompany: { type: String, default: '' },
    insurancePolicyNumber: { type: String, default: '' },

    // Blood Donor Details
    isBloodDonor: { type: Boolean, default: false },
    donorRadiusKm: { type: Number, default: 5.0 },

    // Location (home coordinates)
    homeLat: { type: Number, default: 12.9716 },
    homeLng: { type: Number, default: 77.5946 },

    // Gamification
    lifeCredits: { type: Number, default: 0 },

    // App
    selectedLanguage: { type: String, default: 'English' },
    profileCompleteness: { type: Number, default: 0 }, // 0-100
  },
  { timestamps: true }
);

// Generate a 6-char alphanumeric profile ID
CitizenSchema.statics.generateProfileId = function () {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let id = '';
  for (let i = 0; i < 6; i++) {
    id += chars[Math.floor(Math.random() * chars.length)];
  }
  return id;
};

// Calculate profile completeness score
CitizenSchema.methods.calculateCompleteness = function () {
  let score = 0;
  if (this.fullName) score += 15;
  if (this.bloodGroup && this.bloodGroup !== 'Unknown') score += 15;
  if (this.age) score += 10;
  if (this.address) score += 10;
  if (this.allergies && this.allergies !== 'None') score += 10;
  if (this.medications && this.medications !== 'None') score += 10;
  if (this.emergencyContacts && this.emergencyContacts.length > 0) score += 15;
  if (this.organPledge) score += 10;
  if (this.insuranceCompany) score += 5;
  return score;
};

module.exports = mongoose.model('Citizen', CitizenSchema);
