import { useNavigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { authService } from '../services/auth.service'

export function Dashboard() {
  const navigate = useNavigate()
  const { user } = useAuth()

  const handleSignOut = async () => {
    await authService.signOut()
    navigate('/login')
  }

  return (
    <div className="dashboard">
      <header className="dashboard-header">
        <div className="container">
          <nav className="dashboard-nav">
            <h1 className="dashboard-title">Fitness Tracker</h1>
            <button
              onClick={handleSignOut}
              className="btn btn-danger"
            >
              Sign Out
            </button>
          </nav>
        </div>
      </header>

      <main className="dashboard-content">
        <div className="container">
          <div className="card">
            <h2 className="card-title">Welcome!</h2>
            <div className="user-info">
              <div className="user-info-item">
                <span className="user-info-label">Email:</span>
                <span className="user-info-value">{user?.email}</span>
              </div>
              <div className="user-info-item">
                <span className="user-info-label">User ID:</span>
                <span className="user-info-value">{user?.id}</span>
              </div>
            </div>
          </div>

          <div className="card">
            <h2 className="card-title">Your Workouts</h2>
            <p className="text-secondary">
              Workout tracking features will be integrated here.
            </p>
          </div>
        </div>
      </main>
    </div>
  )
}
