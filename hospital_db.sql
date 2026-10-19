-- =============================================================================
-- Hospital Management System (HMS) - MySQL database
-- Derived from the UML class diagram (13 classes, 15 relationships).
--
-- HOW TO RUN
--   Command line : mysql -u root -p < hospital_db.sql
--   Workbench    : File > Open SQL Script > run all (lightning icon)
--   phpMyAdmin   : Import tab > choose this file > Go
-- Tested on MySQL 8 / MariaDB 10.11.
--
-- UML -> SQL MAPPING
--   Class                 -> table (attributes -> columns, String IDs -> VARCHAR primary keys)
--   Generalization        -> subclass table (patient, doctor, nurse) with a UNIQUE foreign key to person
--   Aggregation           -> foreign key in the "part" table (doctor/nurse -> department)
--   Composition           -> foreign key with ON DELETE CASCADE (prescription_item -> prescription)
--   Association 1 - 0..*  -> foreign key on the "many" side
--   Association 1 - 0..1  -> foreign key that is also UNIQUE (prescription -> appointment)
--   PrescriptionItem      -> junction table: composite primary key (prescription_id, medicine_id)
-- =============================================================================

DROP DATABASE IF EXISTS hospital_db;
CREATE DATABASE hospital_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE hospital_db;

-- -----------------------------------------------------------------------------
-- 1. TABLES
-- -----------------------------------------------------------------------------

-- Abstract class Person: shared identity and contact data
CREATE TABLE person (
    person_id      VARCHAR(10)  PRIMARY KEY,
    full_name      VARCHAR(100) NOT NULL,
    date_of_birth  DATE         NOT NULL,
    gender         VARCHAR(10)  NOT NULL,
    phone          VARCHAR(20),
    address        VARCHAR(150),
    CONSTRAINT ck_person_gender CHECK (gender IN ('Male', 'Female', 'Other'))
) ENGINE=InnoDB;

CREATE TABLE department (
    department_id  VARCHAR(10)  PRIMARY KEY,
    name           VARCHAR(80)  NOT NULL UNIQUE,
    location       VARCHAR(100)
) ENGINE=InnoDB;

-- Patient is-a Person
CREATE TABLE patient (
    patient_id         VARCHAR(10) PRIMARY KEY,
    person_id          VARCHAR(10) NOT NULL UNIQUE,
    blood_group        VARCHAR(3),
    registration_date  DATE        NOT NULL,
    CONSTRAINT fk_patient_person FOREIGN KEY (person_id)
        REFERENCES person (person_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT ck_patient_blood CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-'))
) ENGINE=InnoDB;

-- Doctor is-a Person; Department 1 --o 1..* Doctor
CREATE TABLE doctor (
    doctor_id       VARCHAR(10)  PRIMARY KEY,
    person_id       VARCHAR(10)  NOT NULL UNIQUE,
    specialization  VARCHAR(80)  NOT NULL,
    license_number  VARCHAR(30)  NOT NULL UNIQUE,
    department_id   VARCHAR(10)  NOT NULL,
    CONSTRAINT fk_doctor_person FOREIGN KEY (person_id)
        REFERENCES person (person_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_doctor_department FOREIGN KEY (department_id)
        REFERENCES department (department_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Nurse is-a Person; Department 1 --o 0..* Nurse
CREATE TABLE nurse (
    nurse_id       VARCHAR(10) PRIMARY KEY,
    person_id      VARCHAR(10) NOT NULL UNIQUE,
    shift          VARCHAR(10) NOT NULL,
    department_id  VARCHAR(10) NOT NULL,
    CONSTRAINT fk_nurse_person FOREIGN KEY (person_id)
        REFERENCES person (person_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_nurse_department FOREIGN KEY (department_id)
        REFERENCES department (department_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_nurse_shift CHECK (shift IN ('Morning', 'Afternoon', 'Night'))
) ENGINE=InnoDB;

CREATE TABLE medicine (
    medicine_id  VARCHAR(10)   PRIMARY KEY,
    name         VARCHAR(100)  NOT NULL UNIQUE,
    form         VARCHAR(30)   NOT NULL,
    unit_price   DECIMAL(10,2) NOT NULL,
    CONSTRAINT ck_medicine_price CHECK (unit_price >= 0)
) ENGINE=InnoDB;

CREATE TABLE room (
    room_number   VARCHAR(10) PRIMARY KEY,
    type          VARCHAR(20) NOT NULL,
    capacity      INT         NOT NULL,
    is_available  BOOLEAN     NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_room_type CHECK (type IN ('General Ward', 'Private', 'ICU', 'Paediatric Ward')),
    CONSTRAINT ck_room_capacity CHECK (capacity > 0)
) ENGINE=InnoDB;

-- Patient 1 -- 0..* Appointment ; Doctor 1 -- 0..* Appointment
-- UNIQUE (doctor_id, appointment_datetime) prevents double-booking a doctor (requirement FR3)
CREATE TABLE appointment (
    appointment_id        VARCHAR(10)  PRIMARY KEY,
    appointment_datetime  DATETIME     NOT NULL,
    status                VARCHAR(12)  NOT NULL DEFAULT 'Scheduled',
    reason                VARCHAR(200),
    diagnosis             VARCHAR(255),
    patient_id            VARCHAR(10)  NOT NULL,
    doctor_id             VARCHAR(10)  NOT NULL,
    CONSTRAINT fk_appointment_patient FOREIGN KEY (patient_id)
        REFERENCES patient (patient_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_appointment_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctor (doctor_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_doctor_slot UNIQUE (doctor_id, appointment_datetime),
    CONSTRAINT ck_appointment_status CHECK (status IN ('Scheduled', 'Completed', 'Cancelled'))
) ENGINE=InnoDB;

-- Appointment 1 -- 0..1 Prescription (UNIQUE foreign key)
CREATE TABLE prescription (
    prescription_id  VARCHAR(10)  PRIMARY KEY,
    issue_date       DATE         NOT NULL,
    notes            VARCHAR(255),
    appointment_id   VARCHAR(10)  NOT NULL UNIQUE,
    CONSTRAINT fk_prescription_appointment FOREIGN KEY (appointment_id)
        REFERENCES appointment (appointment_id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Class PrescriptionItem: composition with Prescription, association with Medicine.
-- Resolves the many-to-many relationship between Prescription and Medicine.
CREATE TABLE prescription_item (
    prescription_id  VARCHAR(10) NOT NULL,
    medicine_id      VARCHAR(10) NOT NULL,
    dosage           VARCHAR(50) NOT NULL,
    frequency        VARCHAR(50) NOT NULL,
    duration_days    INT         NOT NULL,
    PRIMARY KEY (prescription_id, medicine_id),
    CONSTRAINT fk_item_prescription FOREIGN KEY (prescription_id)
        REFERENCES prescription (prescription_id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_item_medicine FOREIGN KEY (medicine_id)
        REFERENCES medicine (medicine_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_item_duration CHECK (duration_days > 0)
) ENGINE=InnoDB;

-- Appointment 1 -- 0..* LabTest
CREATE TABLE lab_test (
    test_id         VARCHAR(10)  PRIMARY KEY,
    test_type       VARCHAR(80)  NOT NULL,
    request_date    DATE         NOT NULL,
    result          VARCHAR(255),
    status          VARCHAR(12)  NOT NULL DEFAULT 'Requested',
    appointment_id  VARCHAR(10)  NOT NULL,
    CONSTRAINT fk_lab_appointment FOREIGN KEY (appointment_id)
        REFERENCES appointment (appointment_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_lab_status CHECK (status IN ('Requested', 'In Progress', 'Completed'))
) ENGINE=InnoDB;

-- Patient 1 -- 0..* Admission ; Admission 0..* -- 1 Room ; Doctor 1 -- 0..* Admission
CREATE TABLE admission (
    admission_id    VARCHAR(10) PRIMARY KEY,
    admit_date      DATE        NOT NULL,
    discharge_date  DATE,
    status          VARCHAR(12) NOT NULL DEFAULT 'Admitted',
    patient_id      VARCHAR(10) NOT NULL,
    room_number     VARCHAR(10) NOT NULL,
    doctor_id       VARCHAR(10) NOT NULL,
    CONSTRAINT fk_admission_patient FOREIGN KEY (patient_id)
        REFERENCES patient (patient_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_admission_room FOREIGN KEY (room_number)
        REFERENCES room (room_number) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_admission_doctor FOREIGN KEY (doctor_id)
        REFERENCES doctor (doctor_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_admission_status CHECK (status IN ('Admitted', 'Discharged')),
    CONSTRAINT ck_admission_dates CHECK (discharge_date IS NULL OR discharge_date >= admit_date)
) ENGINE=InnoDB;

-- Patient 1 -- 0..* Bill
CREATE TABLE bill (
    bill_id         VARCHAR(10)   PRIMARY KEY,
    issue_date      DATE          NOT NULL,
    total_amount    DECIMAL(12,2) NOT NULL,
    payment_status  VARCHAR(15)   NOT NULL DEFAULT 'Unpaid',
    patient_id      VARCHAR(10)   NOT NULL,
    CONSTRAINT fk_bill_patient FOREIGN KEY (patient_id)
        REFERENCES patient (patient_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT ck_bill_total CHECK (total_amount >= 0),
    CONSTRAINT ck_bill_status CHECK (payment_status IN ('Unpaid', 'Partially Paid', 'Paid'))
) ENGINE=InnoDB;

-- -----------------------------------------------------------------------------
-- 2. SAMPLE DATA (insert parents before children so foreign keys are satisfied)
-- -----------------------------------------------------------------------------

-- Departments
INSERT INTO department (department_id, name, location) VALUES
('DEP001', 'Cardiology',       'Block A, Floor 2'),
('DEP002', 'Paediatrics',      'Block B, Floor 1'),
('DEP003', 'General Medicine', 'Block A, Floor 1');

-- Persons (5 patients, 4 doctors, 3 nurses)
INSERT INTO person (person_id, full_name, date_of_birth, gender, phone, address) VALUES
('P001', 'Aline Uwase',          '1990-03-14', 'Female', '0788100001', 'Kicukiro, Kigali'),
('P002', 'Jean Claude Habimana', '1985-07-02', 'Male',   '0788100002', 'Gasabo, Kigali'),
('P003', 'Grace Mukamana',       '2001-11-23', 'Female', '0788100003', 'Nyarugenge, Kigali'),
('P004', 'Eric Nsengiyumva',     '1978-01-30', 'Male',   '0788100004', 'Kicukiro, Kigali'),
('P005', 'Divine Ingabire',      '2015-05-09', 'Female', '0788100005', 'Gasabo, Kigali'),
('P006', 'Patrick Niyonzima',    '1975-09-12', 'Male',   '0788200001', 'Kimironko, Kigali'),
('P007', 'Sandrine Uwimana',     '1983-04-18', 'Female', '0788200002', 'Remera, Kigali'),
('P008', 'Olivier Mugisha',      '1980-12-05', 'Male',   '0788200003', 'Nyamirambo, Kigali'),
('P009', 'Claudine Mutesi',      '1979-06-21', 'Female', '0788200004', 'Kacyiru, Kigali'),
('P010', 'Josiane Uwera',        '1992-02-11', 'Female', '0788300001', 'Kanombe, Kigali'),
('P011', 'Emmanuel Bizimana',    '1990-08-27', 'Male',   '0788300002', 'Gikondo, Kigali'),
('P012', 'Chantal Ishimwe',      '1994-10-03', 'Female', '0788300003', 'Kibagabaga, Kigali');

-- Patients
INSERT INTO patient (patient_id, person_id, blood_group, registration_date) VALUES
('PAT001', 'P001', 'O+',  '2026-01-15'),
('PAT002', 'P002', 'A+',  '2026-02-03'),
('PAT003', 'P003', 'B+',  '2026-05-20'),
('PAT004', 'P004', 'AB-', '2026-07-08'),
('PAT005', 'P005', 'O-',  '2026-09-01');

-- Doctors
INSERT INTO doctor (doctor_id, person_id, specialization, license_number, department_id) VALUES
('DOC001', 'P006', 'Cardiologist',          'RMDC-1001', 'DEP001'),
('DOC002', 'P007', 'Paediatrician',         'RMDC-1002', 'DEP002'),
('DOC003', 'P008', 'General Practitioner',  'RMDC-1003', 'DEP003'),
('DOC004', 'P009', 'General Practitioner',  'RMDC-1004', 'DEP003');

-- Nurses
INSERT INTO nurse (nurse_id, person_id, shift, department_id) VALUES
('NUR001', 'P010', 'Morning',   'DEP001'),
('NUR002', 'P011', 'Night',     'DEP003'),
('NUR003', 'P012', 'Afternoon', 'DEP002');

-- Medicines (prices in RWF)
INSERT INTO medicine (medicine_id, name, form, unit_price) VALUES
('MED001', 'Paracetamol 500mg',            'Tablet', 100.00),
('MED002', 'Artemether-Lumefantrine',      'Tablet', 1500.00),
('MED003', 'Amlodipine 5mg',               'Tablet', 300.00),
('MED004', 'Amoxicillin 250mg/5ml',        'Syrup',  2500.00),
('MED005', 'Ciprofloxacin 500mg',          'Tablet', 400.00);

-- Rooms
INSERT INTO room (room_number, type, capacity, is_available) VALUES
('R101', 'General Ward',    4, TRUE),
('R102', 'Private',         1, FALSE),
('R201', 'Paediatric Ward', 6, TRUE),
('R301', 'ICU',             2, TRUE);

-- Appointments
INSERT INTO appointment (appointment_id, appointment_datetime, status, reason, diagnosis, patient_id, doctor_id) VALUES
('APT001', '2026-10-12 09:00:00', 'Completed', 'Persistent fever and headache', 'Malaria',       'PAT001', 'DOC003'),
('APT002', '2026-10-12 10:30:00', 'Completed', 'Chest pain',                    'Hypertension',  'PAT002', 'DOC001'),
('APT003', '2026-10-13 08:30:00', 'Completed', 'Cough and breathing difficulty', 'Bronchitis',   'PAT005', 'DOC002'),
('APT004', '2026-10-14 11:00:00', 'Completed', 'Abdominal pain',                'Typhoid fever', 'PAT003', 'DOC003'),
('APT005', '2026-10-21 09:30:00', 'Scheduled', 'Follow-up consultation',         NULL,           'PAT004', 'DOC001'),
('APT006', '2026-10-15 14:00:00', 'Cancelled', 'Routine check-up',               NULL,           'PAT001', 'DOC004');

-- Prescriptions (one per completed appointment)
INSERT INTO prescription (prescription_id, issue_date, notes, appointment_id) VALUES
('PRE001', '2026-10-12', 'Take after meals',                'APT001'),
('PRE002', '2026-10-12', 'Monitor blood pressure weekly',   'APT002'),
('PRE003', '2026-10-13', 'Give with plenty of fluids',      'APT003'),
('PRE004', '2026-10-14', 'Complete the full course',        'APT004');

-- Prescription items (composition of Prescription, reference to Medicine)
INSERT INTO prescription_item (prescription_id, medicine_id, dosage, frequency, duration_days) VALUES
('PRE001', 'MED002', '4 tablets', 'Twice daily',       3),
('PRE001', 'MED001', '1 tablet',  'Every 6 hours',     3),
('PRE002', 'MED003', '1 tablet',  'Once daily',        30),
('PRE003', 'MED004', '5 ml',      'Three times daily', 7),
('PRE004', 'MED005', '1 tablet',  'Twice daily',       7),
('PRE004', 'MED001', '1 tablet',  'When in pain',      5);

-- Lab tests
INSERT INTO lab_test (test_id, test_type, request_date, result, status, appointment_id) VALUES
('LAB001', 'Malaria rapid test', '2026-10-12', 'Positive',                  'Completed',   'APT001'),
('LAB002', 'ECG',                '2026-10-12', 'Mild left ventricular strain', 'Completed', 'APT002'),
('LAB003', 'Full blood count',   '2026-10-13', NULL,                        'In Progress', 'APT003'),
('LAB004', 'Widal test',         '2026-10-14', 'Positive',                  'Completed',   'APT004');

-- Admissions (ADM002 and ADM003 are already discharged; ADM001 is still in hospital)
INSERT INTO admission (admission_id, admit_date, discharge_date, status, patient_id, room_number, doctor_id) VALUES
('ADM001', '2026-10-14', NULL,         'Admitted',   'PAT003', 'R102', 'DOC003'),
('ADM002', '2026-10-13', '2026-10-16', 'Discharged', 'PAT005', 'R201', 'DOC002'),
('ADM003', '2026-09-20', '2026-09-24', 'Discharged', 'PAT002', 'R101', 'DOC001');

-- Bills (amounts in RWF)
INSERT INTO bill (bill_id, issue_date, total_amount, payment_status, patient_id) VALUES
('BIL001', '2026-10-12',  17500.00, 'Paid',           'PAT001'),
('BIL002', '2026-10-12',  18200.00, 'Partially Paid', 'PAT002'),
('BIL003', '2026-10-16',  95000.00, 'Unpaid',         'PAT005'),
('BIL004', '2026-09-24', 210000.00, 'Paid',           'PAT002');

-- Quick check: row count per table
SELECT 'person' AS table_name, COUNT(*) AS rows_inserted FROM person
UNION ALL SELECT 'patient', COUNT(*) FROM patient
UNION ALL SELECT 'doctor', COUNT(*) FROM doctor
UNION ALL SELECT 'nurse', COUNT(*) FROM nurse
UNION ALL SELECT 'department', COUNT(*) FROM department
UNION ALL SELECT 'appointment', COUNT(*) FROM appointment
UNION ALL SELECT 'prescription', COUNT(*) FROM prescription
UNION ALL SELECT 'medicine', COUNT(*) FROM medicine
UNION ALL SELECT 'prescription_item', COUNT(*) FROM prescription_item
UNION ALL SELECT 'lab_test', COUNT(*) FROM lab_test
UNION ALL SELECT 'room', COUNT(*) FROM room
UNION ALL SELECT 'admission', COUNT(*) FROM admission
UNION ALL SELECT 'bill', COUNT(*) FROM bill;
