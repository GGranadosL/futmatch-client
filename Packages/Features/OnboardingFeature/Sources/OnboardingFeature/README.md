# OnboardingFeature

Feature module for user authentication and onboarding in FutMatch.

## Usage Example

```swift
import OnboardingFeature

// Initialize the service
let authService = AuthService()

// Create a registration request
let request = RegisterStartRequest(
    name: "Diego",
    lastName: "Beltran",
    email: "diego.beltran@example.com",
    password: "StrongPassdd123!",
    phone: "5292422233",
    country: "México",
    birthDate: 915148800000, // timestamp in milliseconds
    gender: .male,
    playerPosition: .midfielder,
    profilePic: "https://example.com/images/diego.jpg",
    level: .intermediate
)

// Start registration
do {
    let response = try await authService.registerStart(request)
    print("Success: \(response.data.message)")
    print("Resend code in: \(response.data.resendCodeTimeInSeconds) seconds")
} catch {
    print("Error: \(error)")
}
```

## API Endpoints

### POST /auth/register/start

Starts the registration process and sends a verification code.

**Request:**
```json
{
  "name": "Diego",
  "lastName": "Beltran",
  "email": "diego.beltran@example.com",
  "password": "StrongPassdd123!",
  "phone": "5292422233",
  "country": "México",
  "birthDate": 915148800000,
  "gender": "MALE",
  "playerPosition": "MIDFIELDER",
  "profilePic": "https://example.com/images/diego.jpg",
  "level": "INTERMEDIATE"
}
```

**Response:**
```json
{
  "data": {
    "success": true,
    "message": "Si tu correo es válido y no está en uso, recibirás un código de verificación en breve.",
    "resendCodeTimeInSeconds": 60
  }
}
```

## Models

### Gender
- `MALE`
- `FEMALE`
- `OTHER`

### PlayerPosition
- `GOALKEEPER`
- `DEFENDER`
- `MIDFIELDER`
- `FORWARD`

### PlayerLevel
- `BEGINNER`
- `INTERMEDIATE`
- `ADVANCED`
- `PROFESSIONAL`
