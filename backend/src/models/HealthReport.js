const mongoose = require('mongoose');

const HealthReportSchema = new mongoose.Schema(
  {
    citizenId: { type: String, required: true },
    disease: {
      type: String,
      enum: ['Dengue', 'Malaria', 'COVID-19', 'Chikungunya', 'Typhoid', 'Cholera', 'Other'],
      required: true,
    },
    symptoms: [String],
    severityLevel: {
      type: String,
      enum: ['mild', 'moderate', 'severe'],
      default: 'mild',
    },
    lat: Number,
    lng: Number,
    locationDescription: String,
    additionalNotes: { type: String, default: '' },
    status: {
      type: String,
      enum: ['submitted', 'reviewed', 'resolved'],
      default: 'submitted',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('HealthReport', HealthReportSchema);
