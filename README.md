# Hospital Management System (HMS) - UML Class Diagram

UML Class Diagram Modelling assignment, Kigali Independent University (ULK), Undergraduate data science department.
Instructor: Eric Maniraguha. Deadline: Tuesday, 20 October 2026, 8:30 AM.

## Group members

| Name | Student ID |
|---|---|
| DAUGLA DOURAH NGUEMADJIMBAYE | 202512707 |


## Business idea

A hospital needs an information system to manage patients, doctors and nurses, departments, appointments,
prescriptions, laboratory tests, admissions to rooms and billing. This project models that system with a UML class
diagram. Building the working application is **not** part of the assignment.

## Problem statement

Paper registers and disconnected files cause lost patient records, double-booked appointments, slow lab results,
prescription errors, unclear room availability and inaccurate billing. The proposed system centralises this
information in one consistent model. 

## Scope

**Covered:** patient registration and history, doctor/nurse/department management, appointment scheduling,
prescriptions, lab tests, admissions and rooms, billing and payments.

**Not covered:** payroll/HR, medical imaging storage, telemedicine, pharmacy purchasing, external insurance claims,
user-account classes, and the development of the working application.

## UML class diagram

![UML class diagram](diagrams/uml_class_diagram.png)

## Classes (13)

| Class | Responsibility |
|---|---|
| Person *(abstract)* | Abstract superclass holding the identity and contact details shared by every person in the hospital. |
| Patient | Person receiving care. Central class that links appointments, admissions and bills. |
| Doctor | Medical practitioner who diagnoses patients, issues prescriptions, orders lab tests and supervises admissions. |
| Nurse | Supports patient care by recording vital signs and assisting doctors within a department. |
| Department | Organisational unit (for example Cardiology or Paediatrics) that groups doctors and nurses. |
| Appointment | Scheduled consultation between one patient and one doctor; stores date and time, status, reason and diagnosis. |
| Prescription | Medical order issued after an appointment, listing the medicines to be dispensed. |
| PrescriptionItem | One line of a prescription (medicine, dosage, frequency, duration). Resolves the many-to-many link between Prescription and Medicine. |
| Medicine | Catalogue entry for a drug (name, form, unit price) that can be prescribed. |
| LabTest | Diagnostic test requested during an appointment; stores the test type, status and result. |
| Admission | Inpatient stay of a patient, with admit and discharge dates; supervised by a doctor and assigned to a room. |
| Room | Physical room or ward with a type, a capacity and an availability status. |
| Bill | Financial document charged to a patient for hospital services; tracks the total amount and payment status. |

## Relationships (15)

| Relationship | Type | Multiplicity |
|---|---|---|
| Patient is-a Person | Generalization | - |
| Doctor is-a Person | Generalization | - |
| Nurse is-a Person | Generalization | - |
| Department - Doctor (employs) | Aggregation | 1 : 1..* |
| Department - Nurse (staffs) | Aggregation | 1 : 0..* |
| Patient - Appointment (books) | Association | 1 : 0..* |
| Doctor - Appointment (attends) | Association | 1 : 0..* |
| Appointment - LabTest (requires) | Association | 1 : 0..* |
| Appointment - Prescription (results in) | Association | 1 : 0..1 |
| Prescription - PrescriptionItem (contains) | Composition | 1 : 1..* |
| PrescriptionItem - Medicine (refers to) | Association | 0..* : 1 |
| Patient - Admission (is admitted) | Association | 1 : 0..* |
| Admission - Room (assigned to) | Association | 0..* : 1 |
| Doctor - Admission (supervises) | Association | 1 : 0..* |
| Patient - Bill (is billed) | Association | 1 : 0..* |

## Database (SQL implementation of the class diagram)

Each class became a table; generalization became subclass tables linked to `person`; composition became
`ON DELETE CASCADE`; the many-to-many link between Prescription and Medicine became the `prescription_item` table.

* **MySQL:** `mysql -u root -p < database/hospital_db.sql`, then `mysql -u root -p < database/hospital_queries.sql`.
* **SQLite:** open `database/hospital.db` with DB Browser for SQLite (https://sqlitebrowser.org).

## Repository structure

```
uml-class-diagram-assignment/
├── README.md
├── documentation/
│   ├── report_1_project_description.pdf
│   └── report_2_uml_class_diagram.pdf
├── diagrams/
│   ├── uml_class_diagram.drawio   (editable diagram - open with draw.io)
│   ├── uml_class_diagram.png      (exported image)
│   └── uml_class_diagram.puml     (PlantUML source code of the same diagram)
└── database/
    ├── hospital_db.sql            (MySQL: creates the 13 tables and inserts sample data)
    ├── hospital_queries.sql       (example INSERT / UPDATE / SELECT statements)
    └── hospital.db                (SQLite version, ready to open in DB Browser for SQLite)
```

## How to view or edit the diagram

* **draw.io:** open https://app.diagrams.net, choose *File > Open from > Device* and select
  `diagrams/uml_class_diagram.drawio`. Export with *File > Export as > PNG*.
* **PlantUML:** paste `diagrams/uml_class_diagram.puml` into https://www.plantuml.com/plantuml or render it with
  `java -jar plantuml.jar -tpng diagrams/uml_class_diagram.puml`.
