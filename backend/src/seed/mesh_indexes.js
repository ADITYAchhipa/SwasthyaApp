require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });
const mongoose = require('mongoose');
const MeshDevice = require('../models/MeshDevice');
const OfflineMeshRequest = require('../models/OfflineMeshRequest');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/swasthyatap';

async function run() {
  console.log('Connecting to MongoDB...');
  await mongoose.connect(MONGO_URI);
  console.log('Connected to MongoDB.');

  console.log('Ensuring indexes for MeshDevice model...');
  await MeshDevice.ensureIndexes();

  console.log('Ensuring indexes for OfflineMeshRequest model (including TTL index)...');
  await OfflineMeshRequest.ensureIndexes();

  console.log('✅ Offline mesh database indexes created / verified successfully.');
  await mongoose.disconnect();
  console.log('Disconnected.');
}

run().catch(err => {
  console.error('Index creation failed:', err);
  process.exit(1);
});
