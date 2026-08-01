const mongoose = require('mongoose');
const fs = require('fs');

const mongoUri = 'mongodb+srv://adichhipa2_db_user:Oo2WWuEiChjI7Ab8@swasthyatap.abo8hz9.mongodb.net/swasthyatap?appName=swasthyatap';

const HospitalSchema = new mongoose.Schema({
  hospitalId: String,
  name: String,
  registeredPhone: String,
  authorizedPersonnel: Array,
});

const Hospital = mongoose.model('Hospital', HospitalSchema);

async function run() {
  let log = "";
  try {
    log += "Connecting to MongoDB...\n";
    await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 5000 });
    log += "Connected to MongoDB successfully!\n";
    
    const hospital = await Hospital.findOne({ hospitalId: 'HOSP-004' });
    log += "HOSP-004: " + JSON.stringify(hospital) + "\n";
  } catch (err) {
    log += "Error connecting to MongoDB: " + err.message + "\n";
  } finally {
    fs.writeFileSync('/home/aditya/clones/Card/scratch/check_db_output.txt', log);
    await mongoose.disconnect();
    process.exit(0);
  }
}

run();
