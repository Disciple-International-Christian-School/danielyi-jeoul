Build a complete, production-ready full-stack web application called "다니엘의 저울".

This is NOT just a UI mockup.
Generate the actual working application code, including frontend, backend/server logic, database schema, authentication, authorization, validation, business rules, and data persistence.

The entire user-facing application must be in Korean.

==================================================
1. PROJECT OVERVIEW
==================================================

Service name:
"다니엘의 저울"

Purpose:
A school student council management system for managing:
- 학생 기본 정보
- 상점
- 벌점
- 벌점 항목
- 반성문 제출 상태
- 학생 처분
- weekly/monthly automatic status detection

There are exactly two administrative roles:

1. 선도부
2. 사생회

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
  Korean display name: "선도부"

- SASAENG
  Korean display name: "사생회"

Administrators log in using:
- ID/email
- Password

After login, redirect the user to the dashboard.

Store the user's role in the authenticated session.

Implement server-side authorization.

A user with role "선도부" must not be able to access restricted 사생회 functions.

A user with role "사생회" must not be able to modify 선도부-only settings.

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

- current 상점
- current 벌점
- weekly 벌점
- monthly 벌점
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

1. Highest current 벌점
2. Grade
3. Korean alphabetical order

Student table:

- 학년
- 이름
- 상점
- 벌점
- 현재 처분
- 상태
- 상세보기

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

- 학생
- 벌점 항목
- 벌점
- 기입자
- 반성문 제출

The student field should be a searchable dropdown.

The penalty item field should be a searchable combobox with a dropdown arrow.

Preset items include:

- 지각
- 복장불량
- 신발장 미정리
- 선생님 재량 벌점
- 기타 직접 입력

IMPORTANT:
Do NOT invent fixed point values for:
- 지각
- 복장불량
- 신발장 미정리

Their point values must be configurable by administrators.

When a preset item with a configured fixed score is selected:
- automatically populate the score
- prevent accidental modification if the item is configured as fixed

For "기타 직접 입력":
- allow manual item name
- allow manual point input

==================================================
8. TEACHER-DISCRETION PENALTY
==================================================

"선생님 재량 벌점" is a special item.

It does NOT have a fixed point value.

When selected, display:

[ 1점 ]
[ 2점 ]
[ 3점 ]
[ 4점 ]
[ 5점 ]

The administrator must select exactly one value.

Only 1–5 points are allowed.

Server-side validation MUST also enforce this rule.

Do not trust client-side validation alone.

==================================================
9. POSITIVE POINTS / 상점
==================================================

Create a separate form for entering 상점.

Fields:

- 학생
- 상점 항목
- 상점
- 기입자
- 날짜

The same manual "기입자" rule applies.

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

"☐ 반성문 제출"

Checked:
"제출 완료"

Unchecked:
"미제출"

IMPORTANT AUTOMATIC RULE:

If the next calendar day has begun and submitted is still false:

Set/display:
"2배 제출 대상"

Do not delete the original record.

Store the original penalty date and deadline.

Create a dedicated reflection paper management page.

Filters:
- 전체
- 제출 완료
- 미제출
- 2배 제출 대상

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
"체력훈련 대상"

RULE B — MONTHLY:

If a student has:
- 20 or more penalty points in the current month

Then:
"징계위원회 대상"

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

- The displayed "이번 주 벌점" becomes 0 for the new week.
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

Create a punishment management system for "사생회".

Punishment types:

- 운동금지
- 간식금지
- 면회금지
- 귀가 지연
- 귀가 금지

IMPORTANT:
The system must NOT automatically choose a punishment.

The 사생회 administrator manually chooses the punishment.

==================================================
14. WEEKLY 5+ RULE
==================================================

If a student has 5 or more penalty points during the current week:

Display:

"처분 선택 필요"

Allow the 사생회 administrator to manually choose ONE punishment from:

- 운동금지
- 간식금지
- 면회금지

==================================================
15. WEEKLY 10+ RULE
==================================================

If a student has 10 or more penalty points during the current week:

Allow the 사생회 administrator to manually choose TWO punishments from:

- 운동금지
- 간식금지
- 면회금지

The UI should clearly show:
"처분 2개를 선택하세요."

Do not automatically select punishments.

Prevent invalid selections on both frontend and backend.

==================================================
16. THREE CONSECUTIVE WEEKS
==================================================

If a student has 5 or more penalty points in each of three consecutive weeks:

Display:

"귀가금지 조건 충족"

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
"귀가금지"

The interface should provide an action for authorized administrators to record a violation.

Do not automatically assume a violation occurred without an administrator recording it.

==================================================
18. PUNISHMENT REGISTRATION
==================================================

Create a punishment registration modal.

Fields:

- 학생
- 이번 주 벌점
- 처분 선택
- 처분 시작일
- 처분 종료일
- 기입자

"기입자" must be a manually typed text field.

For 5+ weekly points:
- allow one punishment selection

For 10+ weekly points:
- allow two punishment selections

Show the current weekly penalty count inside the modal.

Buttons:

[ 취소 ]
[ 처분 등록 ]

==================================================
19. POINT ITEM MANAGEMENT
==================================================

Create a page:
"벌점 항목 관리"

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

지각
복장불량
신발장 미정리
선생님 재량 벌점

For "선생님 재량 벌점":

isFixed = false
allowed range = 1–5

==================================================
20. EXCEL IMPORT
==================================================

Implement Excel import for penalty items.

Provide an "Excel 가져오기" button.

Allow the administrator to upload an Excel file.

Expected columns:

벌점 항목
벌점

Process:

1. Upload Excel file
2. Parse spreadsheet
3. Show preview
4. Validate rows
5. Display validation errors
6. Confirm import
7. Save valid items to database

Do not immediately import invalid data.

For "선생님 재량 벌점", support the special 1–5 rule rather than treating it as a fixed score.

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
- 현재 상점
- 현재 벌점
- 이번 주 벌점
- 이번 달 벌점

Current status:
- 정상
- 체력훈련 대상
- 징계위원회 대상
- 반성문 미제출
- 반성문 2배 제출 대상
- 운동금지
- 간식금지
- 면회금지
- 귀가금지

Penalty history table:

- 날짜
- 항목
- 점수
- 기입자
- 반성문 상태
- 수정
- 삭제

Punishment history:

- 처분
- 시작일
- 종료일
- 기입자
- 상태

==================================================
23. DASHBOARD
==================================================

Create a real dashboard.

Top cards:

- 전체 학생
- 이번 주 벌점 대상
- 반성문 미제출
- 2배 제출 대상
- 현재 처분 중

Main student table:

- 학년
- 이름
- 상점
- 벌점
- 처분
- 상태

Provide:
- Search
- Grade filter
- Status filter
- Sorting

Make "+ 벌점 입력" a prominent primary action.

==================================================
24. NAVIGATION
==================================================

Sidebar:

"⚖ 다니엘의 저울"

- 대시보드
- 학생 관리
- 벌점 입력
- 상점 입력
- 반성문 관리
- 처분 관리
- 벌점 항목 관리

Show role-specific navigation.

For example:
선도부:
- 대시보드
- 학생 관리
- 벌점 입력
- 상점 입력
- 반성문 관리
- 벌점 항목 관리

사생회:
- 대시보드
- 학생 관리
- 처분 관리

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

"학생을 선택해주세요."
"벌점 항목을 선택해주세요."
"벌점을 입력해주세요."
"기입자 이름을 입력해주세요."
"선생님 재량 벌점은 1~5점만 선택할 수 있습니다."
"처분은 2개까지 선택할 수 있습니다."
"처분을 선택해주세요."

Success messages:

"벌점이 등록되었습니다."
"상점이 등록되었습니다."
"처분이 등록되었습니다."
"학생 정보가 수정되었습니다."
"벌점 항목이 저장되었습니다."

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
The "기입자" field is still a manually entered name and is separate from the authenticated administrator account.

==================================================
32. INITIAL SEED DATA
==================================================

Create seed data for development.

Create two administrator accounts:

- 선도부
- 사생회

Create sample students:

- 홍길동 — 2학년
- 김민지 — 1학년
- 이준호 — 3학년
- 박서연 — 2학년

Create sample point items:

- 지각
- 복장불량
- 신발장 미정리
- 선생님 재량 벌점

Do not invent fixed scores for the first three items unless they are explicitly configured later.

==================================================
33. IMPORTANT BUSINESS LOGIC
==================================================

Implement these rules exactly:

Weekly:
3 or more penalty records OR 8+ weekly penalty points
→ 체력훈련 대상

Monthly:
20+ monthly penalty points
→ 징계위원회 대상

Weekly:
5+ penalty points
→ 사생회 manually selects 1 punishment

Weekly:
10+ penalty points
→ 사생회 manually selects 2 punishments

Three consecutive weeks:
5+ penalty points every week
→ 귀가금지 조건 충족

Punishment violation:
→ 귀가금지

Reflection:
Same-day deadline.
Next day + not submitted
→ 2배 제출 대상

Weekly reset:
Current weekly total resets for the new week.
Historical records remain.

==================================================
34. IMPORTANT DATA RULE
==================================================

Do not calculate total 벌점 as:
상점 - 벌점.

"벌점" and "상점" are separate values.

Automatic punishment/status rules use the specified 벌점 values only.

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

Build "다니엘의 저울" as a real full-stack application, not merely a visual prototype.