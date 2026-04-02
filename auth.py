"""
Agridic - Firebase Authentication (REST API)

Uses Firebase Identity Toolkit REST API for email/password auth.
Requires FIREBASE_WEB_API_KEY environment variable.

Admin setup: the very first user to register is automatically assigned
the 'admin' role in Firestore.
"""

import os
import requests
from datetime import datetime

FIREBASE_AUTH_BASE = "https://identitytoolkit.googleapis.com/v1/accounts"


def _get_api_key() -> str:
    return os.environ.get("FIREBASE_WEB_API_KEY", "")


def _translate_error(msg: str) -> str:
    """Translate Firebase error codes to user-friendly messages."""
    table = {
        "EMAIL_EXISTS": "This email is already registered.",
        "INVALID_EMAIL": "Invalid email address.",
        "WEAK_PASSWORD : Password should be at least 6 characters":
            "Password must be at least 6 characters.",
        "WEAK_PASSWORD": "Password must be at least 6 characters.",
        "EMAIL_NOT_FOUND": "No account found with this email.",
        "INVALID_PASSWORD": "Incorrect password.",
        "INVALID_LOGIN_CREDENTIALS": "Invalid email or password.",
        "USER_DISABLED": "This account has been disabled.",
        "TOO_MANY_ATTEMPTS_TRY_LATER": "Too many attempts. Please try again later.",
        "OPERATION_NOT_ALLOWED": (
            "Email/password sign-in is disabled.\n"
            "Enable it in Firebase Console → Authentication → Sign-in method."
        ),
    }
    for key, translation in table.items():
        if key in msg:
            return translation
    return msg


def sign_up_email(email: str, password: str, display_name: str = "") -> dict:
    """Register a new user with email/password.

    Returns the Firebase auth response dict (contains 'localId', 'idToken', etc.).
    Raises ValueError with a user-friendly message on failure.
    """
    api_key = _get_api_key()
    if not api_key:
        raise ValueError(
            "FIREBASE_WEB_API_KEY is not configured.\n"
            "Please set this environment variable."
        )

    resp = requests.post(
        f"{FIREBASE_AUTH_BASE}:signUp?key={api_key}",
        json={"email": email, "password": password, "returnSecureToken": True},
        timeout=15,
    )
    data = resp.json()
    if "error" in data:
        raise ValueError(_translate_error(data["error"].get("message", "Unknown error")))

    # Update display name if provided
    if display_name:
        try:
            requests.post(
                f"{FIREBASE_AUTH_BASE}:update?key={api_key}",
                json={"idToken": data["idToken"], "displayName": display_name},
                timeout=10,
            )
        except Exception:
            pass

    return data


def sign_in_email(email: str, password: str) -> dict:
    """Sign in with email/password.

    Returns the Firebase auth response dict.
    Raises ValueError with a user-friendly message on failure.
    """
    api_key = _get_api_key()
    if not api_key:
        raise ValueError(
            "FIREBASE_WEB_API_KEY is not configured.\n"
            "Please set this environment variable."
        )

    resp = requests.post(
        f"{FIREBASE_AUTH_BASE}:signInWithPassword?key={api_key}",
        json={"email": email, "password": password, "returnSecureToken": True},
        timeout=15,
    )
    data = resp.json()
    if "error" in data:
        raise ValueError(_translate_error(data["error"].get("message", "Unknown error")))

    return data


def get_or_create_user_profile(uid: str, email: str, display_name: str) -> dict:
    """Get existing user profile from Firestore, or create it.

    The very first user to register receives the 'admin' role.
    All subsequent users receive 'farmer' by default.

    Falls back to a local dict if Firestore is unavailable.
    """
    try:
        from firebase_config import initialize_firebase, get_firestore_client

        initialize_firebase()
        db = get_firestore_client()

        user_ref = db.collection("users").document(uid)
        user_doc = user_ref.get()

        if user_doc.exists:
            return user_doc.to_dict()

        # First user → admin
        existing = list(db.collection("users").limit(1).stream())
        role = "admin" if len(existing) == 0 else "farmer"

        user_data = {
            "uid": uid,
            "email": email,
            "display_name": display_name or email.split("@")[0],
            "role": role,
            "created_at": datetime.utcnow().isoformat(),
        }
        user_ref.set(user_data)
        return user_data

    except Exception as exc:
        print(f"[auth] Firestore user profile error: {exc}")
        return {
            "uid": uid,
            "email": email,
            "display_name": display_name or email.split("@")[0],
            "role": "farmer",
        }
