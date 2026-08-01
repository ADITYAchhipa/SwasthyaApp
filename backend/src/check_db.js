const mongoose = require('mongoose');

const mongoUri = 'mongodb+srv://adichhipa2_db_user:Oo2WWuEiChjI7Ab8@swasthyatap.abo8hz9.mongodb.net/swasthyatap?appName=swasthyatap';

const HospitalSchema = new mongoose.Schema({
  hospitalId: String,
  name: String,
  registeredPhone: String,
  authorizedPersonnel: Array,
});

const Hospital = mongoose.model('Hospital', HospitalSchema);

async function run() {
  try {
    await mongoose.connect(mongoUri);
    console.log("Connected to MongoDB!");
    
    // Find HOSP-004
    const hospital = await Hospital.findOne({ hospitalId: 'HOSP-004' });
    console.log("HOSP-004 Record:", JSON.stringify(hospital, null, 2));

    // Find all hospitals to see what exists
    const all = await Hospital.find({}, { hospitalId: 1, name: 1, registeredPhone: 1 });
    console.log("\nAll Hospitals in Database:");
    console.log(JSON.stringify(all, null, 2));
    
    await mongoose.disconnect();
  } catch (err) {
    console.error("Error:", err);
  }
}

run();
