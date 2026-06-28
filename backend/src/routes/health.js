const express = require('express');
const router = express.Router();
const HealthReport = require('../models/HealthReport');
const { authenticate } = require('../middleware/auth');

// ─── POST /api/health-reports ────────────────────────────────────────────────
// Submit a disease/health issue report
router.post('/', authenticate, async (req, res) => {
  try {
    const { disease, symptoms, severityLevel, lat, lng, locationDescription, additionalNotes } = req.body;

    if (!disease) {
      return res.status(400).json({ success: false, message: 'Disease type is required' });
    }

    const report = await HealthReport.create({
      citizenId: req.user.citizenId,
      disease,
      symptoms: symptoms || [],
      severityLevel: severityLevel || 'mild',
      lat,
      lng,
      locationDescription: locationDescription || '',
      additionalNotes: additionalNotes || '',
    });

    console.log(`\n🦠 Health Report: ${disease} (${severityLevel}) from citizen ${req.user.citizenId}\n`);

    res.status(201).json({
      success: true,
      reportId: report._id,
      message: 'Health report submitted successfully. Thank you for helping your community.',
    });
  } catch (err) {
    console.error('health report error:', err);
    res.status(500).json({ success: false, message: 'Failed to submit report' });
  }
});

// ─── GET /api/health-reports/summary ─────────────────────────────────────────
// Public aggregate for dashboard stats
router.get('/summary', async (req, res) => {
  try {
    const summary = await HealthReport.aggregate([
      { $group: { _id: '$disease', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
    ]);
    res.json({ success: true, summary });
  } catch (err) {
    res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
