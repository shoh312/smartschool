# SmartSchool — Project Brief for Frontend Generation

You are building a **modern, polished web frontend** for an existing, fully-functional school management system called **SmartSchool**, built for schools in Tajikistan. The backend (FastAPI/Python + PostgreSQL) already exists and works — your job is only the frontend. Below is everything about the system: architecture, data model, API surface, features, and the existing design language to match.

---

## 1. What the product is

SmartSchool is a school management platform with three user roles:

- **Director** — runs one school: manages classes, teachers, students, cameras, sees attendance/grades/rankings for the whole school.
- **Teacher** — assigned to specific classes/subjects: takes attendance manually if needed, enters grades, views their own classes' rosters and analytics.
- **Parent** — sees only their own children: attendance history, grades, notifications, and their child's academic rating.

The standout feature is **automatic, camera-based attendance**: cameras mounted in classrooms use face recognition (InsightFace) to detect which students are physically present, in real time, without anyone taking manual roll call.

## 2. System architecture (already built — the frontend must integrate with this, not replace it)

Three separate deployable services:

1. **Local backend** (FastAPI, Python) — runs on a server *inside the school's own local network*. Owns all the real data: students, classes, teachers, grades, attendance, cameras. Runs the face-recognition camera pipeline. Director and teacher clients talk to this directly (only reachable on the school's WiFi/LAN).
2. **Public server** (FastAPI, Python, separate deployment, reachable over the public internet) — the *only* thing parents' apps talk to. It never sees camera footage or student photos — only receives a filtered stream of events (grades, attendance status changes, notifications, and pre-computed rating/analytics snapshots) pushed to it one-way from the local backend via an outbox/sync pattern. This split exists deliberately for privacy: a parent's phone, potentially anywhere in the world, must never have a path to the school's internal camera network.
3. **Existing client app** (Flutter, Windows desktop + Android) — the current UI you're replacing/complementing with a web frontend. It already implements every feature described below; use it as the reference for what "done" looks like, and improve on its visual design.

**Implication for you**: the web frontend should talk to the **local backend** (`http://<school-server>:8000`) for director/teacher flows, and to the **public server** (a fixed public URL) for parent flows — exactly like the existing Flutter app does. Don't assume a single unified API base URL across all roles.

Auth: Bearer JWT tokens. Director and teacher login against the local backend (`POST /auth/director/login`, `POST /auth/teacher/login`, email+password). Parents log in against the public server by phone number (`POST /auth/login`, `{"phone": "..."}` — a parent's identity is auto-created by the local backend the first time a director enrolls their child, so no self-registration; an unknown phone returns 404 `phone_not_registered`).

## 3. Core data model (key entities)

- **School** — a tenant. Everything else belongs to one school (`school_id`).
- **Director**, **Teacher**, **Parent** — the three account types, each with their own auth.
- **Class** — e.g. "5A", has a `grade` (integer grade-level, so "5A"/"5B"/"5C" all share `grade=5` — this grouping is called a "parallel").
- **Student** — belongs to a class and a parent, has a face-recognition photo/encoding.
- **Camera** — assigned to a class, runs face-detection on a schedule.
- **Lesson** — a class's weekly timetable entry: subject, day of week, start time, duration (default 45 minutes). This is the unit camera detection uses to know "what lesson is happening right now."
- **Attendance** (day-level, legacy/still used) — one row per student per calendar day: present/late/absent/left_school.
- **LessonAttendance** (fine-grained, newer) — one row per student per lesson per day, so attendance can be judged per-subject/period, not just once a day. A student not detected within 45 minutes of a lesson starting is auto-marked absent for that lesson.
- **Grade** — a mark (1-10 scale) a teacher gives a student for a subject, tagged with `quarter` (1-4, the Tajik 4-"chorak" academic system) and `school_year` (the calendar year the school year starts in, e.g. 2025 for the "2025-2026" year — this exists specifically so quarter numbers don't collide across different years).
- **StudentAnalytics** (public server only, a synced snapshot) — a pre-computed rating snapshot per student per quarter, since the public server can't compute rankings itself (see §2).

## 4. Feature list (build UI for all of this)

### 4.1 Attendance
- Live "who's in class right now" view per class (real-time via WebSocket), color-coded present/late/absent.
- Live camera video stream per class (WebSocket-pushed JPEG frames — not a standard video codec).
- Per-lesson attendance breakdown: for a given class + day, show each scheduled lesson and who was present/late/absent for it specifically.
- Attendance history for a single student (director/teacher/parent).
- Monthly PDF-style report per class (present/late/absent days, hours).
- 30-day/monthly class analytics: attendance rate trend per student.

### 4.2 Gradebook ("Journal")
- Teachers enter grades (1-10) per student per subject per class, with an optional comment, always dated "today," tagged to the current quarter.
- Grades editable only on the day they were entered.
- Director/teacher/parent can list grades filtered by student/class/subject.

### 4.3 Student Rating / Analytics — the newest, most fleshed-out feature; make this genuinely impressive visually
For a given student + quarter, show:
- **Overall average** (mean of all grades that quarter) as a hero number, animated count-up on load.
- **Rank** within: their class, their "parallel" (same grade-level across all lettered sections), and the whole school — each shown as "`position`/`out_of`" (e.g. "3/28").
- **Achievement badges**: gold styling + a small ribbon label for 1st place, top-3, or top-10%-of-group — purely derived from the rank data, no extra API call.
- **Comparison**: "you vs. class/parallel/school average" as a delta (+/- with color and an up/down arrow — never color alone, always paired with an icon, for colorblind users).
- **Per-subject breakdown**: bar chart of average per subject (color-tiered: green ≥8, amber ≥6, red below), sorted best-to-worst, each row showing subject name, a small icon/initial chip, the numeric average, and a grade count.
- **Strongest/weakest subject** highlight cards (top and bottom of the sorted breakdown).
- **Quarter-over-quarter trend**: a small line/sparkline chart of overall average across quarters 1→current (quarters with no grades yet show as gaps, never as 0), plus a "+0.4 vs previous quarter" delta indicator.
- **Lesson-attendance rate** for the quarter (% of lessons the student was present/late for), color-tiered.
- **Quarter picker** (4 tabs/segments, I/II/III/IV chorak).
- **PDF export** of the whole rating (header with student name + quarter, stat cards, comparison table, subject table).
- A **leaderboard** screen (class/parallel/school scope) — ranked list, medal coloring + icon for top 3 (never just color — always show the numeral too), tap a row to open that student's full rating.
- A director/teacher-only **"needs attention"** screen: two lists — students with the lowest current average, and students with the biggest quarter-over-quarter *decline* (both exclude students who simply haven't been graded yet this quarter — that's a different thing from "struggling").
- Parents see this **full** rating for their own child, including comparative rank (this was an explicit product decision — not just their child's raw numbers in isolation).

### 4.4 Management (director only)
- CRUD for classes, students (with face-photo upload/re-registration), teachers (+ which classes/subjects they're assigned to), cameras, and the weekly lesson timetable per class.
- Room/camera live preview and configuration.

### 4.5 Notifications
- Push notifications to parents (Firebase) on attendance events (arrived/late/absent/left school) and other events.
- In-app notification list/inbox per parent.

### 4.6 Cross-cutting
- **Localization**: Tajik, Russian, English — all UI text must be translatable, not hardcoded per-language.
- **Light/dark theme**, fully supported everywhere.
- **Responsive**: this system is used on phones (parents), and desktop-width windows (directors/teachers) — layouts must adapt (no phone-width components just stretched full-width on a wide screen; convert to proper multi-column grids / adaptive nav at wide breakpoints).

## 5. Key API endpoints (local backend, prefix implicit, Bearer auth unless noted)

```
POST   /auth/director/login              {email, password} -> {access_token, ...}
POST   /auth/director/change-password
POST   /auth/teacher/login               {email, password}
GET    /auth/teacher/me

GET    /classes            POST /classes            PUT /classes/{id}          DELETE /classes/{id}
GET    /cameras            POST /cameras            PUT /cameras/{id}          DELETE /cameras/{id}
POST   /students           PUT /students/{id}       DELETE /students/{id}
POST   /students/register-face/{student_id}

GET    /lessons?class_id=  POST /lessons            PATCH /lessons/{id}        DELETE /lessons/{id}

GET    /attendance/history?student_id=&parent_id=
GET    /attendance/live-status?class_id=              # today's per-student status
GET    /attendance/lesson-status?class_id=&on=         # per-lesson roster for one day
GET    /attendance/class-analytics/{class_id}?days=30
GET    /attendance/monthly-report?year=&month=&class_id=

POST   /grades          GET /grades?student_id=&class_id=&subject=
PATCH  /grades/{id}     DELETE /grades/{id}

GET    /analytics/student/{student_id}?quarter=1..4       # full rating overview (see §4.3 shape below)
GET    /analytics/class/{class_id}/ranking?quarter=
GET    /analytics/parallel/{grade}/ranking?quarter=
GET    /analytics/school/ranking?quarter=
GET    /analytics/class/{class_id}/needs-attention?quarter=
GET    /analytics/school/needs-attention?quarter=

WS     /ws/attendance?token=...          # live attendance push
WS     /ws/stream?camera_id=...          # live camera frame push (binary JPEG frames)
GET    /stream/frame?camera_id=          # polling fallback for the live frame
```

`StudentAnalyticsOverview` shape (the main rating payload):
```json
{
  "student_id": 1, "first_name": "...", "last_name": "...",
  "quarter": 4, "school_year": 2025,
  "overall_average": 8.4,
  "class_rank": {"position": 3, "out_of": 28},
  "parallel_rank": {"position": 12, "out_of": 84},
  "school_rank": {"position": 40, "out_of": 310},
  "class_average": 7.1, "parallel_average": 7.3, "school_average": 7.0,
  "subject_breakdown": [{"subject": "Математика", "average": 9.1, "grade_count": 12}, ...],
  "strongest_subject": "Математика", "weakest_subject": "Забони англисӣ",
  "lesson_attendance_rate": 94.5,
  "trend": [{"quarter": 1, "overall_average": null}, {"quarter": 2, "overall_average": 7.8}, {"quarter": 3, "overall_average": 8.0}, {"quarter": 4, "overall_average": 8.4}]
}
```

## 6. Public server endpoints (parent-facing only, different base URL, phone-based auth)

```
POST /auth/login                         {phone} -> {access_token, parent_id, ...}
GET  /students/me                        # this parent's children
GET  /grades?student_id=
GET  /attendance/history?student_id=
GET  /analytics/student/{student_id}?quarter=      # same shape as §5, full rank included
GET  /notifications/parent/{parent_id}
POST /notifications/device-token
```

## 7. Existing design language (match this, don't reinvent)

- **Primary color**: Indigo `#4F46E5` (light) / `#818CF8` (dark), with a `#3730A3` dark variant and `#818CF8` light variant.
- **Accent**: Cyan `#06B6D4`. **Semantic colors**: success `#10B981` (emerald), warning `#F59E0B` (amber), danger `#EF4444` (red), info `#3B82F6` (blue).
- **Surfaces**: light background `#F6F7FB`, card surface `#FFFFFF`; dark background `#0B0F19`, card surface `#161B2E`. Cards use soft shadows and a subtle 1px border, not heavy borders.
- **Radius scale**: 10 / 14 / 20 / 28px depending on element size (small chips → large cards).
- **Typography**: "Inter" font, bold (700-800 weight) headings, generous letter-spacing on small uppercase labels/eyebrows.
- **Gradients**: primary CTA elements and hero cards use a diagonal indigo gradient (`#6366F1` → `#4338CA`), not flat fills.
- **Rank/medal colors**: gold `#D4AF37`, silver `#A0A5AD`, bronze `#B4732C` for 1st/2nd/3rd place, always paired with an icon (trophy) not just background color.
- **Motion**: subtle — staggered fade+slide-in for list/card sections on load (~350ms, easeOut, ~80-130ms stagger between sections), numbers count up rather than snapping in, progress/score bars animate their fill width.
- **Overall feel**: clean, professional SaaS-dashboard aesthetic — not playful/cartoonish, not enterprise-gray-and-boring either. Think "modern edtech product," generous whitespace, one accent color used with intention (gradients on hero elements only, flat color elsewhere).

## 8. Your task

Build a responsive, multi-role web frontend (React or similar) implementing all of §4, calling the real APIs in §5/§6, matching the design language in §7. Prioritize:
1. Director dashboard (live attendance overview, class list, quick actions) + the full rating/analytics suite in §4.3 — this is the feature we most want to look impressive.
2. Teacher gradebook + their class roster.
3. Parent view (children list, attendance, grades, rating).
4. Live camera view.
5. Management/CRUD screens.

Ask me for the local backend's base URL and the public server's base URL if you need them to wire up real requests — don't hardcode a guessed URL.
