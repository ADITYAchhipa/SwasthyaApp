require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });
const mongoose = require('mongoose');
const Hospital = require('../models/Hospital');

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/swasthyatap';

const newHospitals = [
  {
    hospitalId: 'HOSP-004',
    name: 'Fortis Hospital, Bannerghatta Road',
    address: '154/9, Bannerghatta Road, Opposite IIM-B, Bangalore',
    city: 'Bangalore',
    state: 'Karnataka',
    lat: 12.8954,
    lng: 77.5979,
    registeredPhone: '9900112233',
    authorizedPersonnel: [
      { personnelId: 'STAFF-006', name: 'Dr. Aditya Chhipa', designation: 'Cardiologist Head' },
      { personnelId: 'STAFF-007', name: 'Nurse Sophia', designation: 'ER Specialist Nurse' },
    ],
    specialties: ['Cardiology', 'Orthopedics', 'Emergency Care', 'Neurology'],
    bedCount: 400,
    isVerified: true,
  },
  {
    hospitalId: 'HOSP-005',
    name: 'Manipal Hospital, HAL Airport Road',
    address: '98, HAL Airport Road, Kodihalli, Bangalore',
    city: 'Bangalore',
    state: 'Karnataka',
    lat: 12.9592,
    lng: 77.6438,
    registeredPhone: '9900112233',
    authorizedPersonnel: [
      { personnelId: 'STAFF-008', name: 'Dr. Prafful Nagda', designation: 'Critical Care Chief' },
      { personnelId: 'STAFF-009', name: 'Nurse Emily', designation: 'Head Staff Nurse' },
    ],
    specialties: ['Nephrology', 'Emergency', 'Pediatrics', 'Oncology'],
    bedCount: 650,
    isVerified: true,
  },
  {
    hospitalId: 'HOSP-006',
    name: 'Narayana Health City',
    address: '258/A, Bommasandra Industrial Area, Hosur Road, Bangalore',
    city: 'Bangalore',
    state: 'Karnataka',
    lat: 12.8123,
    lng: 77.6934,
    registeredPhone: '9900112233',
    authorizedPersonnel: [
      { personnelId: 'STAFF-010', name: 'Dr. Devi Shetty', designation: 'Chairman & Cardiac Surgeon' },
      { personnelId: 'STAFF-011', name: 'Nurse Chloe', designation: 'Senior ICU Nurse' },
    ],
    specialties: ['Cardiology', 'Cardio-Thoracic Surgery', 'Organ Transplant'],
    bedCount: 1000,
    isVerified: true,
  },
  {
    hospitalId: 'HOSP-007',
    name: 'Aster CMI Hospital, Hebbal',
    address: '43/2, New Airport Road, NH-7, Sahakara Nagar, Bangalore',
    city: 'Bangalore',
    state: 'Karnataka',
    lat: 13.0612,
    lng: 77.5958,
    registeredPhone: '9900112233',
    authorizedPersonnel: [
      { personnelId: 'STAFF-012', name: 'Dr. Ramesh Mehta', designation: 'Neurosurgeon Chief' },
      { personnelId: 'STAFF-013', name: 'Nurse Mia', designation: 'Trauma Unit Lead' },
    ],
    specialties: ['Neurology', 'Gastroenterology', 'Emergency Medicine'],
    bedCount: 500,
    isVerified: true,
  },
  {
    hospitalId: 'HOSP-008',
    name: 'Columbia Asia Referral Hospital, Yeshwanthpur',
    address: '26/4, Brigade Gateway, Beside Metro Cash & Carry, Yeshwanthpur, Bangalore',
    city: 'Bangalore',
    state: 'Karnataka',
    lat: 13.0125,
    lng: 77.5552,
    registeredPhone: '9900112233',
    authorizedPersonnel: [
      { personnelId: 'STAFF-014', name: 'Dr. Sarah Jenkins', designation: 'Pediatrics Lead' },
      { personnelId: 'STAFF-015', name: 'Nurse Olivia', designation: 'Senior Staff Nurse' },
    ],
    specialties: ['Pediatrics', 'Obstetrics & Gynecology', 'Emergency Care'],
    bedCount: 300,
    isVerified: true,
  },
];

async function run() {
  console.log('Connecting to MongoDB...');
  await mongoose.connect(MONGO_URI);
  console.log('Connected to MongoDB.');

  for (const h of newHospitals) {
    const existing = await Hospital.findOne({ hospitalId: h.hospitalId });
    if (existing) {
      console.log(`Hospital ${h.hospitalId} (${h.name}) already exists. Updating...`);
      await Hospital.updateOne({ hospitalId: h.hospitalId }, h);
    } else {
      console.log(`Registering new hospital ${h.hospitalId} (${h.name})...`);
      await Hospital.create(h);
    }
  }

  console.log('All hospitals successfully registered / updated.');
  await mongoose.disconnect();
  console.log('Disconnected from MongoDB.');
}

run().catch(err => {
  console.error('Registration failed:', err);
  process.exit(1);
});
