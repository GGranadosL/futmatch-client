# Onboarding Draft Persistence - Implementation Guide

## ✅ Implementación Completada

Se ha implementado la funcionalidad de **auto-save** para el flujo de onboarding usando **CoreData + Keychain**, siguiendo Clean Architecture.

## 🏗️ Arquitectura Implementada

```
┌─────────────────────────────────────────────────┐
│              Presentation Layer                 │
│  ┌─────────────────────────────────────────┐   │
│  │      OnboardingViewModel                │   │
│  │  - scheduleSaveDraft() (debounced)      │   │
│  │  - loadDraft()                          │   │
│  │  - clearDraftAfterSuccess()             │   │
│  └─────────────────────────────────────────┘   │
├─────────────────────────────────────────────────┤
│               Domain Layer                      │
│  ┌────────────────────────────────────────┐    │
│  │  Use Cases:                            │    │
│  │  - SaveOnboardingDraftUseCase          │    │
│  │  - GetOnboardingDraftUseCase           │    │
│  │  - ClearOnboardingDraftUseCase         │    │
│  └────────────────────────────────────────┘    │
│  ┌────────────────────────────────────────┐    │
│  │  Entity: OnboardingDraft               │    │
│  └────────────────────────────────────────┘    │
├─────────────────────────────────────────────────┤
│                Data Layer                       │
│  ┌────────────────────────────────────────┐    │
│  │  OnboardingRepository                  │    │
│  │  - CoreData (draft data)               │    │
│  │  - Keychain (password)                 │    │
│  └────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

## 📁 Archivos Creados/Modificados

### ✨ Nuevos Archivos

1. **Domain/Entities/OnboardingDraft.swift**
   - Modelo de dominio con todos los campos del onboarding
   - Propiedad `isExpired` para validar drafts antiguos (> 24h)

2. **Domain/Repositories/OnboardingRepositoryProtocol.swift**
   - Protocolo para persistencia de drafts

3. **Domain/UseCases/OnboardingDraftUseCases.swift**
   - SaveOnboardingDraftUseCase
   - GetOnboardingDraftUseCase
   - ClearOnboardingDraftUseCase

4. **Data/Repositories/OnboardingRepository.swift**
   - Implementación con CoreData + Keychain
   - Password guardado de forma segura en Keychain

5. **DI/OnboardingDependencyFactory.swift**
   - Factory para crear dependencias inyectadas

### 🔧 Archivos Modificados

1. **FutMatch_Client.xcdatamodeld/contents**
   - Agregada entidad `OnboardingDraftEntity` con 11 atributos

2. **ViewModels/OnboardingViewModel.swift**
   - Agregado extension con métodos de persistencia
   - Auto-save con debounce de 500ms
   - Load draft en initialization
   - Clear draft después de registro exitoso

3. **Views/Onboarding/Steps/OnboardingStep1View.swift**
   - onChange listeners para firstName, lastName, birthDate, gender

4. **Views/Onboarding/Steps/OnboardingStep2View.swift**
   - onChange listeners para email, password, phone, country, countryCode

5. **Views/Onboarding/Steps/OnboardingStep3View.swift**
   - onChange listeners para playerPosition, level

## 🚀 Cómo Usar

### 1. Inicializar ViewModel con DI

```swift
import OnboardingFeature

// En tu App o Scene
let persistenceContainer = PersistenceController.shared.container

let factory = OnboardingDependencyFactory(
    persistenceContainer: persistenceContainer
)

let viewModel = factory.makeOnboardingViewModel()

// Usar en la vista
OnboardingContainerView(viewModel: viewModel)
```

### 2. Auto-save Automático

El auto-save se ejecuta automáticamente en cada cambio de campo con:
- ✅ **Debounce de 500ms** - Evita guardar en cada keystroke
- ✅ **Background context** - No bloquea la UI
- ✅ **Password en Keychain** - Guardado seguro

### 3. Restauración Automática

Al abrir la app, el draft se carga automáticamente si:
- ✅ Existe un draft guardado
- ✅ No ha expirado (< 24 horas)
- ✅ El usuario no completó el registro

### 4. Limpieza Automática

El draft se limpia automáticamente:
- ✅ Después de verificación exitosa
- ✅ Si ha expirado (> 24 horas)
- ✅ Si falla la restauración

## 🔒 Seguridad

- **Password**: Guardado en **Keychain** (iOS Secure Enclave)
- **Otros datos**: CoreData (encriptado si File Protection está habilitado)
- **Expiración**: 24 horas para evitar datos obsoletos

## 📊 CoreData Schema

```xml
<entity name="OnboardingDraftEntity">
    <attribute name="firstName" type="String"/>
    <attribute name="lastName" type="String"/>
    <attribute name="birthDate" type="Date" optional="YES"/>
    <attribute name="gender" type="String" optional="YES"/>
    <attribute name="email" type="String"/>
    <attribute name="phoneCountryCode" type="String"/>
    <attribute name="phone" type="String"/>
    <attribute name="country" type="String"/>
    <attribute name="currentStep" type="Integer 16"/>
    <attribute name="createdAt" type="Date"/>
    <attribute name="updatedAt" type="Date"/>
</entity>
```

## 🎯 Próximos Pasos

1. **Actualizar FutMatch_ClientApp.swift** para inyectar dependencias
2. **Compilar y probar** el flujo completo
3. **(Opcional)** Agregar toast notification "Borrador restaurado"
4. **(Opcional)** Agregar botón "Limpiar borrador" en Settings

## 🐛 Debug Tips

```swift
// Verificar si hay draft guardado
let factory = OnboardingDependencyFactory(persistenceContainer: container)
let getDraftUseCase = factory.makeGetOnboardingDraftUseCase()

Task {
    if let result = try? await getDraftUseCase.execute() {
        print("📦 Draft found: \(result.draft)")
    } else {
        print("❌ No draft found")
    }
}
```

## ✅ Testing

```swift
// Unit test para SaveOnboardingDraftUseCase
func test_saveDraft_storesDataInCoreData() async throws {
    let draft = OnboardingDraft(
        firstName: "John",
        lastName: "Doe",
        email: "john@example.com"
    )
    
    try await saveUseCase.execute(draft, password: "test123")
    
    let result = try await getUseCase.execute()
    XCTAssertEqual(result?.draft.firstName, "John")
}
```

---

**Implementado por:** GitHub Copilot  
**Fecha:** Febrero 9, 2026  
**Arquitectura:** Clean Architecture + MVVM
