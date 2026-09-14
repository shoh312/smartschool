import { useEffect, useState } from 'react'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { loadSession, onSessionChange } from './api/client'
import type { Session } from './api/types'
import { LangProvider } from './i18n'
import { ToastProvider } from './ui/kit'
import { Shell } from './ui/Shell'
import { Login } from './pages/auth/Login'
import { DirectorHome } from './pages/director/Home'
import { Classes, ClassDetail } from './pages/director/Classes'
import { Journal } from './pages/director/Journal'
import { Students } from './pages/director/Students'
import { Teachers } from './pages/director/Teachers'
import { Cameras } from './pages/director/Cameras'
import { Analytics } from './pages/director/Analytics'
import { StudentPage } from './pages/director/Student'
import { Announcements } from './pages/director/Announcements'
import { Calendar } from './pages/director/Calendar'
import { Settings } from './pages/director/Settings'
import { ManualAttendance } from './pages/director/ManualAttendance'
import { TeacherHome } from './pages/teacher/Home'
import { TeacherJournal } from './pages/teacher/Journal'
import { Materials } from './pages/teacher/Materials'
import { MaterialEditor } from './pages/teacher/MaterialEditor'
import { Results } from './pages/teacher/Results'
import { Diary } from './pages/teacher/Diary'

export function useSession(): Session | null {
  const [s, set] = useState<Session | null>(loadSession)
  useEffect(() => onSessionChange(() => set(loadSession())), [])
  return s
}

function Routed() {
  const session = useSession()
  if (!session) {
    return (
      <Routes>
        <Route path="*" element={<Login />} />
      </Routes>
    )
  }
  if (session.role === 'director') {
    return (
      <Routes>
        <Route element={<Shell session={session} />}>
          <Route index element={<DirectorHome />} />
          <Route path="classes" element={<Classes />} />
          <Route path="classes/:id" element={<ClassDetail />} />
          <Route path="classes/:id/journal" element={<Journal />} />
          <Route path="students" element={<Students />} />
          <Route path="students/:id" element={<StudentPage />} />
          <Route path="teachers" element={<Teachers />} />
          <Route path="cameras" element={<Cameras />} />
          <Route path="analytics" element={<Analytics />} />
          <Route path="announcements" element={<Announcements />} />
          <Route path="calendar" element={<Calendar />} />
          <Route path="settings" element={<Settings />} />
          <Route path="test" element={<ManualAttendance />} />
          <Route path="test/:id" element={<ManualAttendance />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      </Routes>
    )
  }
  return (
    <Routes>
      <Route element={<Shell session={session} />}>
        <Route index element={<TeacherHome />} />
        <Route path="journal/:classId/:subject" element={<TeacherJournal />} />
        <Route path="materials" element={<Materials />} />
        <Route path="materials/new" element={<MaterialEditor />} />
        <Route path="materials/:id" element={<MaterialEditor />} />
        <Route path="results/:id" element={<Results />} />
        <Route path="diary" element={<Diary />} />
        <Route path="calendar" element={<Calendar />} />
        <Route path="announcements" element={<Announcements />} />
        <Route path="settings" element={<Settings />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}

export default function App() {
  return (
    <LangProvider>
      <ToastProvider>
        <BrowserRouter basename={import.meta.env.BASE_URL.replace(/\/$/, '')}>
          <Routed />
        </BrowserRouter>
      </ToastProvider>
    </LangProvider>
  )
}
