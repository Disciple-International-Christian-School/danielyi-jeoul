# Original Business Specification — 35 Sections

**Language / 언어:** [English](spec.md) | [한국어](spec.ko.md)

> Historical requirements, not a current implementation contract. Later decisions supersede manual-author, calendar-month, student-CRUD, and stack assumptions. English labels below translate the original Korean UI wording; the operational application remains Korean. See [Change Log](CHANGELOG.md).

Build a complete, production-ready full-stack web application called "Daniel's Scale".

This is NOT just a UI mockup.
Generate the actual working application code, including frontend, backend/server logic, database schema, authentication, authorization, validation, business rules, and data persistence.

The entire user-facing application must be in Korean.

==================================================
1. PROJECT OVERVIEW
==================================================

Service name:
"Daniel's Scale"

Purpose:
A school student council management system for managing:
- Basic student information
- Merits
- Demerits
- Demerit item
- Reflection submission status
- Student sanctions
- weekly/monthly automatic status detection

There are exactly two administrative roles:

1. Student guidance
2. Residential life

This is an internal administrative application.

Students do NOT log into the system.

Only administrators can access the application.

==================================================
2. RECOMMENDED TECH STACK
==================================================

Use a modern full-stack architecture.

Preferred:
- Next.js with App Router
- TypeScript
- React
- Tailwind CSS
- shadcn/ui
- PostgreSQL
- Prisma ORM
- Secure authentication
- Server-side authorization
- Zod for validation

If the deployment environment provides a managed database/authentication solution such as Supabase, use it when appropriate.

The application must be structured so it can be deployed to a modern cloud platform.

Do NOT build a fake frontend using only hardcoded mock data.

All important data must be persisted in the database.

==================================================
3. AUTHENTICATION
==================================================

Create an authentication system for administrators.

There are two roles:

- SEONDO
  Display-name meaning: "Student guidance"

- SASAENG
  Display-name meaning: "Residential life"

Administrators log in using:
- ID/email
- Password

After login, redirect the user to the dashboard.

Store the user's role in the authenticated session.

Implement server-side authorization.

A user with role "Student guidance" must not be able to access restricted Residential life functions.

A user with role "Residential life" must not be able to modify Student guidance-only settings.

Do not rely only on hiding buttons in the frontend for authorization.

==================================================
4. STUDENT DATA
==================================================

Only store basic student information.

Student fields:

- id
- name
- grade
- createdAt
- updatedAt

Do NOT store unnecessary personal information.

Do not store:
- phone number
- address
- resident registration number
- parent information
- medical information
- unnecessary sensitive personal data

The system derives the following from records:

- current Merits
- current Demerits
- weekly Demerits
- monthly Demerits
- current punishment
- reflection paper status
- automatic status

==================================================
5. STUDENT MANAGEMENT
==================================================

Create a student management page.

Features:
- Search students by name
- Filter by grade
- Sort students
- View student details
- Add student
- Edit student
- Delete student

Default sorting:

1. Highest current Demerits
2. Grade
3. Korean alphabetical order

Student table:

- Grade
- Name
- Merits
- Demerits
- Current sanction
- Status
- Details

==================================================
6. POINT RECORDS
==================================================

Create a point record system.

A point record contains:

- id
- studentId
- type
  - POSITIVE
  - NEGATIVE
- item
- points
- date
- enteredByName
- createdAt
- updatedAt

The "enteredByName" field MUST be manually typed by the administrator.

IMPORTANT:
Do NOT automatically populate enteredByName with the logged-in user's name.

The administrator must type the person's name manually.

==================================================
7. PENALTY ENTRY
==================================================

Create a penalty entry form/modal.

Fields:

- Student
- Demerit item
- Demerits
- Entered by
- Reflection submitted

The student field should be a searchable dropdown.

The penalty item field should be a searchable combobox with a dropdown arrow.

Preset items include:

- Tardiness
- Uniform violation
- Untidy shoe storage
- Teacher-discretion demerit
- Other (manual entry)

IMPORTANT:
Do NOT invent fixed point values for:
- Tardiness
- Uniform violation
- Untidy shoe storage

Their point values must be configurable by administrators.

When a preset item with a configured fixed score is selected:
- automatically populate the score
- prevent accidental modification if the item is configured as fixed

For "Other (manual entry)":
- allow manual item name
- allow manual point input

==================================================
8. TEACHER-DISCRETION PENALTY
==================================================

"Teacher-discretion demerit" is a special item.

It does NOT have a fixed point value.

When selected, display:

[ 1 points ]
[ 2 points ]
[ 3 points ]
[ 4 points ]
[ 5 points ]

The administrator must select exactly one value.

Only 1–5 points are allowed.

Server-side validation MUST also enforce this rule.

Do not trust client-side validation alone.

==================================================
9. POSITIVE POINTS / Merits
==================================================

Create a separate form for entering Merits.

Fields:

- Student
- Merit item
- Merits
- Entered by
- Date

The same manual "Entered by" rule applies.

Allow administrators to manage positive-point items in the future.

==================================================
10. REFLECTION PAPER SYSTEM
==================================================

Every penalty record can have a reflection paper submission status.

Fields:

- submitted
- submissionDeadline
- submittedAt

When a penalty is entered:

- submissionDeadline = the same calendar day as the penalty entry

Default:

submitted = false

The administrator must manually check:

"☐ Reflection submitted"

Checked:
"Submitted"

Unchecked:
"Missing"

IMPORTANT AUTOMATIC RULE:

If the next calendar day has begun and submitted is still false:

Set/display:
"Double submission required"

Do not delete the original record.

Store the original penalty date and deadline.

Create a dedicated reflection paper management page.

Filters:
- All
- Submitted
- Missing
- Double submission required

==================================================
11. AUTOMATIC SEONDO RULES
==================================================

The system must automatically calculate the following statuses.

RULE A — WEEKLY:

If a student has:
- 3 or more penalty records in the same week
OR
- 8 or more penalty points in the same week

Then:
"Physical-training eligible"

RULE B — MONTHLY:

If a student has:
- 20 or more penalty points in the current month

Then:
"Committee referral eligible"

These are automatic system statuses.

The system should detect and display the status automatically.

The administrator confirms the actual disposition.

Do NOT automatically create a punishment merely because the status is triggered.

==================================================
12. WEEKLY CALCULATION
==================================================

Create a weekly calculation system.

Weekly penalty points are calculated from historical penalty records.

At the beginning of a new week:

- The displayed "This week demerits" becomes 0 for the new week.
- Historical records are NOT deleted.
- Previous weekly totals remain available.
- Historical weekly totals must remain queryable.

The system needs historical weekly data because it must detect consecutive-week conditions.

Use a consistent definition of a week.

Prefer:
Monday 00:00 through Sunday 23:59:59 in the school's configured timezone.

Make timezone configurable or use Asia/Seoul by default.

==================================================
13. SASAENGHOE / DORMITORY PUNISHMENT
==================================================

Create a punishment management system for "Residential life".

Punishment types:

- Sports restriction
- Snack restriction
- Visitor restriction
- Delayed home leave
- Home-leave restriction

IMPORTANT:
The system must NOT automatically choose a punishment.

The Residential life administrator manually chooses the punishment.

==================================================
14. WEEKLY 5+ RULE
==================================================

If a student has 5 or more penalty points during the current week:

Display:

"Sanction selection required"

Allow the Residential life administrator to manually choose ONE punishment from:

- Sports restriction
- Snack restriction
- Visitor restriction

==================================================
15. WEEKLY 10+ RULE
==================================================

If a student has 10 or more penalty points during the current week:

Allow the Residential life administrator to manually choose TWO punishments from:

- Sports restriction
- Snack restriction
- Visitor restriction

The UI should clearly show:
"Select two sanctions."

Do not automatically select punishments.

Prevent invalid selections on both frontend and backend.

==================================================
16. THREE CONSECUTIVE WEEKS
==================================================

If a student has 5 or more penalty points in each of three consecutive weeks:

Display:

"Home-leave restriction condition met"

The system should calculate this from historical weekly penalty data.

Do not delete weekly history after the weekly reset.

The exact punishment application remains a manual administrative action unless explicitly configured otherwise.

==================================================
17. PUNISHMENT VIOLATION
==================================================

Store active punishment records.

A punishment record contains:

- id
- studentId
- punishmentType
- startDate
- endDate
- enteredByName
- createdAt
- updatedAt

If an applied punishment is marked as violated:

Display:
"Home-leave restriction"

The interface should provide an action for authorized administrators to record a violation.

Do not automatically assume a violation occurred without an administrator recording it.

==================================================
18. PUNISHMENT REGISTRATION
==================================================

Create a punishment registration modal.

Fields:

- Student
- This week demerits
- Select sanction
- Sanction start
- Sanction end
- Entered by

"Entered by" must be a manually typed text field.

For 5+ weekly points:
- allow one punishment selection

For 10+ weekly points:
- allow two punishment selections

Show the current weekly penalty count inside the modal.

Buttons:

[ Cancel ]
[ Register sanction ]

==================================================
19. POINT ITEM MANAGEMENT
==================================================

Create a page:
"Demerit items"

Administrators can:

- Add penalty item
- Edit penalty item
- Delete/deactivate penalty item
- Change fixed point value
- Enable/disable item

Fields:

- itemName
- pointValue
- isFixed
- isActive
- createdAt
- updatedAt

Example items:

Tardiness
Uniform violation
Untidy shoe storage
Teacher-discretion demerit

For "Teacher-discretion demerit":

isFixed = false
allowed range = 1–5

==================================================
20. EXCEL IMPORT
==================================================

Implement Excel import for penalty items.

Provide an "Import Excel" button.

Allow the administrator to upload an Excel file.

Expected columns:

Demerit item
Demerits

Process:

1. Upload Excel file
2. Parse spreadsheet
3. Show preview
4. Validate rows
5. Display validation errors
6. Confirm import
7. Save valid items to database

Do not immediately import invalid data.

For "Teacher-discretion demerit", support the special 1–5 rule rather than treating it as a fixed score.

==================================================
21. EDIT AND DELETE
==================================================

Allow authorized administrators to edit:

- Student information
- Point records
- Point item
- Point score
- Entered-by name
- Reflection submission status
- Punishment type
- Punishment period

For deletion:
- Show a confirmation dialog
- Clearly explain what will be deleted
- Prevent accidental deletion

Prefer soft deletion for historical records where appropriate.

Historical point records should remain available for calculation and auditing.

==================================================
22. STUDENT DETAIL PAGE
==================================================

Create:

/students/[id]

Display:

Student name
Grade

Summary cards:
- Current merits
- Current demerits
- This week demerits
- This month demerits

Current status:
- Normal
- Physical-training eligible
- Committee referral eligible
- Missing reflection
- Double reflection required
- Sports restriction
- Snack restriction
- Visitor restriction
- Home-leave restriction

Penalty history table:

- Date
- Item
- Points
- Entered by
- Reflection status
- Edit
- Delete

Punishment history:

- Sanction
- Start date
- End date
- Entered by
- Status

==================================================
23. DASHBOARD
==================================================

Create a real dashboard.

Top cards:

- All students
- Weekly demerit targets
- Missing reflection
- Double submission required
- Active sanctions

Main student table:

- Grade
- Name
- Merits
- Demerits
- Sanction
- Status

Provide:
- Search
- Grade filter
- Status filter
- Sorting

Make "+ Enter demerits" a prominent primary action.

==================================================
24. NAVIGATION
==================================================

Sidebar:

"⚖ Daniel's Scale"

- Dashboard
- Students
- Enter demerits
- Enter merits
- Reflection management
- Sanctions
- Demerit items

Show role-specific navigation.

For example:
Student guidance:
- Dashboard
- Students
- Enter demerits
- Enter merits
- Reflection management
- Demerit items

Residential life:
- Dashboard
- Students
- Sanctions

==================================================
25. DATABASE
==================================================

Design a normalized relational database.

Suggested models:

User
- id
- username
- passwordHash
- role
- createdAt
- updatedAt

Student
- id
- name
- grade
- createdAt
- updatedAt
- deletedAt

PointItem
- id
- name
- type
- fixedPoints
- isFixed
- isActive
- createdAt
- updatedAt

PointRecord
- id
- studentId
- pointItemId
- type
- customItemName
- points
- enteredByName
- recordedAt
- createdAt
- updatedAt
- deletedAt

ReflectionRecord
- id
- pointRecordId
- submitted
- submissionDeadline
- submittedAt

Punishment
- id
- studentId
- type
- startDate
- endDate
- enteredByName
- violated
- violationRecordedAt
- createdAt
- updatedAt

WeeklySummary
- id
- studentId
- weekStart
- weekEnd
- penaltyPoints
- penaltyRecordCount
- createdAt
- updatedAt

Use foreign keys and indexes appropriately.

Add indexes for:
- student name
- student grade
- point record studentId
- point record recordedAt
- weekly summary studentId + weekStart
- punishment studentId + dates

==================================================
26. API / SERVER LOGIC
==================================================

Implement proper server-side operations for:

- Authentication
- Students CRUD
- Point items CRUD
- Point records CRUD
- Reflection status updates
- Punishment CRUD
- Weekly calculations
- Monthly calculations
- Status detection
- Excel import

All mutations must validate input on the server.

Do not trust client-provided calculated statuses.

Calculated statuses should be derived from authoritative database records.

==================================================
27. UI COMPONENTS
==================================================

Use reusable components:

- Sidebar
- Header
- Button
- Input
- SearchInput
- Select
- Combobox
- Checkbox
- RadioGroup
- Badge
- Card
- DataTable
- Modal/Dialog
- Toast
- Confirmation Dialog
- Empty State
- Loading State
- Error State
- Pagination

Create consistent component variants.

==================================================
28. RESPONSIVE DESIGN
==================================================

Primary target:
Desktop 1440px.

Also support:
- Tablet
- Mobile

On mobile:
- Sidebar becomes a drawer
- Tables become horizontally scrollable or card-based
- Modals fit smaller screens
- Important actions remain accessible

==================================================
29. ERROR HANDLING
==================================================

Implement clear Korean error messages.

Examples:

"Select a student."
"Select a demerit item."
"Enter demerit points."
"Enter the operator name."
"Teacher-discretion points must be between 1 and 5."
"Select up to two sanctions."
"Select a sanction."

Success messages:

"Demerit recorded."
"Merit recorded."
"Sanction recorded."
"Student information updated."
"Demerit item saved."

==================================================
30. SECURITY
==================================================

Implement basic production security practices.

- Password hashing
- Secure sessions
- Server-side role authorization
- Input validation
- SQL injection protection through ORM
- CSRF protection where applicable
- Secure cookies
- Do not expose passwords
- Do not expose unnecessary personal data
- Validate uploaded Excel files
- Limit upload file size
- Sanitize imported values

Never rely solely on frontend permissions.

==================================================
31. AUDIT LOG
==================================================

Create an audit log system if practical.

Track important changes:

- Who performed the action
- What action occurred
- Which record was affected
- When it happened

Remember:
The "Entered by" field is still a manually entered name and is separate from the authenticated administrator account.

==================================================
32. INITIAL SEED DATA
==================================================

Create seed data for development.

Create two administrator accounts:

- Student guidance
- Residential life

Create sample students:

- Sample Student A — Grade 2
- Sample Student B — Grade 1
- Sample Student C — Grade 3
- Sample Student D — Grade 2

Create sample point items:

- Tardiness
- Uniform violation
- Untidy shoe storage
- Teacher-discretion demerit

Do not invent fixed scores for the first three items unless they are explicitly configured later.

==================================================
33. IMPORTANT BUSINESS LOGIC
==================================================

Implement these rules exactly:

Weekly:
3 or more penalty records OR 8+ weekly penalty points
→ Physical-training eligible

Monthly:
20+ monthly penalty points
→ Committee referral eligible

Weekly:
5+ penalty points
→ Residential life manually selects 1 punishment

Weekly:
10+ penalty points
→ Residential life manually selects 2 punishments

Three consecutive weeks:
5+ penalty points every week
→ Home-leave restriction condition met

Punishment violation:
→ Home-leave restriction

Reflection:
Same-day deadline.
Next day + not submitted
→ Double submission required

Weekly reset:
Current weekly total resets for the new week.
Historical records remain.

==================================================
34. IMPORTANT DATA RULE
==================================================

Do not calculate total Demerits as:
Merits - Demerits.

"Demerits" and "Merits" are separate values.

Automatic punishment/status rules use the specified Demerits values only.

==================================================
35. FINAL REQUIREMENT
==================================================

Do not return only a design or wireframe.

Generate the actual application code.

The application should:
- Start successfully
- Have working navigation
- Have working authentication
- Have working database operations
- Have working CRUD
- Have working automatic calculations
- Have working reflection paper status logic
- Have working punishment selection logic
- Have working Excel import
- Have proper validation
- Have realistic loading/error/empty states

Create a clean project structure with readable TypeScript code.

Add a README.md containing:
- Project overview
- Tech stack
- Environment variables
- Database setup
- Migration instructions
- Seed instructions
- Local development instructions
- Production deployment instructions

Do not use fake buttons.
Every major button should perform a real action.

Build "Daniel's Scale" as a real full-stack application, not merely a visual prototype.
