import { supabase } from '../lib/supabase'
import type { AuthResponse, SignInCredentials, SignUpCredentials } from '../types/auth.types'
import type { AuthChangeEvent, Session } from '@supabase/supabase-js'

class AuthService {
  /**
   * Sign in with email and password
   */
  async signIn({ email, password }: SignInCredentials): Promise<AuthResponse> {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    })

    return {
      user: data.user,
      session: data.session,
      error
    }
  }

  /**
   * Sign up with email and password
   */
  async signUp({ email, password }: SignUpCredentials): Promise<AuthResponse> {
    const { data, error } = await supabase.auth.signUp({
      email,
      password
    })

    return {
      user: data.user,
      session: data.session,
      error
    }
  }

  /**
   * Sign out the current user
   */
  async signOut(): Promise<{ error: AuthResponse['error'] }> {
    const { error } = await supabase.auth.signOut()
    return { error }
  }

  /**
   * Get the current session
   */
  async getSession(): Promise<{ session: Session | null; error: AuthResponse['error'] }> {
    const { data, error } = await supabase.auth.getSession()
    return {
      session: data.session,
      error
    }
  }

  /**
   * Subscribe to auth state changes
   */
  onAuthStateChange(
    callback: (event: AuthChangeEvent, session: Session | null) => void
  ) {
    return supabase.auth.onAuthStateChange(callback)
  }
}

export const authService = new AuthService()
