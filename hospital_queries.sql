-- =============================================================================
-- Hospital Management System - example INSERT / UPDATE / SELECT statements
-- Run hospital_db.sql FIRST, then run this file:
--     mysql -u root -p < hospital_queries.sql
-- =============================================================================
USE hospital_db;

-- -----------------------------------------------------------------------------
-- A. INSERTING NEW DATA
-- -----------------------------------------------------------------------------

-- A1. Register a new patient. Patient is-a Person, so two rows are needed:
--     the person first, then the patient that points to it. A transaction keeps both or neither.
START TRANSACTION;
INSERT INTO person (person_id, full_name, date_of_birth, gender, phone, address)
VALUES ('P013', 'Alice Uwimana', '1996-06-18', 'Female', '0788100006', 'Nyarugenge, Kigali');
INSERT INTO patient (patient_id, person_id, blood_group, registration_date)
VALUES ('PAT006', 'P013', 'A-', '2026-10-19');
COMMIT;

-- A2. Book an appointment for the new patient
INSERT INTO appointment (appointment_id, appointment_datetime, status, reason, patient_id, doctor_id)
VALUES ('APT007', '2026-10-22 10:00:00', 'Scheduled', 'General check-up', 'PAT006', 'DOC004');

-- A3. Double-booking is blocked: the same doctor at the same time raises a duplicate-entry error.
--     (Uncomment to test.)
-- INSERT INTO appointment (appointment_id, appointment_datetime, status, reason, patient_id, doctor_id)
-- VALUES ('APT008', '2026-10-22 10:00:00', 'Scheduled', 'Fever', 'PAT001', 'DOC004');

-- -----------------------------------------------------------------------------
-- B. QUERIES
-- -----------------------------------------------------------------------------

-- B1. All patients with their personal details (Patient JOIN Person)
SELECT pa.patient_id, pe.full_name, pe.gender, pe.date_of_birth, pa.blood_group, pe.phone
FROM patient pa
JOIN person pe ON pe.person_id = pa.person_id
ORDER BY pa.patient_id;

-- B2. Doctors with their department
SELECT d.doctor_id, pe.full_name AS doctor, d.specialization, dep.name AS department
FROM doctor d
JOIN person pe     ON pe.person_id = d.person_id
JOIN department dep ON dep.department_id = d.department_id
ORDER BY dep.name, pe.full_name;

-- B3. Appointments with patient and doctor names
SELECT a.appointment_id, a.appointment_datetime, a.status,
       pp.full_name AS patient, dp.full_name AS doctor, a.reason, a.diagnosis
FROM appointment a
JOIN patient pa ON pa.patient_id = a.patient_id
JOIN person  pp ON pp.person_id  = pa.person_id
JOIN doctor  d  ON d.doctor_id   = a.doctor_id
JOIN person  dp ON dp.person_id  = d.person_id
ORDER BY a.appointment_datetime;

-- B4. Full prescription detail: who, what medicine, how much, for how long
SELECT pr.prescription_id, pp.full_name AS patient, m.name AS medicine,
       i.dosage, i.frequency, i.duration_days
FROM prescription pr
JOIN appointment a ON a.appointment_id = pr.appointment_id
JOIN patient pa    ON pa.patient_id    = a.patient_id
JOIN person  pp    ON pp.person_id     = pa.person_id
JOIN prescription_item i ON i.prescription_id = pr.prescription_id
JOIN medicine m    ON m.medicine_id    = i.medicine_id
ORDER BY pr.prescription_id, m.name;

-- B5. Lab tests that are still waiting for a result
SELECT t.test_id, t.test_type, t.request_date, t.status, pp.full_name AS patient
FROM lab_test t
JOIN appointment a ON a.appointment_id = t.appointment_id
JOIN patient pa    ON pa.patient_id    = a.patient_id
JOIN person  pp    ON pp.person_id     = pa.person_id
WHERE t.status <> 'Completed';

-- B6. Patients currently admitted (no discharge date) and their rooms
SELECT ad.admission_id, pp.full_name AS patient, ad.room_number, ad.admit_date
FROM admission ad
JOIN patient pa ON pa.patient_id = ad.patient_id
JOIN person  pp ON pp.person_id  = pa.person_id
WHERE ad.discharge_date IS NULL;

-- B7. Rooms that are available
SELECT room_number, type, capacity FROM room WHERE is_available = TRUE;

-- B8. Number of appointments per doctor
SELECT dp.full_name AS doctor, COUNT(a.appointment_id) AS total_appointments
FROM doctor d
JOIN person dp ON dp.person_id = d.person_id
LEFT JOIN appointment a ON a.doctor_id = d.doctor_id
GROUP BY d.doctor_id, dp.full_name
ORDER BY total_appointments DESC;

-- B9. Amount still to be paid, per patient (Unpaid and Partially Paid bills)
SELECT pp.full_name AS patient, SUM(b.total_amount) AS outstanding_rwf
FROM bill b
JOIN patient pa ON pa.patient_id = b.patient_id
JOIN person  pp ON pp.person_id  = pa.person_id
WHERE b.payment_status <> 'Paid'
GROUP BY pa.patient_id, pp.full_name;

-- B10. Medical history of one patient: appointments, diagnosis and admissions
SELECT 'Appointment' AS event_type, a.appointment_datetime AS event_date, a.diagnosis AS detail
FROM appointment a WHERE a.patient_id = 'PAT002'
UNION ALL
SELECT 'Admission', ad.admit_date, CONCAT('Room ', ad.room_number, ' - ', ad.status)
FROM admission ad WHERE ad.patient_id = 'PAT002'
ORDER BY event_date;

-- -----------------------------------------------------------------------------
-- C. UPDATING DATA (run after the queries so the queries above still show the "before" state)
-- -----------------------------------------------------------------------------

-- C1. Complete an appointment and record the diagnosis
UPDATE appointment
SET status = 'Completed', diagnosis = 'Healthy - routine check-up'
WHERE appointment_id = 'APT007';

-- C2. Discharge a patient and free the room
UPDATE admission SET status = 'Discharged', discharge_date = '2026-10-19' WHERE admission_id = 'ADM001';
UPDATE room SET is_available = TRUE WHERE room_number = 'R102';

-- C3. Record a lab result
UPDATE lab_test SET result = 'Normal', status = 'Completed' WHERE test_id = 'LAB003';

-- C4. Record a payment
UPDATE bill SET payment_status = 'Paid' WHERE bill_id = 'BIL003';

-- -----------------------------------------------------------------------------
-- D. CHECK THE EFFECT OF THE UPDATES
-- -----------------------------------------------------------------------------
SELECT room_number, is_available FROM room ORDER BY room_number;
SELECT bill_id, payment_status FROM bill ORDER BY bill_id;
SELECT test_id, status, result FROM lab_test ORDER BY test_id;
