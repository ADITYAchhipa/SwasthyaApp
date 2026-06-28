require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const citizenRoutes = require('./routes/citizens');
const orderRoutes = require('./routes/orders');
const bloodRequestRoutes = require('./routes/bloodRequests');
const hospitalRoutes = require('./routes/hospitals');
const healthRoutes = require('./routes/health');

const app = express();
const PORT = process.env.PORT || 3000;

// ─── Middleware ────────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ─── Request Logger ─────────────────────────────────────────────────────────
app.use((req, res, next) => {
  const time = new Date().toISOString();
  console.log(`[${time}] ${req.method} ${req.url}`);
  next();
});

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/citizens', citizenRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/blood-requests', bloodRequestRoutes);
app.use('/api/hospitals', hospitalRoutes);
app.use('/api/health-reports', healthRoutes);

// ─── Health Check ─────────────────────────────────────────────────────────────
app.get('/api/ping', (req, res) => {
  res.json({
    status: 'ok',
    message: 'SwasthyaTap API is running',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// ─── 404 Fallback ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

// ─── Global Error Handler ─────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ success: false, message: 'Internal server error' });
});

// ─── Database + Server Start ──────────────────────────────────────────────────
const mongoUri = process.env.MONGO_URI;
mongoose
  .connect(mongoUri, { serverSelectionTimeoutMS: 5000 })
  .then(() => {
    console.log('\n✅ Connected to MongoDB:', mongoUri);
    app.listen(PORT, () => {
      console.log(`🚀 SwasthyaTap API running on http://localhost:${PORT}`);
      console.log(`📡 Health check: http://localhost:${PORT}/api/ping\n`);
    });
  })
  .catch((err) => {
    console.error('❌ MongoDB Atlas connection failed:', err.message);
    if (mongoUri !== 'mongodb://localhost:27017/swasthyatap') {
      console.log('🔄 Attempting fallback connection to local MongoDB...');
      mongoose
        .connect('mongodb://localhost:27017/swasthyatap')
        .then(() => {
          console.log('✅ Connected to local MongoDB fallback!');
          app.listen(PORT, () => {
            console.log(`🚀 SwasthyaTap API running on http://localhost:${PORT}`);
            console.log(`📡 Health check: http://localhost:${PORT}/api/ping\n`);
          });
        })
        .catch((fallbackErr) => {
          console.error('❌ Local fallback MongoDB connection failed:', fallbackErr.message);
          process.exit(1);
        });
    } else {
      process.exit(1);
    }
  });
